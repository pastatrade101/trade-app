import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_theme.dart';
import '../../../app/providers.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../services/analytics_service.dart';
import '../models/ios_paywall_offer.dart';
import '../services/ios_billing_service.dart';
import 'package:stock_investment_flutter/app/app_icons.dart';

class IosPremiumPaywallScreen extends ConsumerStatefulWidget {
  const IosPremiumPaywallScreen({
    super.key,
    this.sourceScreen,
  });

  final String? sourceScreen;

  @override
  ConsumerState<IosPremiumPaywallScreen> createState() =>
      _IosPremiumPaywallScreenState();
}

class _IosPremiumPaywallScreenState
    extends ConsumerState<IosPremiumPaywallScreen> {
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  List<ProductDetails> _products = const [];
  bool _loading = true;
  bool _purchaseInProgress = false;
  bool _restoring = false;
  String? _selectedId;
  String? _loadError;
  bool _loggedView = false;

  static const _termsUrl = 'https://example.com/terms';
  static const _privacyUrl = 'https://example.com/privacy';
  static const _supportEmail = 'support@mchambuzikai.app';

  @override
  void initState() {
    super.initState();
    final billing = ref.read(iosBillingServiceProvider);
    _purchaseSub = billing.purchaseUpdates.listen(
      _handlePurchaseUpdates,
      onError: (_) {
        if (mounted) {
          AppToast.error(context, 'Purchase update failed.');
        }
      },
    );
    _loadProducts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loggedView) {
      return;
    }
    _loggedView = true;
    AnalyticsService.instance.logEvent(
      'premium_view_paywall',
      params: {
        'sourceScreen': widget.sourceScreen ?? 'unknown',
        'platform': 'ios',
      },
    );
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final result = await ref.read(iosBillingServiceProvider).fetchProducts();
    if (!mounted) {
      return;
    }
    final products = result.products;
    final missing =
        IOSBillingService.productIds.difference(products.map((p) => p.id).toSet());
    setState(() {
      _products = products;
      _loadError = result.hasError
          ? result.errorMessage
          : (missing.isNotEmpty ? 'Missing products.' : null);
      _loading = false;
      if (_selectedId == null && products.isNotEmpty) {
        _selectedId =
            _findProduct(IOSBillingService.monthlyProductId)?.id ??
                products.first.id;
      }
    });
  }

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchases,
  ) async {
    bool activated = false;
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) {
        if (mounted) {
          setState(() => _purchaseInProgress = true);
        }
        continue;
      }
      if (purchase.status == PurchaseStatus.error) {
        if (mounted) {
          AppToast.error(context, 'Purchase failed. Try again.');
        }
      }
      if (purchase.status == PurchaseStatus.canceled) {
        if (mounted) {
          AppToast.info(context, 'Purchase canceled.');
        }
      }
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        final result = await ref
            .read(iosBillingServiceProvider)
            .activateMembershipFromPurchase(purchase);
        activated = activated || result;
        await ref
            .read(iosBillingServiceProvider)
            .completePurchaseIfNeeded(purchase);
      } else {
        await ref.read(iosBillingServiceProvider).completePurchaseIfNeeded(
              purchase,
            );
      }
    }
    if (mounted) {
      setState(() {
        _purchaseInProgress = false;
        _restoring = false;
      });
      if (activated) {
        AppToast.success(context, 'Premium unlocked.');
      }
    }
  }

  Future<void> _startPurchase(ProductDetails product) async {
    setState(() => _purchaseInProgress = true);
    try {
      await ref.read(iosBillingServiceProvider).buy(product);
    } catch (_) {
      if (mounted) {
        AppToast.error(context, 'Unable to start purchase.');
        setState(() => _purchaseInProgress = false);
      }
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _restoring = true);
    try {
      await ref.read(iosBillingServiceProvider).restorePurchases();
    } catch (_) {
      if (mounted) {
        AppToast.error(context, 'Unable to restore purchases.');
        setState(() => _restoring = false);
      }
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        AppToast.error(context, 'Unable to open link.');
      }
    }
  }

  Future<void> _contactSupport() async {
    await _launchUrl('mailto:$_supportEmail');
  }

  ProductDetails? _findProduct(String id) {
    for (final product in _products) {
      if (product.id == id) {
        return product;
      }
    }
    return null;
  }

  bool _textImpliesTrial(String text) {
    final lower = text.toLowerCase();
    return lower.contains('trial') || lower.contains('free');
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final billing = ref.read(iosBillingServiceProvider);
    final offer = ref.watch(iosPaywallOfferProvider).valueOrNull;
    final hasIntroOffer =
        _products.any((product) => billing.hasIntroOffer(product));
    final offerText = _resolveOfferText(offer, hasIntroOffer);
    final badgeText = _resolveBadgeText(offer, hasIntroOffer);
    final showTrialDisclaimer =
        offer?.enabled == true && offer!.trialDays > 0 && hasIntroOffer;
    final weekly = _findProduct(IOSBillingService.weeklyProductId);
    final monthly = _findProduct(IOSBillingService.monthlyProductId);
    final productsReady = weekly != null && monthly != null;
    final showFallback =
        !_loading && (!productsReady || _loadError != null || _products.isEmpty);

    return Scaffold(
      appBar: AppBar(title: const Text('Premium Paywall')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Unlock Premium',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose a plan and get full access to premium signals.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: tokens.mutedText,
                      ),
                ),
                const SizedBox(height: 16),
                if (offerText != null || badgeText != null) ...[
                  _OfferBanner(
                    text: offerText,
                    badge: badgeText,
                  ),
                  const SizedBox(height: 16),
                ],
                if (showFallback)
                  _FallbackPanel(
                    onRetry: _loadProducts,
                    onRestore: _restorePurchases,
                    onContact: _contactSupport,
                    restoring: _restoring,
                  )
                else ...[
                  _BenefitList(),
                  const SizedBox(height: 16),
                  _PlanCard(
                    title: 'Weekly',
                    subtitle: 'Flexible weekly access',
                    price: weekly?.price ?? '--',
                    durationLabel: 'Weekly',
                    isSelected: _selectedId == weekly?.id,
                    isBestValue: false,
                    onTap: () => setState(() => _selectedId = weekly?.id),
                  ),
                  const SizedBox(height: 12),
                  _PlanCard(
                    title: 'Monthly',
                    subtitle: 'Best value for active traders',
                    price: monthly?.price ?? '--',
                    durationLabel: 'Monthly',
                    isSelected: _selectedId == monthly?.id,
                    isBestValue: true,
                    onTap: () => setState(() => _selectedId = monthly?.id),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _purchaseInProgress
                          ? null
                          : () {
                              final product = _selectedId == monthly?.id
                                  ? monthly
                                  : weekly;
                              if (product != null) {
                                _startPurchase(product);
                              }
                            },
                      child: _purchaseInProgress
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Unlock Premium'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: _restoring ? null : _restorePurchases,
                        child: _restoring
                            ? const SizedBox(
                                height: 14,
                                width: 14,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Restore Purchases'),
                      ),
                      TextButton(
                        onPressed: () => _launchUrl(_termsUrl),
                        child: const Text('Terms'),
                      ),
                      TextButton(
                        onPressed: () => _launchUrl(_privacyUrl),
                        child: const Text('Privacy'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                _DisclaimerBlock(
                  tokens: tokens,
                  showTrialDisclaimer: showTrialDisclaimer,
                  onTerms: () => _launchUrl(_termsUrl),
                  onPrivacy: () => _launchUrl(_privacyUrl),
                ),
              ],
            ),
    );
  }

  String? _resolveOfferText(IosPaywallOffer? offer, bool hasIntroOffer) {
    if (offer == null || !offer.enabled) {
      return null;
    }
    final text = offer.promoText.trim();
    if (text.isEmpty) {
      return null;
    }
    if (_textImpliesTrial(text) && !hasIntroOffer) {
      return 'Limited offer';
    }
    return text;
  }

  String? _resolveBadgeText(IosPaywallOffer? offer, bool hasIntroOffer) {
    if (offer == null || !offer.enabled) {
      return null;
    }
    final text = offer.badgeText.trim();
    if (text.isEmpty) {
      return null;
    }
    if (_textImpliesTrial(text) && !hasIntroOffer) {
      return null;
    }
    return text;
  }
}

class _OfferBanner extends StatelessWidget {
  const _OfferBanner({
    required this.text,
    required this.badge,
  });

  final String? text;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        children: [
          Icon(AppIcons.bolt, color: tokens.warning, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text ?? 'Limited offer',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: tokens.warning.withOpacity(0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                badge!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: tokens.warning,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BenefitList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _BenefitRow(text: 'Full access to signals'),
        SizedBox(height: 10),
        _BenefitRow(text: 'Sessions + overlap indicator'),
        SizedBox(height: 10),
        _BenefitRow(text: 'Session alerts (premium)'),
        SizedBox(height: 10),
        _BenefitRow(text: 'Direct trader chat'),
      ],
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Row(
      children: [
        Icon(AppIcons.check, size: 18, color: tokens.success),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: tokens.mutedText,
                ),
          ),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.durationLabel,
    required this.isSelected,
    required this.isBestValue,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String price;
  final String durationLabel;
  final bool isSelected;
  final bool isBestValue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? colorScheme.primary : tokens.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: colorScheme.primary.withOpacity(0.12),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                if (isBestValue)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: tokens.success.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Best Value',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: tokens.success,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: tokens.mutedText,
                  ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  price,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.primary,
                      ),
                ),
                const SizedBox(width: 8),
                Text(
                  durationLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.mutedText,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                if (isSelected)
                  Icon(AppIcons.check_circle, color: colorScheme.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FallbackPanel extends StatelessWidget {
  const _FallbackPanel({
    required this.onRetry,
    required this.onRestore,
    required this.onContact,
    required this.restoring,
  });

  final VoidCallback onRetry;
  final VoidCallback onRestore;
  final VoidCallback onContact;
  final bool restoring;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Subscriptions unavailable',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'We couldn\'t load Apple subscription plans right now. '
            'Check your connection or try again.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: tokens.mutedText,
                ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: restoring ? null : onRestore,
              child: restoring
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Restore Purchases'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: onContact,
              child: const Text('Contact Support'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DisclaimerBlock extends StatelessWidget {
  const _DisclaimerBlock({
    required this.tokens,
    required this.showTrialDisclaimer,
    required this.onTerms,
    required this.onPrivacy,
  });

  final AppThemeTokens tokens;
  final bool showTrialDisclaimer;
  final VoidCallback onTerms;
  final VoidCallback onPrivacy;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: tokens.mutedText,
          height: 1.4,
        );
    final linkStyle = textStyle?.copyWith(
      color: Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.w600,
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Auto-renewable subscription. Charged to Apple ID at confirmation. '
            'Renews unless canceled at least 24h before end. '
            'Manage/cancel in Apple ID Settings.',
            style: textStyle,
          ),
          if (showTrialDisclaimer) ...[
            const SizedBox(height: 6),
            Text(
              'Any unused free trial is forfeited when purchasing.',
              style: textStyle,
            ),
          ],
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              style: textStyle,
              children: [
                const TextSpan(text: 'Terms of Use and Privacy Policy: '),
                TextSpan(
                  text: 'Terms of Use',
                  style: linkStyle,
                  recognizer: TapGestureRecognizer()..onTap = onTerms,
                ),
                const TextSpan(text: ' - '),
                TextSpan(
                  text: 'Privacy Policy',
                  style: linkStyle,
                  recognizer: TapGestureRecognizer()..onTap = onPrivacy,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
