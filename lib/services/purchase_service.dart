import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';

class AppleSubscriptionProduct {
  AppleSubscriptionProduct({
    required this.details,
    required this.displayName,
    required this.price,
    required this.billingPeriod,
    this.trialBadge,
  });

  final ProductDetails details;
  final String displayName;
  final String price;
  final String billingPeriod;
  final String? trialBadge;
}

class ApplePaywallState {
  const ApplePaywallState({
    this.products = const [],
    this.selectedProductId,
    this.isLoading = false,
    this.isPurchasing = false,
    this.isRestoring = false,
    this.loadFailed = false,
    this.actionError,
  });

  final List<AppleSubscriptionProduct> products;
  final String? selectedProductId;
  final bool isLoading;
  final bool isPurchasing;
  final bool isRestoring;
  final bool loadFailed;
  final String? actionError;

  bool get showFallback =>
      !isLoading && (loadFailed || products.isEmpty);

  ApplePaywallState copyWith({
    List<AppleSubscriptionProduct>? products,
    String? selectedProductId,
    bool? isLoading,
    bool? isPurchasing,
    bool? isRestoring,
    bool? loadFailed,
    String? actionError,
    bool clearActionError = false,
  }) {
    return ApplePaywallState(
      products: products ?? this.products,
      selectedProductId: selectedProductId ?? this.selectedProductId,
      isLoading: isLoading ?? this.isLoading,
      isPurchasing: isPurchasing ?? this.isPurchasing,
      isRestoring: isRestoring ?? this.isRestoring,
      loadFailed: loadFailed ?? this.loadFailed,
      actionError: clearActionError ? null : (actionError ?? this.actionError),
    );
  }
}

class ApplePurchaseService extends StateNotifier<ApplePaywallState> {
  ApplePurchaseService({
    InAppPurchase? inAppPurchase,
    FirebaseFunctions? functions,
  })  : _inAppPurchase = inAppPurchase ?? InAppPurchase.instance,
        _functions = functions ?? FirebaseFunctions.instance,
        super(const ApplePaywallState()) {
    _purchaseSub = _inAppPurchase.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: _handlePurchaseStreamError,
    );
    loadProducts();
  }

  final InAppPurchase _inAppPurchase;
  final FirebaseFunctions _functions;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  final Set<String> _confirmedPurchaseIds = <String>{};

  static const List<String> _productIdOrder = [
    'weekly',
    'monthly_',
  ];

  Future<void> loadProducts() async {
    state = state.copyWith(
      isLoading: true,
      loadFailed: false,
      clearActionError: true,
    );
    final available = await _inAppPurchase.isAvailable();
    if (!available) {
      state = state.copyWith(isLoading: false, loadFailed: true);
      return;
    }

    final response =
        await _inAppPurchase.queryProductDetails(_productIdOrder.toSet());
    if (response.error != null || response.productDetails.isEmpty) {
      debugPrint('Apple products load failed.');
      state = state.copyWith(isLoading: false, loadFailed: true);
      return;
    }

    final products = _mapProducts(response.productDetails);
    if (products.isEmpty ||
        response.notFoundIDs.isNotEmpty ||
        products.length != _productIdOrder.length) {
      debugPrint('Apple products missing or incomplete.');
      state = state.copyWith(isLoading: false, loadFailed: true);
      return;
    }

    final selectedId = state.selectedProductId ?? products.first.details.id;
    state = state.copyWith(
      products: products,
      selectedProductId: selectedId,
      isLoading: false,
      loadFailed: false,
      clearActionError: true,
    );
  }

  void selectProduct(String productId) {
    state = state.copyWith(
      selectedProductId: productId,
      clearActionError: true,
    );
  }

  Future<void> buySelectedProduct() async {
    final selectedId = state.selectedProductId;
    if (selectedId == null) {
      state = state.copyWith(actionError: 'Select a plan to continue.');
      return;
    }
    final selected = state.products.firstWhere(
      (product) => product.details.id == selectedId,
      orElse: () => AppleSubscriptionProduct(
        details: state.products.first.details,
        displayName: '',
        price: '',
        billingPeriod: '',
      ),
    );
    if (selected.details.id.isEmpty) {
      state = state.copyWith(actionError: 'Select a plan to continue.');
      return;
    }

    state = state.copyWith(isPurchasing: true, clearActionError: true);
    final param = PurchaseParam(productDetails: selected.details);
    await _inAppPurchase.buyNonConsumable(purchaseParam: param);
  }

  Future<void> restorePurchases() async {
    state = state.copyWith(isRestoring: true, clearActionError: true);
    await _inAppPurchase.restorePurchases();
    state = state.copyWith(isRestoring: false);
  }

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchases,
  ) async {
    bool hasPending = false;
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          hasPending = true;
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _confirmAndComplete(purchase);
          break;
        case PurchaseStatus.error:
          state = state.copyWith(
            isPurchasing: false,
            actionError:
                purchase.error?.message ?? 'Purchase failed. Try again.',
          );
          await _completePurchaseIfNeeded(purchase);
          break;
        case PurchaseStatus.canceled:
          await _completePurchaseIfNeeded(purchase);
          break;
      }
    }

    state = state.copyWith(
      isPurchasing: hasPending,
      isRestoring: false,
    );
  }

  void _handlePurchaseStreamError(Object error) {
    debugPrint('Apple purchase stream error.');
    state = state.copyWith(
      isPurchasing: false,
      isRestoring: false,
      actionError: 'Unable to process the purchase right now.',
    );
  }

  Future<void> _confirmAndComplete(PurchaseDetails purchase) async {
    final purchaseId = _purchaseKey(purchase);
    if (_confirmedPurchaseIds.contains(purchaseId)) {
      await _completePurchaseIfNeeded(purchase);
      return;
    }

    final confirmed = await _confirmAppleSubscription(purchase);
    if (confirmed) {
      _confirmedPurchaseIds.add(purchaseId);
    }
    await _completePurchaseIfNeeded(purchase);
  }

  Future<bool> _confirmAppleSubscription(PurchaseDetails purchase) async {
    try {
      final callable = _functions.httpsCallable('confirmAppleSubscription');
      final response = await callable({
        'productId': purchase.productID,
        'transactionId': purchase.purchaseID,
        'transactionDate': purchase.transactionDate,
        'verificationData': purchase.verificationData.serverVerificationData,
        'verificationSource': purchase.verificationData.source,
        'status': purchase.status.name,
      });
      final data = Map<String, dynamic>.from(response.data ?? {});
      final success = data.isEmpty || data['success'] == true;
      if (!success) {
        state = state.copyWith(
          actionError:
              data['message']?.toString() ??
                  'Unable to confirm subscription.',
        );
      }
      return success;
    } on FirebaseFunctionsException catch (error) {
      state = state.copyWith(
        actionError:
            error.message ?? 'Unable to confirm subscription.',
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        actionError: 'Unable to confirm subscription.',
      );
      return false;
    }
  }

  Future<void> _completePurchaseIfNeeded(PurchaseDetails purchase) async {
    if (purchase.pendingCompletePurchase) {
      await _inAppPurchase.completePurchase(purchase);
    }
  }

  List<AppleSubscriptionProduct> _mapProducts(
    List<ProductDetails> products,
  ) {
    final byId = <String, ProductDetails>{
      for (final product in products) product.id: product,
    };
    final ordered = <AppleSubscriptionProduct>[];
    for (final id in _productIdOrder) {
      final details = byId[id];
      if (details == null) {
        continue;
      }
      ordered.add(
        AppleSubscriptionProduct(
          details: details,
          displayName: details.title,
          price: details.price,
          billingPeriod: _resolveBillingPeriod(details),
          trialBadge: _resolveTrialBadge(details),
        ),
      );
    }
    return ordered;
  }

  String _resolveBillingPeriod(ProductDetails details) {
    if (details is AppStoreProductDetails) {
      final period = details.skProduct.subscriptionPeriod;
      if (period != null && period.numberOfUnits > 0) {
        return _formatPeriod(
          period.numberOfUnits,
          period.unit.name,
        );
      }
    }
    if (details is AppStoreProduct2Details) {
      final period = details.sk2Product.subscription?.subscriptionPeriod;
      if (period != null && period.value > 0) {
        return _formatPeriod(period.value, period.unit.name);
      }
    }
    return 'Subscription';
  }

  String? _resolveTrialBadge(ProductDetails details) {
    if (details is AppStoreProductDetails) {
      final intro = details.skProduct.introductoryPrice;
      if (intro == null) {
        return null;
      }
      if (intro.paymentMode == SKProductDiscountPaymentMode.freeTrail) {
        return 'Free trial';
      }
      return 'Intro offer';
    }
    if (details is AppStoreProduct2Details) {
      final offers = details.sk2Product.subscription?.promotionalOffers ?? [];
      if (offers.isEmpty) {
        return null;
      }
      final hasTrial = offers.any(
        (offer) =>
            offer.paymentMode == SK2SubscriptionOfferPaymentMode.freeTrial,
      );
      return hasTrial ? 'Free trial' : 'Intro offer';
    }
    return null;
  }

  String _formatPeriod(int count, String unitName) {
    final unit = _normalizeUnit(unitName);
    if (count == 1) {
      return 'per $unit';
    }
    return 'every $count ${unit}s';
  }

  String _normalizeUnit(String unitName) {
    switch (unitName.toLowerCase()) {
      case 'day':
        return 'day';
      case 'week':
        return 'week';
      case 'month':
        return 'month';
      case 'year':
        return 'year';
      default:
        return 'period';
    }
  }

  String _purchaseKey(PurchaseDetails purchase) {
    final id = purchase.purchaseID;
    if (id != null && id.isNotEmpty) {
      return id;
    }
    final date = purchase.transactionDate;
    if (date != null && date.isNotEmpty) {
      return '${purchase.productID}-$date';
    }
    return '${purchase.productID}-${purchase.status.name}';
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    super.dispose();
  }
}
