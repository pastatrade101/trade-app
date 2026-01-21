// @ts-nocheck
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require("axios");
const crypto = require("crypto");
const { XMLParser } = require("fast-xml-parser");

admin.initializeApp();
const db = admin.firestore();

// ===================== CONFIG =====================
const AZAMPAY_CONFIG = {
  app_name: "Makutano-app",
  client_id: "18512733-5a9c-4bc6-bbf1-d0285b0e515a",
  client_secret:
    "VcttCrIHmXlf7NeHe7KuvLk3Jgr+ajH8Dfyd5X7kUjwzzRnUNFQEyErdFGpGYldhs/aOEKaz0+1jQZmSNVWxaVxxKkgon84kFoON1fJBj+eJprWB8JyqkkABze7naMYQ+8VQ++biRkXzWhAvN7vrVvowa9pzwTVFdpULgm4y7F+dP0oyZI56dStIGt1sgGpal2XFTnYc+iGDn8WOPkR4tsffy9mg5pe3Rm753k3go5rd+gJnKJf3ntNeH/1O7kZB0z+rYxTIl3yN5ZvRlApYyjBeXrd78/899qvjUDUBv7U6M9u1rjxhaY0MigYd+PX8di1ubkbvp3MGb4bk+l9FGNr+D+W9kPM/pGEnIzirVA5S66ItMZBBTWj3H7woiRorJF7W101f5jlnp5mpsfaZXHvD4slGRGFj1XP3V23ihdOvqi/F8hEhLIylnV34r09pt+WBdFk6cMw+7kBRR3XxMF/U4hW3PvFea7TfXziIiLOC9gDtPn7ce6QWrOdTrgJsWVTIpvzdHAjKP0lv66Z0AHQFkB1G+vFMCaH2GaXuFb637pnt1QYC5JK3hgzaiNU+8z5y2EngHu+KRiHUnF1najykjANiNlHAV9BIU4I4hIorKs2gvodrypl0eIigx7jSCPKPKn3byN9J7YnDdlomyRtK/ncad3co2CHyAqrokR0=",
};
const CHECKOUT_URL = "https://creatorstores.xyz/api/pastory/azampay/request/payment";
// const CHECKOUT_URL = "https://sandbox.azampay.co.tz/azampay/mno/checkout";
const AUTH_URL =
  "https://authenticator-sandbox.azampay.co.tz/AppRegistration/GenerateToken";

const DEFAULT_PREMIUM_PRODUCT_ID = "premium_monthly";
const PREMIUM_PRODUCT_IDS = ["premium_daily", "premium_weekly", "premium_monthly"];
const BILLING_DAYS = {
  daily: 1,
  weekly: 7,
  monthly: 30,
};
const ALLOWED_PROVIDERS = ["airtel", "vodacom", "tigo", "halopesa"];
const SIGNAL_STATUS_OPEN = "open";
const SIGNAL_STATUS_VOTING = "voting";
const SIGNAL_STATUS_EXPIRED_UNVERIFIED = "expired_unverified";
const SIGNAL_BATCH_LIMIT = 200;
const SIGNAL_TOPIC_PREFIX = "trader_";
const SIGNAL_NOTIFICATION_CHANNEL = "signals";
const PREMIUM_SESSIONS_TOPIC = "premium_sessions";
const NEWS_SOURCES = {
  fxstreet_forex: "https://www.fxstreet.com/rss/news",
  fxstreet_crypto: "https://www.fxstreet.com/rss/crypto",
  fxstreet_analysis: "https://www.fxstreet.com/rss/analysis",
};
const NEWS_SOURCE_KEYS = Object.keys(NEWS_SOURCES);
const NEWS_CACHE_TTL_MS = 5 * 60 * 1000;
const NEWS_FETCH_TIMEOUT_MS = 12000;
const NEWS_USER_AGENT = "MarketResolveTZRSS/1.0";
const NEWS_META_DOC_ID = "meta";
const NEWS_PARSER = new XMLParser({ ignoreAttributes: false });

const SESSION_DEFINITIONS = [
  { key: "asia", name: "Asia", openHour: 3, openMinute: 0 },
  { key: "london", name: "London", openHour: 11, openMinute: 0 },
  { key: "new_york", name: "New York", openHour: 16, openMinute: 0 },
];

function mapProviderToAzam(providerLower) {
  const normalized = String(providerLower || "").toLowerCase();
  const map = {
    airtel: "Airtel",
    vodacom: "Mpesa",
    tigo: "Tigo",
    halopesa: "Halopesa",
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

function ensureArray(value) {
  if (!value) {
    return [];
  }
  return Array.isArray(value) ? value : [value];
}

function pickRssText(value) {
  if (Array.isArray(value)) {
    for (const entry of value) {
      const resolved = pickRssText(entry);
      if (resolved) {
        return resolved;
      }
    }
    return "";
  }
  if (value == null) {
    return "";
  }
  if (typeof value === "string" || typeof value === "number") {
    return String(value);
  }
  if (typeof value === "object") {
    const text = value["#text"];
    if (text != null) {
      return String(text);
    }
  }
  return "";
}

function decodeHtmlEntities(value) {
  return String(value || "")
    .replace(/&nbsp;/gi, " ")
    .replace(/&amp;/gi, "&")
    .replace(/&quot;/gi, '"')
    .replace(/&#39;/gi, "'")
    .replace(/&lt;/gi, "<")
    .replace(/&gt;/gi, ">");
}

function stripHtml(value) {
  return decodeHtmlEntities(String(value || ""))
    .replace(/<[^>]*>/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function resolvePublishedAt(value) {
  const raw = pickRssText(value);
  if (!raw) {
    return null;
  }
  const parsed = new Date(raw);
  if (Number.isNaN(parsed.getTime())) {
    return null;
  }
  return parsed.toISOString();
}

function resolveNewsId({ guid, title, link, publishedAt }) {
  const guidValue = String(guid || "").trim();
  if (guidValue) {
    return guidValue;
  }
  const hashBase = `${title || ""}|${link || ""}|${publishedAt || ""}`;
  return crypto.createHash("sha1").update(hashBase).digest("hex");
}

function parseNewsItemsFromXml(xmlText) {
  const parsed = NEWS_PARSER.parse(xmlText);
  const channel = parsed?.rss?.channel;
  const items = ensureArray(channel?.item);
  return items
    .map((item) => {
      const title = pickRssText(item.title);
      const link = pickRssText(item.link);
      const description = stripHtml(
        pickRssText(item.description || item["content:encoded"])
      );
      const publishedAt =
        resolvePublishedAt(item.pubDate || item.published || item["dc:date"]) ||
        new Date(0).toISOString();
      const guid = pickRssText(item.guid) || link;
      const id = resolveNewsId({ guid, title, link, publishedAt });
      return {
        id,
        title,
        link,
        description,
        publishedAt,
      };
    })
    .filter((item) => item.title && item.link);
}

function dedupeAndSortNews(items) {
  const map = new Map();
  for (const item of items) {
    if (!item?.id) {
      continue;
    }
    if (!map.has(item.id)) {
      map.set(item.id, item);
    }
  }
  return Array.from(map.values()).sort((a, b) => {
    const left = new Date(a.publishedAt).getTime();
    const right = new Date(b.publishedAt).getTime();
    return right - left;
  });
}

async function readCachedNews(source) {
  const sourceRef = db.collection("news_cache").doc(source);
  const itemsRef = sourceRef.collection("items");
  const metaRef = sourceRef.collection("meta").doc(NEWS_META_DOC_ID);
  const [metaSnap, itemsSnap] = await Promise.all([
    metaRef.get(),
    itemsRef.get(),
  ]);
  const items = itemsSnap.docs.map((doc) => {
    const data = doc.data() || {};
    return {
      id: data.id || doc.id,
      title: data.title || "",
      link: data.link || "",
      description: data.description || "",
      publishedAt: data.publishedAt || new Date(0).toISOString(),
    };
  });
  const lastFetchedAt = metaSnap.exists ? metaSnap.get("lastFetchedAt") : null;
  const lastFetchedMs = lastFetchedAt?.toMillis?.() || 0;
  const fresh = lastFetchedMs > 0 && Date.now() - lastFetchedMs < NEWS_CACHE_TTL_MS;
  return { items: dedupeAndSortNews(items), fresh };
}

async function fetchAndCacheNews(source) {
  const url = NEWS_SOURCES[source];
  if (!url) {
    throw new Error(`Unsupported news source: ${source}`);
  }
  const response = await axios.get(url, {
    headers: { "User-Agent": NEWS_USER_AGENT },
    timeout: NEWS_FETCH_TIMEOUT_MS,
  });
  const parsedItems = parseNewsItemsFromXml(response.data);
  const items = dedupeAndSortNews(parsedItems);
  const sourceRef = db.collection("news_cache").doc(source);
  const itemsRef = sourceRef.collection("items");
  const metaRef = sourceRef.collection("meta").doc(NEWS_META_DOC_ID);
  const existing = await itemsRef.get();
  const batch = db.batch();
  const keepIds = new Set(items.map((item) => item.id));
  existing.docs.forEach((doc) => {
    if (!keepIds.has(doc.id)) {
      batch.delete(doc.ref);
    }
  });
  items.forEach((item) => {
    batch.set(itemsRef.doc(item.id), item, { merge: true });
  });
  batch.set(
    metaRef,
    { lastFetchedAt: admin.firestore.FieldValue.serverTimestamp() },
    { merge: true }
  );
  await batch.commit();
  return items;
}

async function getUserTokens(uid) {
  if (!uid) {
    return [];
  }
  const tokensSnap = await db
    .collection("users")
    .doc(uid)
    .collection("tokens")
    .get();
  return tokensSnap.docs.map((doc) => doc.id).filter(Boolean);
}

async function getTokensByRoles(roles) {
  if (!roles || !roles.length) {
    return [];
  }
  const usersSnap = await db.collection("users").where("role", "in", roles).get();
  const tokens = [];
  for (const userDoc of usersSnap.docs) {
    const tokensSnap = await userDoc.ref.collection("tokens").get();
    tokensSnap.docs.forEach((tokenDoc) => {
      if (tokenDoc.id) {
        tokens.push(tokenDoc.id);
      }
    });
  }
  return tokens;
}

async function resolveMemberName(uid) {
  if (!uid) {
    return "Member";
  }
  const snap = await db.collection("users").doc(uid).get();
  if (!snap.exists) {
    return "Member";
  }
  const data = snap.data() || {};
  return (
    data.displayName ||
    data.username ||
    data.fullName ||
    data.phoneNumber ||
    data.email ||
    "Member"
  );
}

async function resolveProductTitle(productId) {
  if (!productId) {
    return "Premium";
  }
  const snap = await db.collection("products").doc(productId).get();
  if (!snap.exists) {
    return String(productId);
  }
  const data = snap.data() || {};
  return String(data.title || productId);
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

async function notifyAdminsOnTrial({ memberName, expiresAt, uid }) {
  const tokens = await getTokensByRoles(["admin", "trader_admin"]);
  if (!tokens.length) {
    return;
  }
  const friendlyName = memberName || "Member";
  const endsAtLabel = expiresAt
    ? new Date(
        expiresAt.toDate ? expiresAt.toDate() : expiresAt
      ).toLocaleString("en-US", {
        timeZone: "Africa/Dar_es_Salaam",
      })
    : null;
  const title = "Member trial activated";
  const body = endsAtLabel
    ? `${friendlyName} trial ends ${endsAtLabel}.`
    : `${friendlyName} started a global trial.`;
  await sendToTokens(tokens, {
    notification: {
      title,
      body,
    },
    data: {
      type: "member_trial",
      uid: String(uid || ""),
      expiresAt: expiresAt ? expiresAt.toDate().toISOString() : "",
    },
  });
}

function tanzaniaNow() {
  const now = new Date();
  const tzString = now.toLocaleString("en-US", {
    timeZone: "Africa/Dar_es_Salaam",
  });
  return new Date(tzString);
}

function isWeekendTanzania() {
  const day = tanzaniaNow().getDay();
  return day === 0 || day === 6;
}

function sessionOpenTimeLabel(openHour, openMinute) {
  const tzNow = tanzaniaNow();
  const openTime = new Date(
    tzNow.getFullYear(),
    tzNow.getMonth(),
    tzNow.getDate(),
    openHour,
    openMinute,
    0
  );
  return openTime.toISOString();
}

async function sendSessionReminder(session, options = {}) {
  if (!session) {
    return null;
  }
  const { force = false } = options || {};
  if (!force && isWeekendTanzania()) {
    console.log("Session reminder skipped (weekend)", session.key);
    return null;
  }
  const { key, name, openHour, openMinute } = session;
  const opensAt = sessionOpenTimeLabel(openHour, openMinute);
  return admin.messaging().send({
    topic: PREMIUM_SESSIONS_TOPIC,
    notification: {
      title: "Session Reminder",
      body: `${name} session opens in 1 hour. Stay focused and manage risk.`,
    },
    data: {
      type: "session_reminder",
      session: key,
      opensAt,
    },
    android: {
      notification: {
        channelId: SIGNAL_NOTIFICATION_CHANNEL,
      },
    },
  });
}

async function notifyAdminsOnRevenue({
  amount,
  currency,
  productId,
  uid,
  intentId,
  memberName,
  planTitle,
  billingPeriod,
  durationDays,
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

  const safeMember = memberName || "Member";
  const safePlan = planTitle || productId || "Premium";
  const periodLabel = billingPeriod ? ` • ${billingPeriod}` : "";
  const durationLabel = durationDays ? ` • ${durationDays}d` : "";
  await sendToTokens(tokens, {
    notification: {
      title: "New premium subscription",
      body: `${safeMember} • ${safePlan} • ${amount} ${currency}${periodLabel}${durationLabel}`,
    },
    data: {
      type: "revenue",
      uid: String(uid || ""),
      intentId: String(intentId || ""),
      amount: String(amount || ""),
      currency: String(currency || ""),
      productId: String(productId || ""),
      memberName: String(memberName || ""),
      planTitle: String(planTitle || ""),
      billingPeriod: String(billingPeriod || ""),
      durationDays: String(durationDays || ""),
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

async function activatePremiumMembership(uid, paymentRef, durationDays, options = {}) {
  const startedAt = admin.firestore.Timestamp.now();
  const lengthDays = Math.max(1, Number(durationDays || BILLING_DAYS.monthly));
  const expiresAt = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() + lengthDays * 24 * 60 * 60 * 1000)
  );
  const membershipPayload = {
    tier: "premium",
    status: "active",
    startedAt,
    expiresAt,
    lastPaymentRef: paymentRef || null,
    updatedAt: startedAt,
    source: options.source || "paid",
  };
  if (options.trialUsed === true) {
    membershipPayload.trialUsed = true;
  }
  await db.collection("users").doc(uid).set(
    {
      membership: membershipPayload,
    },
    { merge: true }
  );
  return expiresAt;
}

function toMillis(value) {
  if (!value) {
    return null;
  }
  if (value instanceof admin.firestore.Timestamp) {
    return value.toMillis();
  }
  if (value instanceof Date) {
    return value.getTime();
  }
  if (typeof value === "object" && value?.toMillis) {
    return value.toMillis();
  }
  const parsed = Date.parse(String(value));
  if (Number.isNaN(parsed)) {
    return null;
  }
  return parsed;
}

async function fetchGlobalOfferConfig() {
  const doc = await db.collection("app_config").doc("global_offer").get();
  if (!doc.exists) {
    return null;
  }
  const data = doc.data() || {};
  return {
    isActive: data.isActive === true,
    type: data.type === "discount" ? "discount" : "trial",
    trialDays: Number(data.trialDays || 0),
    discountPercent: Number(data.discountPercent || 0),
    label: String(data.label || ""),
    startsAt: data.startsAt || null,
    endsAt: data.endsAt || null,
    updatedAt: data.updatedAt || null,
  };
}

async function getActiveGlobalOffer() {
  const config = await fetchGlobalOfferConfig();
  if (
    !config ||
    !config.isActive ||
    (config.type === "trial" && (!config.trialDays || config.trialDays <= 0)) ||
    (config.type === "discount" &&
      (!config.discountPercent || config.discountPercent <= 0))
  ) {
    return null;
  }
  const nowMs = Date.now();
  const startMs = toMillis(config.startsAt);
  const endMs = toMillis(config.endsAt);
  if (startMs != null && nowMs < startMs) {
    return null;
  }
  if (endMs != null && nowMs > endMs) {
    return null;
  }
  return config;
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

    const userRef = db.collection("users").doc(uid);
    const userSnap = await userRef.get();
    const currentMembership = (userSnap.exists ? userSnap.data() : {}) || {};
    const trialUsed = currentMembership?.membership?.trialUsed === true;

    const product = await loadPremiumProduct(pid);
    const offer = await getActiveGlobalOffer();
    if (offer?.type === "trial" && !trialUsed) {
      const trialDays = Math.max(1, Math.floor(Number(offer.trialDays || 0)) || 1);
      const expiresAt = await activatePremiumMembership(
        uid,
        `trial_${uid}_${Date.now()}`,
        trialDays,
        {
          source: "trial",
          trialUsed: true,
        }
      );
      return res.status(200).json({
        success: true,
        trialActivated: true,
        offerType: "trial",
        offerLabel: offer.label || null,
        trialDays,
        trialExpiresAt: expiresAt.toDate().toISOString(),
      });
    }

    const externalId = `prem_${uid}_${Date.now()}`;
    const intentRef = db.collection("payment_intents").doc();
    const intentId = intentRef.id;
    const baseAmount = Number(product.amount || 0);
    const discountPercent = offer?.type === "discount"
      ? Math.min(100, Math.max(0, Number(offer.discountPercent || 0)))
      : 0;
    const discountedPrice =
      discountPercent > 0
        ? Math.max(
            0,
            Number((baseAmount * (1 - discountPercent / 100)).toFixed(0))
          )
        : baseAmount;
    const amountToCharge = discountPercent > 0 ? discountedPrice : baseAmount;

    await intentRef.set({
      uid,
      productId: pid,
      amount: amountToCharge,
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
      expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 50 * 1000)),
      offerType: offer?.type || null,
      offerLabel: offer?.label || null,
      originalPrice: baseAmount,
      discountedPrice: amountToCharge,
      discountPercent: discountPercent > 0 ? discountPercent : null,
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
      amount: amountToCharge,
      currency: String(product.currency),
      externalId: String(externalId),
      provider: azamProvider,
      additionalProperties: {
        property1: uid || null,
        property2: intentId || null,
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
      offerLabel: offer?.label || null,
      discountPercent: discountPercent > 0 ? discountPercent : null,
      originalPrice: baseAmount,
      discountedPrice: amountToCharge,
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

    const externalIdRaw =
      body.utilityref ||
      body.utilityRef ||
      body.externalId ||
      body.external_id ||
      body.externalID ||
      body.externalreference ||
      body.externalReference ||
      body.external_reference ||
      body.pgReferenceId ||
      body.initiatorReferenceId ||
      body.fspReferenceId ||
      null;
    const additional = body.additionalProperties || {};
    const intentId = additional.property2 || null;
    const providerRef =
      body.reference ||
      body.externalreference ||
      body.externalReference ||
      body.transid ||
      body.transactionId ||
      body.transaction_id ||
      body.pgReferenceId ||
      body.initiatorReferenceId ||
      body.fspReferenceId ||
      null;

    const statusRaw =
      body.transactionstatus ||
      body.transactionStatus ||
      body.status ||
      body.statusCode ||
      body.statusDescription ||
      body.status_description ||
      body.message ||
      body.description ||
      null;
    const status = String(statusRaw || "").toLowerCase();
    const transid =
      body.transid ||
      body.transactionId ||
      body.transaction_id ||
      body.pgReferenceId ||
      null;
    const mnoreference =
      body.mnoreference ||
      body.mnoReference ||
      body.fspReferenceId ||
      null;
    const message =
      body.message ||
      body.description ||
      body.statusDescription ||
      null;
    const externalId = externalIdRaw || providerRef || null;

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

    if (!intentRef && providerRef) {
      const snapshot = await db
        .collection("payment_intents")
        .where("providerRef", "==", providerRef)
        .limit(1)
        .get();

      if (!snapshot.empty) {
        const doc = snapshot.docs[0];
        intentRef = doc.ref;
        intent = doc.data() || {};
      }
    }

    if (!intentRef) {
      console.error("Payment intent not found:", {
        externalId,
        intentId,
        providerRef,
      });
      return res.status(404).send("Payment intent not found");
    }

    if (intent.status === "paid") {
      return res.status(200).send("Already paid");
    }

    const isSuccess =
      status.includes("success") ||
      status.includes("completed") ||
      status.includes("paid");
    const isPending =
      status.includes("pending") ||
      status.includes("processing") ||
      status.includes("queued") ||
      status.includes("initiated");
    const isFailed =
      status.includes("failed") ||
      status.includes("cancel") ||
      status.includes("declined") ||
      status.includes("rejected") ||
      status.includes("expired") ||
      status.includes("timeout") ||
      status.includes("reversed") ||
      status.includes("aborted");

    if (isSuccess) {
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
      const memberName = await resolveMemberName(intent?.uid);
      const planTitle = await resolveProductTitle(intent?.productId);
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
          message: `${memberName} • ${planTitle} • ${amountValue} ${currencyValue}`,
          amount: amountValue,
          currency: currencyValue,
          productId: intent?.productId || null,
          planTitle,
          billingPeriod: intent?.billingPeriod || null,
          durationDays: intent?.durationDays || null,
          memberName,
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
          memberName,
          planTitle,
          billingPeriod: intent?.billingPeriod,
          durationDays: intent?.durationDays,
        });
      }
      return res.status(200).send("Callback received");
    }

    if (isPending) {
      await intentRef.update({
        status: "pending",
        transid: transid || null,
        mnoreference: mnoreference || null,
        message: message || null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        rawResponse: admin.firestore.FieldValue.delete(),
      });
      return res.status(200).send("Callback received");
    }

    await intentRef.update({
      status: "failed",
      transid: transid || null,
      mnoreference: mnoreference || null,
      transactionstatus: statusRaw || null,
      message: message || null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      rawResponse: admin.firestore.FieldValue.delete(),
    });

    try {
      const amountValue = Number(intent?.amount || body.amount || 0);
      const currencyValue = intent?.currency || body.currency || "TZS";
      const failedRef = db.collection("failed_order").doc(intentRef.id);
      await failedRef.create({
        type: "premium",
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
        status,
        message: message || null,
        providerRef: providerRef || null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        rawResponse: body,
      });
    } catch (error) {
      const errMessage = error?.message || "";
      if (!errMessage.includes("already exists")) {
        console.error("failed_order create failed:", error);
      }
    }
    return res.status(200).send("Callback received");
  } catch (error) {
    console.error("Error processing callback:", error);
    return res.status(500).send("Internal Server Error");
  }
}

exports.azamPayCallback = functions.https.onRequest(handleAzamPayPremiumWebhook);

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

    if (traderUid) {
      await sendToTopic(`${SIGNAL_TOPIC_PREFIX}${traderUid}`, message);
      return res.status(200).json({ success: true, target: "topic" });
    }

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

    const result = await sendToTokens(tokens, message);
    return res.status(200).json({ success: true, target: "tokens", ...result });
  } catch (error) {
    console.error("sendTestSignalNotification error:", error);
    return res.status(500).json({
      success: false,
      message: "Unable to send test notification",
    });
  }
});

exports.sendTestSessionReminder = functions.https.onRequest(async (req, res) => {
  if (req.method !== "POST") {
    return res.status(405).json({ success: false, message: "Method not allowed" });
  }

  const decoded = await requireAuth(req, res);
  if (!decoded) {
    return;
  }

  try {
    const sessionKey = String(req.body?.session || "london").toLowerCase();
    const session =
      SESSION_DEFINITIONS.find((item) => item.key === sessionKey) ||
      SESSION_DEFINITIONS[1];
    await sendSessionReminder(session, { force: true });
    return res.status(200).json({ success: true });
  } catch (error) {
    console.error("sendTestSessionReminder error:", error);
    return res.status(500).json({
      success: false,
      message: "Unable to send test session reminder",
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
    console.log("AzamPay order webhook:", JSON.stringify(req.body));

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

    const amountValue = Number(amount);
    if (!Number.isFinite(amountValue) || amountValue <= 0) {
      return res.status(400).json({
        success: false,
        message: "amount must be a positive number",
      });
    }

    const requestData = {
      accountNumber: String(accountNumber),
      additionalProperties: {
        property1: userId || null,
        property2: bookID || null,
        source: "pastory",
      },
      amount: amountValue,
      currency: "TZS",
      externalId: String(externalId || ""),
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

exports.expirePaymentIntents = functions.pubsub
  .schedule("every 5 minutes")
  .timeZone("Africa/Dar_es_Salaam")
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();
    const snapshot = await db
      .collection("payment_intents")
      .where("status", "in", ["created", "pending"])
      .where("expiresAt", "<=", now)
      .limit(200)
      .get();

    if (snapshot.empty) {
      console.log("expirePaymentIntents done", { expired: 0 });
      return null;
    }

    const batch = db.batch();
    snapshot.docs.forEach((doc) => {
      batch.update(doc.ref, {
        status: "expired",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
    await batch.commit();

    await Promise.all(
      snapshot.docs.map(async (doc) => {
        const data = doc.data() || {};
        const failedRef = db.collection("failed_order").doc(doc.id);
        try {
          await failedRef.create({
            type: "premium",
            intentId: doc.id,
            uid: data.uid || null,
            productId: data.productId || null,
            billingPeriod: data.billingPeriod || null,
            durationDays: data.durationDays || null,
            amount: Number(data.amount || 0),
            currency: data.currency || "TZS",
            provider: data.provider || null,
            msisdn: data.msisdn || null,
            externalId: data.externalId || null,
            transid: data.transid || null,
            mnoreference: data.mnoreference || null,
            status: "expired",
            message: "expired",
            providerRef: data.providerRef || null,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        } catch (error) {
          const errMessage = error?.message || "";
          if (!errMessage.includes("already exists")) {
            console.error("failed_order create failed:", error);
          }
        }
      })
    );

    console.log("expirePaymentIntents done", { expired: snapshot.size });
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
    const expiredUsers = [];
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
        expiredUsers.push({
          uid: doc.id,
          name:
            data.displayName ||
            data.username ||
            data.fullName ||
            data.phoneNumber ||
            data.email ||
            "Member",
        });
      }
    });

    if (count > 0) {
      await batch.commit();
    }
    for (const user of expiredUsers) {
      const tokens = await getUserTokens(user.uid);
      if (!tokens.length) {
        continue;
      }
      await sendToTokens(tokens, {
        notification: {
          title: "Premium expired",
          body: "Your premium access has ended. Renew to keep receiving signals.",
        },
        data: {
          type: "membership_expired",
          uid: String(user.uid || ""),
        },
      });
    }
  console.log("expireMembershipsDaily downgraded:", count);
  return null;
});

exports.claimGlobalTrial = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required.");
  }
  const uid = context.auth.uid;
  const offer = await getActiveGlobalOffer();
  if (!offer || offer.type !== "trial") {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "No active trial offer is available at the moment."
    );
  }
  const memberRef = db.collection("users").doc(uid);
  const memberSnap = await memberRef.get();
  const membership = memberSnap.exists ? memberSnap.data()?.membership || {} : {};
  if (membership?.trialUsed === true) {
    throw new functions.https.HttpsError(
      "already-exists",
      "Trial already claimed."
    );
  }
  const trialDays = Math.max(1, Math.floor(Number(offer.trialDays || 0)) || 1);
  const expiresAt = await activatePremiumMembership(
    uid,
    `trial_${uid}_${Date.now()}`,
    trialDays,
    { source: "trial", trialUsed: true }
  );
  const memberName = await resolveMemberName(uid);
  await notifyAdminsOnTrial({
    memberName,
    expiresAt,
    uid,
  });
  return {
    success: true,
    trialDays,
    trialExpiresAt: expiresAt.toDate().toISOString(),
    offerLabel: offer.label || null,
  };
});

const ADMIN_NOTIF_ROLES = new Set(["admin", "trader_admin"]);

exports.testTrialNotification = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required.");
  }
  const role = await getUserRole(context.auth.uid);
  if (!ADMIN_NOTIF_ROLES.has(role)) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Admin access required."
    );
  }
  const memberName =
    (data?.memberName?.toString?.() ?? "").trim() || "Test member";
  const trialDays = Math.max(1, Number(data?.trialDays) || 5);
  const expiresAt = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() + trialDays * 24 * 60 * 60 * 1000)
  );
  await notifyAdminsOnTrial({
    memberName,
    expiresAt,
    uid: data?.memberUid || context.auth.uid,
  });
  return { success: true };
});

exports.testPurchaseNotification = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required.");
  }
  const role = await getUserRole(context.auth.uid);
  if (!ADMIN_NOTIF_ROLES.has(role)) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Admin access required."
    );
  }
  const memberName =
    (data?.memberName?.toString?.() ?? "").trim() || "Test member";
  await notifyAdminsOnRevenue({
    amount: Number(data?.amount) || 0,
    currency: data?.currency?.toString() || "TZS",
    productId: data?.productId?.toString() || "premium_monthly",
    uid: data?.memberUid || context.auth.uid,
    intentId: data?.intentId?.toString() || null,
    provider: data?.provider?.toString() || null,
    memberName,
    planTitle: data?.planTitle?.toString() || "Premium",
    billingPeriod: data?.billingPeriod?.toString() || "monthly",
    durationDays: Number(data?.durationDays) || 30,
  });
  return { success: true };
});

// ===================== 3b) SESSION REMINDERS =====================
exports.sendAsiaSessionReminder = functions.pubsub
  .schedule("0 2 * * *")
  .timeZone("Africa/Dar_es_Salaam")
  .onRun(async () => {
    const session = SESSION_DEFINITIONS.find((item) => item.key === "asia");
    if (!session) {
      return null;
    }
    await sendSessionReminder(session);
    return null;
  });

exports.sendLondonSessionReminder = functions.pubsub
  .schedule("0 10 * * *")
  .timeZone("Africa/Dar_es_Salaam")
  .onRun(async () => {
    const session = SESSION_DEFINITIONS.find((item) => item.key === "london");
    if (!session) {
      return null;
    }
    await sendSessionReminder(session);
    return null;
  });

exports.sendNewYorkSessionReminder = functions.pubsub
  .schedule("0 15 * * *")
  .timeZone("Africa/Dar_es_Salaam")
  .onRun(async () => {
    const session = SESSION_DEFINITIONS.find(
      (item) => item.key === "new_york"
    );
    if (!session) {
      return null;
    }
    await sendSessionReminder(session);
    return null;
  });

// ===================== 4) LIMITED CHAT QUOTA =====================
const MAX_MESSAGES_PER_WINDOW = 10;
const MAX_CHARS_PER_WINDOW = 1500;
const WINDOW_HOURS = 20;
const MAX_CHARS_PER_MESSAGE = 300;

function conversationIdFor(memberUid, traderUid) {
  return `${memberUid}_${traderUid}`;
}

function quotaIdFor(memberUid, traderUid) {
  return `${memberUid}_${traderUid}`;
}

async function getUserRole(uid) {
  if (!uid) return null;
  const snap = await db.collection("users").doc(uid).get();
  if (!snap.exists) return "member";
  const data = snap.data() || {};
  return String(data.role || "member").toLowerCase();
}

async function isPremiumActive(uid) {
  if (!uid) return false;
  const snap = await db.collection("users").doc(uid).get();
  if (!snap.exists) return false;
  const data = snap.data() || {};
  const membership = data.membership || {};
  const tier = String(membership.tier || "free").toLowerCase();
  const status = String(membership.status || "inactive").toLowerCase();
  const expiresAt = membership.expiresAt;
  if (tier !== "premium" || status !== "active") {
    return false;
  }
  if (!expiresAt || !expiresAt.toMillis) {
    return false;
  }
  return expiresAt.toMillis() > Date.now();
}

function buildQuotaResponse({ windowEndsAt, messagesUsed, charsUsed }) {
  const remainingMessages = Math.max(0, MAX_MESSAGES_PER_WINDOW - messagesUsed);
  const remainingChars = Math.max(0, MAX_CHARS_PER_WINDOW - charsUsed);
  return {
    windowEndsAt: windowEndsAt ? windowEndsAt.toMillis() : null,
    remainingMessages,
    remainingChars,
    messagesUsed,
    charsUsed,
  };
}

exports.sendChatMessage = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Authentication required."
    );
  }

  const memberUid = context.auth.uid;
  const traderUid = String(data?.traderUid || "").trim();
  const text = String(data?.text || "").trim();
  const clientMessageId = String(data?.clientMessageId || "").trim();

  if (!traderUid) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Missing traderUid."
    );
  }
  if (!text) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Message text is required."
    );
  }
  if (text.length > MAX_CHARS_PER_MESSAGE) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Message exceeds max length."
    );
  }

  const memberRole = await getUserRole(memberUid);
  if (memberRole !== "member") {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Only members can send chat messages."
    );
  }
  const traderRole = await getUserRole(traderUid);
  if (!["trader", "admin", "trader_admin"].includes(traderRole)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Trader account not found."
    );
  }
  const premiumActive = await isPremiumActive(memberUid);
  if (!premiumActive) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Premium membership required to chat."
    );
  }

  const convoId = conversationIdFor(memberUid, traderUid);
  const quotaId = quotaIdFor(memberUid, traderUid);
  const convoRef = db.collection("conversations").doc(convoId);
  const quotaRef = db.collection("chatQuotas").doc(quotaId);
  const messageRef = clientMessageId
    ? convoRef.collection("messages").doc(clientMessageId)
    : convoRef.collection("messages").doc();
  const now = admin.firestore.Timestamp.now();
  const windowDurationMs = WINDOW_HOURS * 60 * 60 * 1000;

  return db.runTransaction(async (tx) => {
    const quotaSnap = await tx.get(quotaRef);
    let windowStartAt = now;
    let windowEndsAt = admin.firestore.Timestamp.fromMillis(
      now.toMillis() + windowDurationMs
    );
    let messagesUsed = 0;
    let charsUsed = 0;

    if (quotaSnap.exists) {
      const data = quotaSnap.data() || {};
      const storedEndsAt = data.windowEndsAt;
      const storedStartAt = data.windowStartAt;
      const storedMessages = Number(data.messagesUsed || 0);
      const storedChars = Number(data.charsUsed || 0);
      if (
        storedEndsAt &&
        storedEndsAt.toMillis &&
        now.toMillis() <= storedEndsAt.toMillis()
      ) {
        windowStartAt = storedStartAt || windowStartAt;
        windowEndsAt = storedEndsAt;
        messagesUsed = storedMessages;
        charsUsed = storedChars;
      }
    }

    const nextMessages = messagesUsed + 1;
    const nextChars = charsUsed + text.length;
    if (
      nextMessages > MAX_MESSAGES_PER_WINDOW ||
      nextChars > MAX_CHARS_PER_WINDOW
    ) {
      throw new functions.https.HttpsError("resource-exhausted", "Quota exceeded", {
        windowEndsAt: windowEndsAt.toMillis(),
        remainingMessages: Math.max(0, MAX_MESSAGES_PER_WINDOW - messagesUsed),
        remainingChars: Math.max(0, MAX_CHARS_PER_WINDOW - charsUsed),
      });
    }

    tx.set(
      quotaRef,
      {
        memberUid,
        traderUid,
        windowStartAt,
        windowEndsAt,
        messagesUsed: nextMessages,
        charsUsed: nextChars,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    tx.set(messageRef, {
      senderUid: memberUid,
      senderRole: "member",
      text,
      charCount: text.length,
      clientMessageId: clientMessageId || null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    tx.set(
      convoRef,
      {
        memberUid,
        traderUid,
        lastMessage: text,
        lastSender: "member",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return buildQuotaResponse({
      windowEndsAt,
      messagesUsed: nextMessages,
      charsUsed: nextChars,
    });
  });
});

exports.getChatQuota = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Authentication required."
    );
  }

  const memberUid = context.auth.uid;
  const traderUid = String(data?.traderUid || "").trim();
  if (!traderUid) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Missing traderUid."
    );
  }

  const memberRole = await getUserRole(memberUid);
  if (memberRole !== "member") {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Only members can request quota."
    );
  }
  const traderRole = await getUserRole(traderUid);
  if (!["trader", "admin", "trader_admin"].includes(traderRole)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Trader account not found."
    );
  }
  const premiumActive = await isPremiumActive(memberUid);
  if (!premiumActive) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Premium membership required to chat."
    );
  }

  const quotaId = quotaIdFor(memberUid, traderUid);
  const convoId = conversationIdFor(memberUid, traderUid);
  const quotaRef = db.collection("chatQuotas").doc(quotaId);
  const convoRef = db.collection("conversations").doc(convoId);
  const now = admin.firestore.Timestamp.now();
  const windowDurationMs = WINDOW_HOURS * 60 * 60 * 1000;

  return db.runTransaction(async (tx) => {
    const convoSnap = await tx.get(convoRef);
    const quotaSnap = await tx.get(quotaRef);
    let windowStartAt = now;
    let windowEndsAt = admin.firestore.Timestamp.fromMillis(
      now.toMillis() + windowDurationMs
    );
    let messagesUsed = 0;
    let charsUsed = 0;

    if (quotaSnap.exists) {
      const data = quotaSnap.data() || {};
      const storedEndsAt = data.windowEndsAt;
      const storedStartAt = data.windowStartAt;
      const storedMessages = Number(data.messagesUsed || 0);
      const storedChars = Number(data.charsUsed || 0);
      if (
        storedEndsAt &&
        storedEndsAt.toMillis &&
        now.toMillis() <= storedEndsAt.toMillis()
      ) {
        windowStartAt = storedStartAt || windowStartAt;
        windowEndsAt = storedEndsAt;
        messagesUsed = storedMessages;
        charsUsed = storedChars;
      }
    }

    tx.set(
      quotaRef,
      {
        memberUid,
        traderUid,
        windowStartAt,
        windowEndsAt,
        messagesUsed,
        charsUsed,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    if (!convoSnap.exists) {
      tx.set(
        convoRef,
        {
          memberUid,
          traderUid,
          lastMessage: "",
          lastSender: "",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }

    return buildQuotaResponse({
      windowEndsAt,
      messagesUsed,
      charsUsed,
    });
  });
});

exports.sendTraderMessage = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Authentication required."
    );
  }

  const traderUid = context.auth.uid;
  const memberUid = String(data?.memberUid || "").trim();
  const text = String(data?.text || "").trim();

  if (!memberUid) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Missing memberUid."
    );
  }
  if (!text) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Message text is required."
    );
  }
  if (text.length > MAX_CHARS_PER_MESSAGE) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Message exceeds max length."
    );
  }

  const traderRole = await getUserRole(traderUid);
  if (!["trader", "admin", "trader_admin"].includes(traderRole)) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Only trader/admin can reply."
    );
  }
  const memberRole = await getUserRole(memberUid);
  if (!memberRole) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Member not found."
    );
  }

  const convoId = conversationIdFor(memberUid, traderUid);
  const convoRef = db.collection("conversations").doc(convoId);
  const messageRef = convoRef.collection("messages").doc();

  await messageRef.set({
    senderUid: traderUid,
    senderRole: "trader",
    text,
    charCount: text.length,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await convoRef.set(
    {
      memberUid,
      traderUid,
      lastMessage: text,
      lastSender: "trader",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  return { success: true };
});

exports.news = functions.https.onRequest(async (req, res) => {
  if (req.method !== "GET") {
    res.status(405).json({ error: "Method not allowed. Use GET." });
    return;
  }
  const source = String(req.query.source || "").trim();
  if (!NEWS_SOURCE_KEYS.includes(source)) {
    res.status(400).json({
      error: "Invalid source.",
      allowedSources: NEWS_SOURCE_KEYS,
    });
    return;
  }
  let cache = { items: [], fresh: false };
  try {
    cache = await readCachedNews(source);
    if (cache.fresh) {
      res.status(200).json({ source, items: cache.items });
      return;
    }
  } catch (error) {
    console.warn("news cache read failed:", error?.message || error);
  }

  try {
    const items = await fetchAndCacheNews(source);
    res.status(200).json({ source, items });
    return;
  } catch (error) {
    console.error("news fetch failed:", error?.message || error);
    if (cache.items.length) {
      res
        .status(200)
        .json({ source, items: cache.items, warning: "served_from_cache" });
      return;
    }
    res.status(502).json({
      error: "Unable to fetch news at the moment.",
      source,
    });
  }
});

exports.refreshNewsCache = functions.pubsub
  .schedule("every 10 minutes")
  .timeZone("Africa/Dar_es_Salaam")
  .onRun(async () => {
    await Promise.all(
      NEWS_SOURCE_KEYS.map(async (source) => {
        try {
          await fetchAndCacheNews(source);
        } catch (error) {
          console.error(`refreshNewsCache failed for ${source}:`, error);
        }
      })
    );
    return null;
  });
