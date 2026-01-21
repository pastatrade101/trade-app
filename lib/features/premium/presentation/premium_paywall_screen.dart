import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../app/providers.dart';
import '../models/global_offer.dart';
import 'plan_selection_screen.dart';
import '../../../services/analytics_service.dart';
import 'package:stock_investment_flutter/app/app_icons.dart';

class PremiumPaywallScreen extends ConsumerStatefulWidget {
  const PremiumPaywallScreen({
    super.key,
    this.sourceScreen,
  });

  final String? sourceScreen;

  @override
  ConsumerState<PremiumPaywallScreen> createState() =>
      _PremiumPaywallScreenState();
}

class _PremiumPaywallScreenState extends ConsumerState<PremiumPaywallScreen> {
  bool _loggedView = false;

  @override
  void initState() {
    super.initState();
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final offer = ref.watch(globalOfferProvider).valueOrNull;
    final membership = ref.watch(userMembershipProvider).value;
    final hasUsedTrial = membership?.trialUsed ?? false;
    final showOffer =
        offer != null && !(offer.isTrial && hasUsedTrial);
    return Scaffold(
      appBar: AppBar(title: const Text('Premium Membership')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Unlock premium signals',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Upgrade to see full entry, stop loss, take profits, and trader reasoning. Choose daily, weekly, or monthly access.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: tokens.mutedText,
                    ),
              ),
              const SizedBox(height: 20),
              if (showOffer && offer != null) ...[
                _OfferBanner(offer: offer),
                const SizedBox(height: 16),
              ],
              _BenefitTile(
              icon: AppIcons.lock_open,
              title: 'Premium signals',
              subtitle: 'View full signal details instantly.',
            ),
            const SizedBox(height: 12),
            const _BenefitTile(
              icon: AppIcons.notifications_active,
              title: 'Faster alerts',
              subtitle: 'Be first to see high-confidence setups.',
            ),
            const SizedBox(height: 12),
            const _BenefitTile(
              icon: AppIcons.lightbulb_outline,
              title: 'Premium tips',
              subtitle: 'Get extra market insights and trade ideas.',
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PlanSelectionScreen(),
                    ),
                  );
                },
                child: const Text('Upgrade'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfferBanner extends StatelessWidget {
  const _OfferBanner({required this.offer});

  final GlobalOffer offer;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final primaryColor = offer.isDiscount ? tokens.success : tokens.warning;
    final icon = offer.isDiscount ? AppIcons.flash_on : AppIcons.timer;
    final subtitle = offer.isDiscount
        ? 'Discount applies to daily, weekly, and monthly plans.'
        : 'Valid for ${offer.trialDays} day${offer.trialDays == 1 ? '' : 's'} across all plans.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: primaryColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  offer.label.isNotEmpty ? offer.label : 'Limited time offer',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.mutedText,
                      ),
                ),
              ],
            ),
          ),
          if (offer.isDiscount)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${offer.discountPercent.toStringAsFixed(0)}% OFF',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BenefitTile extends StatelessWidget {
  const _BenefitTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 36,
          width: 36,
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: primaryColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: tokens.mutedText,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
