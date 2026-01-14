import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../app/providers.dart';
import '../../../core/models/product.dart';
import 'payment_method_screen.dart';

class PlanSelectionScreen extends ConsumerStatefulWidget {
  const PlanSelectionScreen({super.key});

  @override
  ConsumerState<PlanSelectionScreen> createState() =>
      _PlanSelectionScreenState();
}

class _PlanSelectionScreenState extends ConsumerState<PlanSelectionScreen> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final plans = _PlanDefinition.defaults;
    final productStream = ref
        .read(productRepositoryProvider)
        .watchProductsByIds(plans.map((plan) => plan.id).toList());
    return Scaffold(
      appBar: AppBar(title: const Text('Choose plan')),
      body: StreamBuilder<List<Product>>(
        stream: productStream,
        builder: (context, snapshot) {
          final products = snapshot.data ?? const [];
          if (snapshot.connectionState == ConnectionState.waiting &&
              products.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          final byId = {for (final product in products) product.id: product};
          final options = plans
              .map((plan) =>
                  _PlanOption(plan: plan, product: byId[plan.id]))
              .toList();
          final activeOptions = options
              .where((option) => option.product?.isActive ?? false)
              .toList();
          if (_selectedId == null && options.isNotEmpty) {
            final initial = activeOptions.isNotEmpty
                ? activeOptions.first
                : options.first;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() => _selectedId = initial.plan.id);
              }
            });
          } else if (_selectedId != null &&
              activeOptions.isNotEmpty &&
              !activeOptions.any((option) => option.plan.id == _selectedId)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() => _selectedId = activeOptions.first.plan.id);
              }
            });
          }
          final visibleOptions =
              activeOptions.isNotEmpty ? activeOptions : const <_PlanOption>[];
          if (visibleOptions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No active plans are available yet.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: tokens.mutedText,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final selectedOption = visibleOptions.firstWhere(
            (option) => option.plan.id == _selectedId,
            orElse: () => visibleOptions.first,
          );
          final selectedProduct = selectedOption.product ??
              selectedOption.plan.toProduct(isActive: false);
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pick your premium access',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose the duration that fits your trading style.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.mutedText,
                      ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    itemCount: visibleOptions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final option = visibleOptions[index];
                      final product = option.product ??
                          option.plan.toProduct(isActive: false);
                      final isSelected = option.plan.id == _selectedId;
                      return _PlanCard(
                        option: option,
                        product: product,
                        isSelected: isSelected,
                        onTap: () => setState(() => _selectedId = option.plan.id),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: selectedProduct.isActive
                        ? () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    PaymentMethodScreen(product: selectedProduct),
                              ),
                            );
                          }
                        : null,
                    child: const Text('Continue'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.option,
    required this.product,
    required this.isSelected,
    required this.onTap,
  });

  final _PlanOption option;
  final Product product;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = isSelected ? colorScheme.primary : tokens.border;
    final badgeColor = product.isActive ? tokens.success : tokens.warning;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: option.plan.accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(option.plan.icon, color: option.plan.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.plan.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        option.plan.subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: tokens.mutedText,
                            ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(product.isActive ? 'Available' : 'Unavailable'),
                  backgroundColor: badgeColor.withOpacity(0.14),
                  labelStyle: TextStyle(
                    color: badgeColor,
                    fontWeight: FontWeight.w600,
                  ),
                  side: BorderSide(color: badgeColor.withOpacity(0.4)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${product.price.toStringAsFixed(0)} ${product.currency}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.primary,
                      ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    option.plan.billingLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: tokens.mutedText,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                const Spacer(),
                if (isSelected)
                  Icon(Icons.check_circle, color: colorScheme.primary),
              ],
            ),
            const SizedBox(height: 10),
            _PlanBullet(text: option.plan.durationLabel),
            const _PlanBullet(text: 'Premium signal details included'),
          ],
        ),
      ),
    );
  }
}

class _PlanBullet extends StatelessWidget {
  const _PlanBullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(Icons.check, size: 16, color: tokens.success),
          const SizedBox(width: 6),
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

class _PlanOption {
  const _PlanOption({required this.plan, required this.product});

  final _PlanDefinition plan;
  final Product? product;
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
      subtitle: 'Great for quick sessions',
      price: 2000,
      currency: 'TZS',
      billingPeriod: 'daily',
      durationLabel: 'Valid for 24 hours',
      icon: Icons.flash_on,
      accent: Color(0xFF2563EB),
    ),
    _PlanDefinition(
      id: 'premium_weekly',
      title: 'Premium Weekly',
      subtitle: 'Flexible 7-day access',
      price: 12000,
      currency: 'TZS',
      billingPeriod: 'weekly',
      durationLabel: 'Valid for 7 days',
      icon: Icons.calendar_view_week,
      accent: Color(0xFF16A34A),
    ),
    _PlanDefinition(
      id: 'premium_monthly',
      title: 'Premium Monthly',
      subtitle: 'Best value for active traders',
      price: 30000,
      currency: 'TZS',
      billingPeriod: 'monthly',
      durationLabel: 'Valid for 30 days',
      icon: Icons.star_outline,
      accent: Color(0xFFF97316),
    ),
  ];
}
