import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app_theme.dart';
import '../app/providers.dart';
import '../services/purchase_service.dart';

class ApplePaywallScreen extends ConsumerWidget {
  const ApplePaywallScreen({super.key, this.sourceScreen});

  final String? sourceScreen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = AppThemeTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final state = ref.watch(applePurchaseServiceProvider);
    final controller = ref.read(applePurchaseServiceProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Upgrade')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Go Premium',
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Unlock full access to premium signals and trader insights.',
            style: textTheme.bodyMedium?.copyWith(color: tokens.mutedText),
          ),
          const SizedBox(height: 16),
          if (state.isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (state.showFallback)
            _FallbackCard(onRetry: controller.loadProducts)
          else ...[
            for (final product in state.products) ...[
              _PlanCard(
                product: product,
                isSelected: state.selectedProductId == product.details.id,
                onTap: () => controller.selectProduct(product.details.id),
              ),
              const SizedBox(height: 12),
            ],
            if (state.actionError != null) ...[
              Text(
                state.actionError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: state.isPurchasing
                    ? null
                    : controller.buySelectedProduct,
                child: state.isPurchasing
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Continue'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: state.isRestoring
                    ? null
                    : controller.restorePurchases,
                child: state.isRestoring
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Restore Purchases'),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Payment will be charged to your Apple ID account. '
              'Subscription automatically renews unless canceled at least 24 '
              'hours before the end of the current period. Manage or cancel '
              'in Apple ID settings.',
              style: textTheme.bodySmall?.copyWith(color: tokens.mutedText),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.product,
    required this.isSelected,
    required this.onTap,
  });

  final AppleSubscriptionProduct product;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final borderColor =
        isSelected ? Theme.of(context).colorScheme.primary : tokens.border;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          color: tokens.surface,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.displayName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${product.price} ${product.billingPeriod}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: tokens.mutedText,
                        ),
                  ),
                  if (product.trialBadge != null) ...[
                    const SizedBox(height: 8),
                    _TrialBadge(label: product.trialBadge!),
                  ],
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}

class _TrialBadge extends StatelessWidget {
  const _TrialBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tokens.success.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.success.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: tokens.success,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _FallbackCard extends StatelessWidget {
  const _FallbackCard({required this.onRetry});

  final VoidCallback onRetry;

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
            'Subscriptions unavailable. Please try again later.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ),
        ],
      ),
    );
  }
}
