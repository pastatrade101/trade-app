const functions = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require("axios");

admin.initializeApp();
const db = admin.firestore();

// ===================== CONFIG =====================
const AZAMPAY_CONFIG = {
  app_name: "Makutano-app",
  client_id: "18512733-5a9c-4bc6-bbf1-d0285b0e515a",
  client_secret:
    "VcttCrIHmXlf7NeHe7KuvLk3Jgr+ajH8Dfyd5X7kUjwzzRnUNFQEyErdFGpGYldhs/aOEKaz0+1jQZmSNVWxaVxxKkgon84kFoON1fJBj+eJprWB8JyqkkABze7naMYQ+8VQ++biRkXzWhAvN7vrVvowa9pzwTVFdpULgm4y7F+dP0oyZI56dStIGt1sgGpal2XFTnYc+iGDn8WOPkR4tsffy9mg5pe3Rm753k3go5rd+gJnKJf3ntNeH/1O7kZB0z+rYxTIl3yN5ZvRlApYyjBeXrd78/899qvjUDUBv7U6M9u1rjxhaY0MigYd+PX8di1ubkbvp3MGb4bk+l9FGNr+D+W9kPM/pGEnIzirVA5S66ItMZBBTWj3H7woiRorJF7W101f5jlnp5mpsfaZXHvD4slGRGFj1XP3V23ihdOvqi/F8hEhLIylnV34r09pt+WBdFk6cMw+7kBRR3XxMF/U4hW3PvFea7TfXziIiLOC9gDtPn7ce6QWrOdTrgJsWVTIpvzdHAjKP0lv66Z0AHQFkB1G+vFMCaH2GaXuFb637pnt1QYC5JK3hgzaiNU+8z5y2EngHu+KRiHUnF1najykjANiNlHAV9BIU4I4hIorKs2gvodrypl0eIigx7jSCPKPKn3byN9J7YnDdlomyRtK/ncad3co2CHyAqrokR0=",
};
const CHECKOUT_URL = "https://sandbox.azampay.co.tz/azampay/mno/checkout";
const AUTH_URL =
  "https://authenticator-sandbox.azampay.co.tz/AppRegistration/GenerateToken";

const DEFAULT_PREMIUM_PRODUCT_ID = "premium_monthly";
const PREMIUM_PRODUCT_IDS = ["premium_daily", "premium_weekly", "premium_monthly"];
const BILLING_DAYS = {
  daily: 1,
  weekly: 7,
  monthly: 30,
};
const ALLOWED_PROVIDERS = ["airtel", "vodacom", "tigo", "mixx"];
const SIGNAL_STATUS_OPEN = "open";
const SIGNAL_STATUS_VOTING = "voting";
const SIGNAL_STATUS_EXPIRED_UNVERIFIED = "expired_unverified";
const SIGNAL_BATCH_LIMIT = 200;
const SIGNAL_TOPIC_PREFIX = "trader_";
const SIGNAL_NOTIFICATION_CHANNEL = "signals";

function mapProviderToAzam(providerLower) {
  const normalized = String(providerLower || "").toLowerCase();
  const map = {
    airtel: "Airtel",
    vodacom: "Mpesa",
    tigo: "Tigo",
    mixx: "Azampesa",
  };
  return map[normalized] || null;
}

// ===================== HELPERS =====================
const SENSITIVE_LOG_KEYS = new Set([
  "accountNumber",
  "msisdn",
  "phoneNumber",
  "accessToken",
  "clientSecret",
  "authorization",
  "Authorization",
]);

function maskValue(value, visible = 4) {
  const str = String(value || "");
  if (!str) {
    return str;
  }
  if (str.length <= visible) {
    return "*".repeat(str.length);
  }
  return `${"*".repeat(str.length - visible)}${str.slice(-visible)}`;
}

function redactForLog(value) {
  if (Array.isArray(value)) {
    return value.map((item) => redactForLog(item));
  }
  if (value && typeof value === "object") {
    const next = {};
    for (const [key, val] of Object.entries(value)) {
      if (SENSITIVE_LOG_KEYS.has(key)) {
        next[key] = maskValue(val);
      } else {
        next[key] = redactForLog(val);
      }
    }
    return next;
  }
  return value;
}

function getBearerToken(req) {
  const authHeader = req.headers.authorization || "";
  if (!authHeader.startsWith("Bearer ")) {
    return null;
  }
  return authHeader.replace("Bearer ", "");
}

async function requireAuth(req, res) {
  const token = getBearerToken(req);
  if (!token) {
    res.status(401).json({ success: false, message: "Unauthorized" });
    return null;
  }
  try {
    return await admin.auth().verifyIdToken(token);
  } catch (error) {
    console.error("Auth error:", error.message);
    res.status(401).json({ success: false, message: "Unauthorized" });
    return null;
  }
}

function resolveValidUntil(data) {
  const preview = data?.preview || {};
  const value = data?.validUntil || preview.validUntil;
  if (!value) {
    return null;
  }
  if (value instanceof admin.firestore.Timestamp) {
    return value;
  }
  if (value?.toDate) {
    return value;
  }
  if (value instanceof Date) {
    return admin.firestore.Timestamp.fromDate(value);
  }
  return null;
}

function chunkArray(list, size) {
  const chunks = [];
  for (let i = 0; i < list.length; i += size) {
    chunks.push(list.slice(i, i + size));
  }
  return chunks;
}

async function sendToTokens(tokens, message) {
  if (!tokens.length) {
    return { successCount: 0, failureCount: 0 };
  }
  const chunks = chunkArray(tokens, 500);
  let successCount = 0;
  let failureCount = 0;
  for (const chunk of chunks) {
    const response = await admin.messaging().sendEachForMulticast({
      ...message,
      tokens: chunk,
    });
    successCount += response.successCount;
    failureCount += response.failureCount;
  }
  return { successCount, failureCount };
}

async function sendToTopic(topic, message) {
  return admin.messaging().send({
    ...message,
    topic,
  });
}

async function notifyAdminsOnRevenue({
  amount,
  currency,
  productId,
  uid,
  intentId,
}) {
  const adminsSnap = await db.collection("users").where("role", "==", "admin").get();
  if (adminsSnap.empty) {
    return;
  }

  const tokens = [];
  for (const doc of adminsSnap.docs) {
    const tokensSnap = await doc.ref.collection("tokens").get();
    tokensSnap.docs.forEach((tokenDoc) => {
      if (tokenDoc.id) {
        tokens.push(tokenDoc.id);
      }
    });
  }

  if (!tokens.length) {
    return;
  }

  await sendToTokens(tokens, {
    notification: {
      title: "New premium subscription",
      body: `${amount} ${currency} • ${productId}`,
    },
    data: {
      type: "revenue",
      uid: String(uid || ""),
      intentId: String(intentId || ""),
      amount: String(amount || ""),
      currency: String(currency || ""),
      productId: String(productId || ""),
    },
  });
}

async function updateRevenueStats({ amount, currency }) {
  const now = new Date();
  const monthKey = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;
  const dayKey = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}-${String(
    now.getDate()
  ).padStart(2, "0")}`;

  const statsRef = db.collection("revenue_stats").doc("global");
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(statsRef);
    const data = snap.exists ? snap.data() || {} : {};
    const increment = Number(amount || 0);

    const next = {
      totalRevenue: (data.totalRevenue || 0) + increment,
      totalPayments: (data.totalPayments || 0) + 1,
      currency: currency || data.currency || "TZS",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (data.currentMonth === monthKey) {
      next.currentMonth = monthKey;
      next.currentMonthRevenue = (data.currentMonthRevenue || 0) + increment;
      next.currentMonthPayments = (data.currentMonthPayments || 0) + 1;
    } else {
      next.currentMonth = monthKey;
      next.currentMonthRevenue = increment;
      next.currentMonthPayments = 1;
    }

    if (data.todayDate === dayKey) {
      next.todayDate = dayKey;
      next.todayRevenue = (data.todayRevenue || 0) + increment;
      next.todayPayments = (data.todayPayments || 0) + 1;
    } else {
      next.todayDate = dayKey;
      next.todayRevenue = increment;
      next.todayPayments = 1;
    }

    tx.set(statsRef, next, { merge: true });
  });
}

async function getAzamPayToken() {
  const appName = AZAMPAY_CONFIG.app_name;
  const clientId = AZAMPAY_CONFIG.client_id;
  const clientSecret = AZAMPAY_CONFIG.client_secret;
  if (!appName || !clientId || !clientSecret) {
    throw new Error("AzamPay config is missing (app_name, client_id, client_secret)");
  }
  try {
    console.log("AzamPay auth request:", {
      url: AUTH_URL,
      appName,
      clientId: maskValue(clientId, 6),
    });
    const response = await axios.post(
      AUTH_URL,
      {
        appName,
        clientId,
        clientSecret,
      },
      { headers: { "Content-Type": "application/json" } }
    );

    const token = response?.data?.data?.accessToken;
    if (!token) {
      throw new Error("AzamPay token missing");
    }
    console.log("AzamPay auth response:", {
      status: response.status,
      hasToken: Boolean(token),
    });
    return token;
  } catch (error) {
    console.error(
      "Error generating token:",
      redactForLog(error.response?.data || error.message)
    );
    throw new Error("Failed to authenticate with AzamPay");
  }
}

function normalizeBillingPeriod(productId, billingPeriodRaw) {
  const period = String(billingPeriodRaw || "").toLowerCase();
  if (period === "daily" || period === "weekly" || period === "monthly") {
    return period;
  }
  if (String(productId || "").includes("daily")) {
    return "daily";
  }
  if (String(productId || "").includes("weekly")) {
    return "weekly";
  }
  return "monthly";
}

function durationDaysForProduct(productId, billingPeriodRaw) {
  const period = normalizeBillingPeriod(productId, billingPeriodRaw);
  return BILLING_DAYS[period] || BILLING_DAYS.monthly;
}

async function loadPremiumProduct(productId) {
  const snap = await db.collection("products").doc(productId).get();
  if (!snap.exists) {
    throw new Error(`products/${productId} not found`);
  }
  const data = snap.data() || {};
  if (data.isActive !== true) {
    throw new Error("Premium product is inactive");
  }
  const amount = Number(data.price || 0);
  const currency = String(data.currency || "TZS");
  if (!amount || amount <= 0) {
    throw new Error("Invalid premium product price");
  }
  const billingPeriod = normalizeBillingPeriod(productId, data.billingPeriod);
  const durationDays = durationDaysForProduct(productId, data.billingPeriod);
  return {
    amount,
    currency,
    title: String(data.title || "Premium"),
    billingPeriod,
    durationDays,
  };
}

async function activatePremiumMembership(uid, paymentRef, durationDays) {
  const startedAt = admin.firestore.Timestamp.now();
  const expiresAt = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() + Number(durationDays || BILLING_DAYS.monthly) * 24 * 60 * 60 * 1000)
  );
  await db.collection("users").doc(uid).set(
    {
      membership: {
        tier: "premium",
        status: "active",
        startedAt,
        expiresAt,
        lastPaymentRef: paymentRef || null,
        updatedAt: startedAt,
      },
    },
    { merge: true }
  );
}

// ===================== 1) INITIATE CHECKOUT =====================
exports.initiatePremiumCheckout = functions.https.onRequest(async (req, res) => {
  try {
    if (req.method !== "POST") {
      return res.status(405).json({ success: false, message: "Method not allowed" });
    }

    const { jwtToken, accountNumber, provider, productId } = req.body || {};
    console.log("initiatePremiumCheckout body:", redactForLog(req.body));

    if (!jwtToken) {
      return res.status(400).json({ success: false, message: "Missing jwtToken" });
    }
    if (!accountNumber) {
      return res.status(400).json({ success: false, message: "Missing accountNumber" });
    }
    if (!provider) {
      return res.status(400).json({ success: false, message: "Missing provider" });
    }

    const providerLower = String(provider).toLowerCase();
    if (!ALLOWED_PROVIDERS.includes(providerLower)) {
      return res.status(400).json({
        success: false,
        message: "Invalid provider. Use airtel, vodacom, tigo, mixx (lowercase).",
      });
    }

    const pid = String(productId || DEFAULT_PREMIUM_PRODUCT_ID);
    if (!PREMIUM_PRODUCT_IDS.includes(pid)) {
      return res.status(400).json({
        success: false,
        message: "Invalid productId. Use premium_daily, premium_weekly, premium_monthly.",
      });
    }

    const decoded = await admin.auth().verifyIdToken(jwtToken);
    const uid = decoded.uid;

    const product = await loadPremiumProduct(pid);

    const externalId = `prem_${uid}_${Date.now()}`;
    const intentRef = db.collection("payment_intents").doc();
    const intentId = intentRef.id;

    await intentRef.set({
      uid,
      productId: pid,
      amount: product.amount,
      currency: product.currency,
      billingPeriod: product.billingPeriod,
      durationDays: product.durationDays,
      provider: providerLower,
      msisdn: String(accountNumber),
      status: "created",
      externalId,
      providerRef: null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 30 * 60 * 1000)),
    });

    const azamToken = await getAzamPayToken();
    const azamProvider = mapProviderToAzam(providerLower);
    if (!azamProvider) {
      await intentRef.update({
        status: "failed",
        failReason: `Provider mapping not found for ${providerLower}`,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return res.status(400).json({
        success: false,
        message: `Provider mapping not configured for ${providerLower}`,
      });
    }

    const checkoutPayload = {
      accountNumber: String(accountNumber),
      amount: String(product.amount),
      currency: product.currency,
      externalId,
      provider: azamProvider,
      additionalProperties: {
        property1: uid,
        property2: intentId,
      },
    };

    console.log("AzamPay checkout request:", {
      url: CHECKOUT_URL,
      payload: redactForLog(checkoutPayload),
    });

    const azamRes = await axios.post(CHECKOUT_URL, checkoutPayload, {
      headers: {
        Authorization: `Bearer ${azamToken}`,
        "Content-Type": "application/json",
      },
    });
    console.log("AzamPay checkout response:", {
      status: azamRes.status,
      data: redactForLog(azamRes.data),
    });

    const providerRef =
      azamRes.data?.transactionId ||
      azamRes.data?.data?.transactionId ||
      azamRes.data?.reference ||
      null;

    await intentRef.update({
      status: "pending",
      providerRef,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return res.status(200).json({
      success: true,
      intentId,
      externalId,
      azamResponse: azamRes.data,
    });
  } catch (error) {
    console.error(
      "Error processing premium payment:",
      redactForLog(error.response?.data || error.message)
    );
    return res.status(500).json({ success: false, message: "Internal server error" });
  }
});

// ===================== 2) WEBHOOK CALLBACK =====================
async function handleAzamPayPremiumWebhook(req, res) {
  try {
    const body = req.body || {};
    console.log("AzamPay callback:", redactForLog(body));

    const externalId =
      body.utilityref ||
      body.utilityRef ||
      body.externalId ||
      body.external_id ||
      body.externalID ||
      null;
    const additional = body.additionalProperties || {};
    const intentId = additional.property2 || null;

    const statusRaw =
      body.transactionstatus ||
      body.transactionStatus ||
      body.status ||
      body.statusCode ||
      null;
    const status = String(statusRaw || "").toLowerCase();
    const transid = body.transid || body.transactionId || body.transaction_id || null;
    const mnoreference = body.mnoreference || body.mnoReference || null;
    const message = body.message || body.description || null;

    let intentRef = null;
    let intent = null;

    if (intentId) {
      const docRef = db.collection("payment_intents").doc(String(intentId));
      const docSnap = await docRef.get();
      if (docSnap.exists) {
        intentRef = docRef;
        intent = docSnap.data() || {};
      }
    }

    if (!intentRef && externalId) {
      const snapshot = await db
        .collection("payment_intents")
        .where("externalId", "==", externalId)
        .limit(1)
        .get();

      if (!snapshot.empty) {
        const doc = snapshot.docs[0];
        intentRef = doc.ref;
        intent = doc.data() || {};
      }
    }

    if (!intentRef) {
      console.error("Payment intent not found:", { externalId, intentId });
      return res.status(404).send("Payment intent not found");
    }

    if (intent.status === "paid") {
      return res.status(200).send("Already paid");
    }

    const success = status === "success" || status === "completed" || status === "paid";

    if (success) {
      await intentRef.update({
        status: "paid",
        transid: transid || null,
        mnoreference: mnoreference || null,
        message: message || null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        paidAt: admin.firestore.FieldValue.serverTimestamp(),
        rawResponse: body,
      });
      const paymentRef = transid || mnoreference || externalId || intentRef.id;
      const durationDays =
        Number(intent?.durationDays) ||
        durationDaysForProduct(intent?.productId || DEFAULT_PREMIUM_PRODUCT_ID, intent?.billingPeriod);
      await activatePremiumMembership(intent.uid, paymentRef, durationDays);

      const amountValue = Number(intent?.amount || body.amount || 0);
      const currencyValue = intent?.currency || body.currency || "TZS";
      const successRef = db.collection("success_payment").doc(intentRef.id);
      let successCreated = false;
      try {
        await successRef.create({
          intentId: intentRef.id,
          uid: intent?.uid || null,
          productId: intent?.productId || null,
          billingPeriod: intent?.billingPeriod || null,
          durationDays: intent?.durationDays || null,
          amount: amountValue,
          currency: currencyValue,
          provider: intent?.provider || null,
          msisdn: intent?.msisdn || null,
          externalId: externalId || null,
          transid: transid || null,
          mnoreference: mnoreference || null,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        successCreated = true;
      } catch (error) {
        const message = error?.message || "";
        if (!message.includes("already exists")) {
          console.error("success_payment create failed:", error);
        }
      }

      if (successCreated) {
        await updateRevenueStats({
          amount: amountValue,
          currency: currencyValue,
        });

        await db.collection("admin_notifications").add({
          type: "revenue",
          title: "New premium subscription",
          message: `${amountValue} ${currencyValue} • ${intent?.productId || ""}`,
          amount: amountValue,
          currency: currencyValue,
          productId: intent?.productId || null,
          uid: intent?.uid || null,
          intentId: intentRef.id,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          read: false,
        });

        await notifyAdminsOnRevenue({
          amount: amountValue,
          currency: currencyValue,
          productId: intent?.productId,
          uid: intent?.uid,
          intentId: intentRef.id,
        });
      }
      return res.status(200).send("Callback received");
    }

    await intentRef.update({
      status: "failed",
      transid: transid || null,
      mnoreference: mnoreference || null,
      message: message || null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      rawResponse: body,
    });
    return res.status(200).send("Callback received");
  } catch (error) {
    console.error("Error processing callback:", error);
    return res.status(500).send("Internal Server Error");
  }
}

exports.azamPayCallback = functions.https.onRequest(handleAzamPayPremiumWebhook);
exports.azamPayPremiumWebhook = functions.https.onRequest(handleAzamPayPremiumWebhook);

// ===================== NOTIFICATIONS =====================
exports.sendTestSignalNotification = functions.https.onRequest(async (req, res) => {
  if (req.method !== "POST") {
    return res.status(405).json({ success: false, message: "Method not allowed" });
  }

  const decoded = await requireAuth(req, res);
  if (!decoded) {
    return;
  }

  try {
    const body = req.body || {};
    const traderUid = String(body.traderUid || "").trim();
    const signalId = String(body.signalId || "").trim();
    const tokensSnap = await db
      .collection("users")
      .doc(decoded.uid)
      .collection("tokens")
      .get();
    const tokens = tokensSnap.docs.map((doc) => doc.id).filter(Boolean);
    if (!tokens.length) {
      return res.status(404).json({
        success: false,
        message: "No notification tokens for user",
      });
    }

    const message = {
      notification: {
        title: "Test signal notification",
        body: traderUid
          ? `New signal from ${traderUid}.`
          : "You will receive alerts for new signals.",
      },
      data: {
        type: "new_signal",
        signalId,
        traderUid,
      },
      android: {
        notification: {
          channelId: SIGNAL_NOTIFICATION_CHANNEL,
        },
      },
    };

    const result = await sendToTokens(tokens, message);
    return res.status(200).json({ success: true, ...result });
  } catch (error) {
    console.error("sendTestSignalNotification error:", error);
    return res.status(500).json({
      success: false,
      message: "Unable to send test notification",
    });
  }
});

exports.recordAffiliateClick = functions.https.onRequest(async (req, res) => {
  if (req.method !== "POST") {
    return res.status(405).json({ success: false, message: "Method not allowed" });
  }

  const decoded = await requireAuth(req, res);
  if (!decoded) {
    return;
  }

  try {
    const affiliateId = String(req.body?.affiliateId || "").trim();
    if (!affiliateId) {
      return res.status(400).json({
        success: false,
        message: "affiliateId is required",
      });
    }

    const affiliateRef = db.collection("affiliates").doc(affiliateId);
    await affiliateRef.set(
      {
        clickCount: admin.firestore.FieldValue.increment(1),
        lastClickedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    await affiliateRef.collection("clicks").add({
      uid: decoded.uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return res.status(200).json({ success: true });
  } catch (error) {
    console.error("recordAffiliateClick error:", error);
    return res.status(500).json({
      success: false,
      message: "Unable to record click",
    });
  }
});

// ===================== AZAMPAY ORDER FLOW =====================
exports.azamPay = functions.https.onRequest(async (req, res) => {
  try {
    console.log("AzamPay callback:", JSON.stringify(req.body));

    const body = req.body || {};
    const {
      transactionstatus,
      transid,
      utilityref,
      mnoreference,
      msisdn,
      amount,
      additionalProperties,
    } = body;

    const externalId = utilityref || null;
    const props = additionalProperties || {};
    const userId = props.property1 || null;
    const bookID = props.property2 || null;

    if (transactionstatus === "success") {
      const orderDataArray = [];
      let idsArray = [];

      if (Array.isArray(bookID)) {
        idsArray = bookID.map((id) => String(id));
      } else if (typeof bookID === "string" && bookID.length > 0) {
        const trimmed = bookID.trim();
        if (trimmed.startsWith("[") && trimmed.endsWith("]")) {
          idsArray = trimmed
            .substring(1, trimmed.length - 1)
            .split(",")
            .map((id) => id.trim())
            .filter(Boolean);
        } else {
          idsArray.push(trimmed);
        }
      }

      if (!idsArray.length) {
        idsArray.push(String(bookID || ""));
      }

      for (const id of idsArray) {
        const orderData = {
          userId,
          bookID: id,
          amount,
          msisdn,
          transid,
          mnoreference,
          transactionstatus,
          externalId,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        };
        orderDataArray.push(orderData);
      }

      await Promise.all(
        orderDataArray.map((orderData) =>
          db.collection("Users_Order").add(orderData)
        )
      );

      return res.status(200).send("Order(s) created successfully.");
    }

    await db.collection("failed_order").add({
      userId,
      bookID,
      amount,
      msisdn,
      transid,
      mnoreference,
      transactionstatus,
      externalId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return res.status(400).send("Payment was not successful.");
  } catch (error) {
    console.error("Error creating order:", error);
    return res.status(500).send("Error creating order.");
  }
});

exports.processOrder = functions.https.onRequest(async (req, res) => {
  try {
    const body = req.body || {};
    console.log("processOrder body:", redactForLog(body));
    const {
      amount,
      externalId,
      provider,
      accountNumber,
      jwtToken,
      azamToken,
      additionalProperties,
    } = body;
    const props = additionalProperties || {};
    const bookID = props.property2;
    const token = jwtToken || getBearerToken(req);

    if (!token) {
      return res.status(401).json({ success: false, message: "Unauthorized" });
    }

    const user = await admin.auth().verifyIdToken(token);
    const userId = user.uid;

    if (!accountNumber || !provider) {
      return res.status(400).json({
        success: false,
        message: "accountNumber and provider are required",
      });
    }

    const normalizedProvider = mapProviderToAzam(provider) || provider;
    if (!normalizedProvider) {
      return res.status(400).json({
        success: false,
        message: "Invalid provider",
      });
    }

    const requestData = {
      accountNumber,
      additionalProperties: {
        property1: userId,
        property2: bookID,
        source: "pastory",
      },
      amount,
      currency: "TZS",
      externalId,
      provider: normalizedProvider,
    };

    console.log("AzamPay checkout request (processOrder):", {
      url: CHECKOUT_URL,
      payload: redactForLog(requestData),
    });

    const tokenToUse = azamToken || (await getAzamPayToken());
    const headers = {
      Authorization: `Bearer ${tokenToUse}`,
      "Content-Type": "application/json",
    };

    const response = await axios.post(CHECKOUT_URL, requestData, { headers });
    console.log("AzamPay checkout response (processOrder):", {
      status: response.status,
      data: redactForLog(response.data),
    });

    if (response.status === 200) {
      const responseData = response.data || {};
      if (responseData.success === false) {
        return res
          .status(400)
          .json({ success: false, message: "Payment failed", data: responseData });
      }
      return res.status(200).json({
        success: true,
        message: "Order processed successfully",
        data: responseData,
      });
    }

    return res
      .status(response.status)
      .json({ success: false, message: "Request failed" });
  } catch (error) {
    console.error(
      "Error processing order:",
      redactForLog(error.response?.data || error.message)
    );
    return res
      .status(500)
      .json({ success: false, message: "Internal server error" });
  }
});

exports.mostBookSold = functions.https.onRequest(async (req, res) => {
  try {
    const ordersSnapshot = await db.collection("Users_Order").get();

    const booksCount = {};
    ordersSnapshot.forEach((order) => {
      const bookID = order.data().bookID;
      if (!bookID) {
        return;
      }
      booksCount[bookID] = (booksCount[bookID] || 0) + 1;
    });

    const booksArray = Object.keys(booksCount).map((key) => ({
      bookID: key,
      count: booksCount[key],
    }));

    booksArray.sort((a, b) => b.count - a.count);
    const mostSoldBooks = booksArray.slice(0, 7);

    const booksPromises = mostSoldBooks.map(async (book) => {
      const bookSnapshot = await db.collection("books").doc(book.bookID).get();
      return { id: book.bookID, count: book.count, ...bookSnapshot.data() };
    });

    const mostSoldBooksData = await Promise.all(booksPromises);
    console.log("Most Sold Books:", mostSoldBooksData);

    return res.status(200).json(mostSoldBooksData);
  } catch (error) {
    console.error("Error retrieving most sold books:", error);
    return res.status(500).send("Error retrieving most sold books.");
  }
});

exports.notifyOnSignalCreate = functions.firestore
  .document("signals/{signalId}")
  .onCreate(async (snap, context) => {
    const data = snap.data() || {};
    const status = String(data.status || SIGNAL_STATUS_OPEN).toLowerCase();
    if (status === "hidden") {
      return null;
    }

    const traderUid = String(data.uid || "").trim();
    if (!traderUid) {
      return null;
    }

    const preview = data.preview || {};
    const pair = preview.pair || data.pair || "New signal";
    const direction = preview.direction || data.direction || "";
    const title = "New trading signal";
    const body = `${pair} ${direction}`.trim();

    const message = {
      notification: { title, body },
      data: {
        type: "new_signal",
        signalId: context.params.signalId,
        traderUid,
      },
      android: {
        notification: {
          channelId: SIGNAL_NOTIFICATION_CHANNEL,
        },
      },
    };

    try {
      await sendToTopic(`${SIGNAL_TOPIC_PREFIX}${traderUid}`, message);
    } catch (error) {
      console.error("notifyOnSignalCreate error:", error);
    }
    return null;
  });

exports.processSignalExpirations = functions.pubsub
  .schedule("every 5 minutes")
  .timeZone("Africa/Dar_es_Salaam")
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();
    const openSnap = await db
      .collection("signals")
      .where("status", "==", SIGNAL_STATUS_OPEN)
      .where("preview.validUntil", "<=", now)
      .limit(SIGNAL_BATCH_LIMIT)
      .get();

    if (!openSnap.empty) {
      const batch = db.batch();
      openSnap.docs.forEach((doc) => {
        const data = doc.data() || {};
        const validUntil = resolveValidUntil(data);
        if (!validUntil) {
          return;
        }
        batch.update(doc.ref, {
          status: SIGNAL_STATUS_EXPIRED_UNVERIFIED,
          lockVotes: true,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });
      await batch.commit();
    }

    const votingSnap = await db
      .collection("signals")
      .where("status", "==", SIGNAL_STATUS_VOTING)
      .where("preview.validUntil", "<=", now)
      .limit(SIGNAL_BATCH_LIMIT)
      .get();

    if (!votingSnap.empty) {
      const batch = db.batch();
      votingSnap.docs.forEach((doc) => {
        batch.update(doc.ref, {
          status: SIGNAL_STATUS_EXPIRED_UNVERIFIED,
          lockVotes: true,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });
      await batch.commit();
    }

    console.log("processSignalExpirations done", {
      openExpired: openSnap.size,
      votingExpired: votingSnap.size,
    });
    return null;
  });

// ===================== 3) DAILY EXPIRY CLEANUP =====================
exports.expireMembershipsDaily = functions.pubsub
  .schedule("every day 03:00")
  .timeZone("Africa/Dar_es_Salaam")
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();
    const snapshot = await db
      .collection("users")
      .where("membership.tier", "==", "premium")
      .get();

    const batch = db.batch();
    let count = 0;
    snapshot.docs.forEach((doc) => {
      const data = doc.data() || {};
      const expiresAt = data?.membership?.expiresAt;
      if (expiresAt && expiresAt.toMillis && expiresAt.toMillis() < now.toMillis()) {
        batch.set(
          doc.ref,
          {
            membership: {
              tier: "free",
              status: "inactive",
              updatedAt: now,
            },
          },
          { merge: true }
        );
        count++;
      }
    });

    if (count > 0) {
      await batch.commit();
    }
    console.log("expireMembershipsDaily downgraded:", count);
    return null;
  });
