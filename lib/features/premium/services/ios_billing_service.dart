import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';

class IOSBillingService {
  IOSBillingService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    InAppPurchase? inAppPurchase,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _inAppPurchase = inAppPurchase ?? InAppPurchase.instance;

  static const String weeklyProductId = 'weekly';
  static const String monthlyProductId = 'monthly_';
  static const Set<String> productIds = {
    weeklyProductId,
    monthlyProductId,
  };

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final InAppPurchase _inAppPurchase;

  Stream<List<PurchaseDetails>> get purchaseUpdates =>
      _inAppPurchase.purchaseStream;

  Future<IosProductQueryResult> fetchProducts() async {
    final available = await _inAppPurchase.isAvailable();
    if (!available) {
      return const IosProductQueryResult(
        products: [],
        notFoundIds: [],
        errorMessage: 'Store unavailable.',
      );
    }
    final response = await _inAppPurchase.queryProductDetails(productIds);
    return IosProductQueryResult(
      products: response.productDetails,
      notFoundIds: response.notFoundIDs,
      errorMessage: response.error?.message,
    );
  }

  Future<void> buy(ProductDetails product) async {
    final param = PurchaseParam(productDetails: product);
    await _inAppPurchase.buyNonConsumable(purchaseParam: param);
  }

  Future<void> restorePurchases() async {
    await _inAppPurchase.restorePurchases();
  }

  bool hasIntroOffer(ProductDetails product) {
    if (product is AppStoreProductDetails) {
      return product.skProduct.introductoryPrice != null;
    }
    return false;
  }

  Future<bool> activateMembershipFromPurchase(PurchaseDetails purchase) async {
    if (purchase.status != PurchaseStatus.purchased &&
        purchase.status != PurchaseStatus.restored) {
      return false;
    }
    final productId = purchase.productID;
    if (!productIds.contains(productId)) {
      await completePurchaseIfNeeded(purchase);
      return false;
    }
    final startedAt = _resolvePurchaseDate(purchase);
    final expiresAt = startedAt.add(_subscriptionDuration(productId));
    final user = _auth.currentUser;
    if (user == null) {
      return false;
    }
    bool trialUsed = false;
    try {
      final snapshot = await _firestore.collection('users').doc(user.uid).get();
      final membership =
          snapshot.data()?['membership'] as Map<String, dynamic>?;
      trialUsed = membership?['trialUsed'] == true;
    } catch (_) {
      trialUsed = false;
    }
    final membershipUpdate = {
      'tier': 'premium',
      'status': 'active',
      'startedAt': Timestamp.fromDate(startedAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'lastPaymentRef': purchase.purchaseID ?? purchase.transactionDate,
      'updatedAt': FieldValue.serverTimestamp(),
      'source': 'ios_storekit',
      'trialUsed': trialUsed,
    };
    await _firestore.collection('users').doc(user.uid).set({
      'membership': membershipUpdate,
      'membershipTier': 'premium',
    }, SetOptions(merge: true));
    await completePurchaseIfNeeded(purchase);
    return true;
  }

  Future<void> completePurchaseIfNeeded(PurchaseDetails purchase) async {
    if (purchase.pendingCompletePurchase) {
      await _inAppPurchase.completePurchase(purchase);
    }
  }

  Duration _subscriptionDuration(String productId) {
    switch (productId) {
      case weeklyProductId:
        return const Duration(days: 7);
      case monthlyProductId:
      default:
        return const Duration(days: 30);
    }
  }

  DateTime _resolvePurchaseDate(PurchaseDetails purchase) {
    final rawDate = purchase.transactionDate;
    if (rawDate == null) {
      return DateTime.now();
    }
    final millis = int.tryParse(rawDate);
    if (millis == null) {
      return DateTime.now();
    }
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }
}

class IosProductQueryResult {
  const IosProductQueryResult({
    required this.products,
    required this.notFoundIds,
    this.errorMessage,
  });

  final List<ProductDetails> products;
  final List<String> notFoundIds;
  final String? errorMessage;

  bool get hasError => errorMessage != null && errorMessage!.isNotEmpty;
}
