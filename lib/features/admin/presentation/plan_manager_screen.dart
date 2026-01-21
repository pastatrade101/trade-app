import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../app/providers.dart';
import '../../../core/models/product.dart';
import '../../../core/widgets/app_toast.dart';
import 'global_offer_settings_screen.dart';
import 'package:stock_investment_flutter/app/app_icons.dart';

class PlanManagerScreen extends ConsumerStatefulWidget {
  const PlanManagerScreen({super.key});

  @override
  ConsumerState<PlanManagerScreen> createState() => _PlanManagerScreenState();
}

class _PlanManagerScreenState extends ConsumerState<PlanManagerScreen> {
  final Set<String> _loading = {};

  Future<void> _setPlanStatus({
    required BuildContext context,
    required _PlanDefinition plan,
    required bool isActive,
  }) async {
    if (_loading.contains(plan.id)) {
      return;
    }
    setState(() => _loading.add(plan.id));
    try {
      final product = plan.toProduct(isActive: isActive);
      await ref.read(productRepositoryProvider).upsertProduct(product);
      if (mounted) {
        AppToast.success(
          context,
          isActive ? 'Plan published' : 'Plan unpublished',
        );
      }
    } catch (error) {
      if (mounted) {
        AppToast.error(context, 'Failed to update plan: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _loading.remove(plan.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final plans = _PlanDefinition.defaults;
    final productStream =
        ref.read(productRepositoryProvider).watchProductsByIds(
              plans.map((plan) => plan.id).toList(),
            );

    return Scaffold(
      appBar: AppBar(title: const Text('Publish plans')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const GlobalOfferSettingsScreen(),
                    ),
                  );
                },
                icon: const Icon(AppIcons.timer),
                label: const Text('Manage trials & offers'),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Product>>(
              stream: productStream,
              builder: (context, snapshot) {
                final products = snapshot.data ?? const [];
                final byId = {for (final product in products) product.id: product};
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: plans.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final plan = plans[index];
                    final product =
                        byId[plan.id] ?? plan.toProduct(isActive: false);
                    final isActive = product.isActive;
                    final loading = _loading.contains(plan.id);
                    return _PlanCard(
                      plan: plan,
                      product: product,
                      isActive: isActive,
                      loading: loading,
                      tokens: tokens,
                      onPublish: () => _setPlanStatus(
                        context: context,
                        plan: plan,
                        isActive: true,
                      ),
                      onUnpublish: () => _setPlanStatus(
                        context: context,
                        plan: plan,
                        isActive: false,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.product,
    required this.isActive,
    required this.loading,
    required this.tokens,
    required this.onPublish,
    required this.onUnpublish,
  });

  final _PlanDefinition plan;
  final Product product;
  final bool isActive;
  final bool loading;
  final AppThemeTokens tokens;
  final VoidCallback onPublish;
  final VoidCallback onUnpublish;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = isActive ? tokens.success : tokens.warning;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: plan.accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(plan.icon, color: plan.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plan.subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: tokens.mutedText,
                            ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(isActive ? 'Published' : 'Draft'),
                  backgroundColor: statusColor.withOpacity(0.15),
                  labelStyle: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                  side: BorderSide(color: statusColor.withOpacity(0.4)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: tokens.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: tokens.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${product.price.toStringAsFixed(0)} ${product.currency}',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.primary,
                          ),
                    ),
                  ),
                  Text(
                    plan.billingLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: tokens.mutedText,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _PlanBenefit(text: 'Premium signals unlocked'),
            _PlanBenefit(text: plan.durationLabel),
            const _PlanBenefit(text: 'Mobile money supported'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: loading || isActive ? null : onPublish,
                    child: loading && !isActive
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Publish'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: loading || !isActive ? null : onUnpublish,
                    child: loading && isActive
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Unpublish'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanBenefit extends StatelessWidget {
  const _PlanBenefit({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(AppIcons.check_circle, size: 18, color: tokens.success),
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
      ),
    );
  }
}

class _PlanDefinition {
  const _PlanDefinition({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.currency,
    required this.billingPeriod,
    required this.durationLabel,
    required this.icon,
    required this.accent,
  });

  final String id;
  final String title;
  final String subtitle;
  final double price;
  final String currency;
  final String billingPeriod;
  final String durationLabel;
  final IconData icon;
  final Color accent;

  String get billingLabel {
    switch (billingPeriod) {
      case 'daily':
        return 'per day';
      case 'weekly':
        return 'per week';
      case 'monthly':
      default:
        return 'per month';
    }
  }

  Product toProduct({required bool isActive}) {
    return Product(
      id: id,
      title: title,
      price: price,
      currency: currency,
      billingPeriod: billingPeriod,
      isActive: isActive,
    );
  }

  static const defaults = <_PlanDefinition>[
    _PlanDefinition(
      id: 'premium_daily',
      title: 'Premium Daily',
      subtitle: 'Quick access for 24 hours',
      price: 2000,
      currency: 'TZS',
      billingPeriod: 'daily',
      durationLabel: 'Valid for 24 hours',
      icon: AppIcons.flash_on,
      accent: Color(0xFF2563EB),
    ),
    _PlanDefinition(
      id: 'premium_weekly',
      title: 'Premium Weekly',
      subtitle: 'Best for short-term plans',
      price: 12000,
      currency: 'TZS',
      billingPeriod: 'weekly',
      durationLabel: 'Valid for 7 days',
      icon: AppIcons.calendar_view_week,
      accent: Color(0xFF16A34A),
    ),
    _PlanDefinition(
      id: 'premium_monthly',
      title: 'Premium Monthly',
      subtitle: 'Full access for active traders',
      price: 30000,
      currency: 'TZS',
      billingPeriod: 'monthly',
      durationLabel: 'Valid for 30 days',
      icon: AppIcons.star_outline,
      accent: Color(0xFFF97316),
    ),
  ];
}
