import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../app/providers.dart';
import '../../../core/models/revenue_stats.dart';
import '../../../core/models/success_payment.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/app_section_card.dart';
import '../../../core/widgets/firestore_error_widget.dart';

final _revenueStatsProvider = StreamProvider<RevenueStats?>((ref) {
  return ref.watch(revenueRepositoryProvider).watchStats();
});

final _recentPaymentsProvider = StreamProvider<List<SuccessPayment>>((ref) {
  return ref.watch(revenueRepositoryProvider).watchRecentPayments();
});

class RevenueScreen extends ConsumerWidget {
  const RevenueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(_revenueStatsProvider);
    final payments = ref.watch(_recentPaymentsProvider);
    final tokens = AppThemeTokens.of(context);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {},
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Revenue',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            stats.when(
              data: (value) {
                final data = value ?? RevenueStats.empty();
                return Column(
                  children: [
                    _RevenueSummaryCard(
                      title: 'Total revenue',
                      amount: data.totalRevenue,
                      currency: data.currency,
                      subtitle: '${data.totalPayments} payments',
                      color: tokens.success,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _RevenueSummaryCard(
                            title: 'This month',
                            amount: data.currentMonthRevenue,
                            currency: data.currency,
                            subtitle:
                                '${data.currentMonthPayments} payments',
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _RevenueSummaryCard(
                            title: 'Today',
                            amount: data.todayRevenue,
                            currency: data.currency,
                            subtitle: '${data.todayPayments} payments',
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
              loading: () => const _LoadingCard(),
              error: (error, stack) => FirestoreErrorWidget(
                error: error,
                stackTrace: stack,
                title: 'Revenue failed to load',
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Recent subscriptions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            payments.when(
              data: (items) {
                if (items.isEmpty) {
                  return AppSectionCard(
                    child: Text(
                      'No payments recorded yet.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: tokens.mutedText),
                    ),
                  );
                }
                return Column(
                  children: items
                      .map((payment) => _PaymentListTile(payment: payment))
                      .toList(),
                );
              },
              loading: () => const _LoadingList(),
              error: (error, stack) => FirestoreErrorWidget(
                error: error,
                stackTrace: stack,
                title: 'Payments failed to load',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevenueSummaryCard extends StatelessWidget {
  const _RevenueSummaryCard({
    required this.title,
    required this.amount,
    required this.currency,
    required this.subtitle,
    required this.color,
  });

  final String title;
  final double amount;
  final String currency;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return AppSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: tokens.mutedText,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            '${amount.toStringAsFixed(0)} $currency',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
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
    );
  }
}

class _PaymentListTile extends StatelessWidget {
  const _PaymentListTile({required this.payment});

  final SuccessPayment payment;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final createdAt = payment.createdAt;
    final timeLabel =
        createdAt != null ? formatTanzaniaDateTime(createdAt) : '—';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppSectionCard(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            '${payment.amount.toStringAsFixed(0)} ${payment.currency}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          subtitle: Text(
            '${_planLabel(payment.productId)} • ${payment.provider}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: tokens.mutedText),
          ),
          trailing: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                timeLabel,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: tokens.mutedText),
              ),
              Text(
                payment.msisdn,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: tokens.mutedText,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const AppSectionCard(
      child: Center(
        child: SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      ),
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return const AppSectionCard(
      child: Center(
        child: SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      ),
    );
  }
}

String _planLabel(String productId) {
  switch (productId) {
    case 'premium_daily':
      return 'Premium Daily';
    case 'premium_weekly':
      return 'Premium Weekly';
    case 'premium_monthly':
      return 'Premium Monthly';
    default:
      return productId;
  }
}
