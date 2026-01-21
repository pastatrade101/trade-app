import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/app_theme.dart';
import '../../../app/providers.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/payment_intent.dart';
import '../../../core/models/revenue_stats.dart';
import '../../../core/models/success_payment.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/app_section_card.dart';
import '../../../core/widgets/firestore_error_widget.dart';
import 'package:stock_investment_flutter/app/app_icons.dart';

final _revenueStatsProvider = StreamProvider<RevenueStats?>((ref) {
  return ref.watch(revenueRepositoryProvider).watchStats();
});

final _recentPaymentsProvider = StreamProvider<List<SuccessPayment>>((ref) {
  return ref.watch(revenueRepositoryProvider).watchRecentPayments(limit: 200);
});

final _failedIntentsProvider = StreamProvider<List<PaymentIntent>>((ref) {
  return ref.watch(revenueRepositoryProvider).watchFailedPaymentIntents(limit: 200);
});

final _revenueUsersProvider = StreamProvider<List<AppUser>>((ref) {
  return ref.watch(userRepositoryProvider).watchUsers(limit: 500);
});

enum _TrendRange { daily, weekly, monthly }

class RevenueScreen extends ConsumerStatefulWidget {
  const RevenueScreen({super.key});

  @override
  ConsumerState<RevenueScreen> createState() => _RevenueScreenState();
}

class _RevenueScreenState extends ConsumerState<RevenueScreen> {
  bool _showUsd = false;
  bool _showAllPayments = false;
  bool _showAllFailures = false;
  _TrendRange _trendRange = _TrendRange.daily;

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(_revenueStatsProvider);
    final payments = ref.watch(_recentPaymentsProvider);
    final failures = ref.watch(_failedIntentsProvider);
    final users = ref.watch(_revenueUsersProvider);
    final tokens = AppThemeTokens.of(context);

    final statsValue = stats.valueOrNull ?? RevenueStats.empty();
    final paymentsValue = payments.valueOrNull ?? const <SuccessPayment>[];
    final isStatsLoading = stats.isLoading;
    final isPaymentsLoading = payments.isLoading;

    final currency = _showUsd ? 'USD' : statsValue.currency;
    final totalAmount =
        _showUsd ? statsValue.totalRevenue / 2500 : statsValue.totalRevenue;
    final monthAmount = _showUsd
        ? statsValue.currentMonthRevenue / 2500
        : statsValue.currentMonthRevenue;
    final todayKey = tanzaniaDateKey();
    final todayPayments = paymentsValue.where((payment) {
      final createdAt = payment.createdAt;
      if (createdAt == null) {
        return false;
      }
      return tanzaniaDateKey(createdAt) == todayKey;
    }).toList();
    final hasStatsForToday = statsValue.todayDate == todayKey;
    final todayAmountRaw = todayPayments.isNotEmpty
        ? todayPayments.fold<double>(
            0,
            (sum, payment) => sum + payment.amount,
          )
        : (hasStatsForToday ? statsValue.todayRevenue : 0);
    final todayPaymentsCount = todayPayments.isNotEmpty
        ? todayPayments.length
        : (hasStatsForToday ? statsValue.todayPayments : 0);
    final todayAmount = _showUsd
        ? (todayAmountRaw / 2500).toDouble()
        : todayAmountRaw.toDouble();

    final revenueTab = _buildRevenueTab(
      stats: stats,
      payments: payments,
      tokens: tokens,
      currency: currency,
      totalAmount: totalAmount,
      monthAmount: monthAmount,
      todayAmount: todayAmount,
      todayPaymentsCount: todayPaymentsCount,
      statsValue: statsValue,
      paymentsValue: paymentsValue,
      isStatsLoading: isStatsLoading,
      isPaymentsLoading: isPaymentsLoading,
    );

    return DefaultTabController(
      length: 2,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _RevenueTabBar(tokens: tokens),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                children: [
                  revenueTab,
                  _buildFailuresTab(failures, users),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueTab({
    required AsyncValue<RevenueStats?> stats,
    required AsyncValue<List<SuccessPayment>> payments,
    required AppThemeTokens tokens,
    required String currency,
    required double totalAmount,
    required double monthAmount,
    required double todayAmount,
    required int todayPaymentsCount,
    required RevenueStats statsValue,
    required List<SuccessPayment> paymentsValue,
    required bool isStatsLoading,
    required bool isPaymentsLoading,
  }) {
    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Revenue',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              _CurrencyToggle(
                showUsd: _showUsd,
                onChanged: (value) => setState(() => _showUsd = value),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (stats.hasError)
            FirestoreErrorWidget(
              error: stats.error!,
              stackTrace: stats.stackTrace,
              title: 'Revenue failed to load',
            )
          else if (isStatsLoading)
            const _LoadingCard()
          else
            _RevenueHeroCard(
              amount: totalAmount,
              currency: currency,
              subtitle: '${todayPaymentsCount} payments today',
              percentLabel: _trendLabel(paymentsValue),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _RevenueSummaryCard(
                  title: 'This month',
                  amount: monthAmount,
                  currency: currency,
                  amountText:
                      '${_formatAmount(monthAmount, decimals: _showUsd ? 2 : 0)} $currency',
                  subtitle: '${statsValue.currentMonthPayments} payments',
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _RevenueSummaryCard(
                  title: 'Today',
                  amount: todayAmount,
                  currency: currency,
                  amountText:
                      '${_formatAmount(todayAmount, decimals: _showUsd ? 2 : 0)} $currency',
                  subtitle: '$todayPaymentsCount payments',
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SubscriptionsCard(
            payments: paymentsValue,
            loading: isPaymentsLoading,
          ),
          const SizedBox(height: 16),
          _RevenueTrendCard(
            payments: paymentsValue,
            currency: currency,
            showUsd: _showUsd,
            range: _trendRange,
            onRangeChanged: (value) => setState(() => _trendRange = value),
          ),
          const SizedBox(height: 16),
          _PlanDistributionCard(
            payments: paymentsValue,
            currency: currency,
            showUsd: _showUsd,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recent subscriptions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              TextButton(
                onPressed: () => setState(
                  () => _showAllPayments = !_showAllPayments,
                ),
                child: Text(_showAllPayments ? 'View less' : 'View all'),
              ),
            ],
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
              final visible = _showAllPayments ? items : items.take(5).toList();
              return Column(
                children: visible
                    .map(
                      (payment) => _PaymentListTile(
                        payment: payment,
                        onTap: () => _showPaymentDetails(payment),
                      ),
                    )
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
    );
  }

  Widget _buildFailuresTab(
    AsyncValue<List<PaymentIntent>> failures,
    AsyncValue<List<AppUser>> users,
  ) {
    final tokens = AppThemeTokens.of(context);
    final usersValue = users.valueOrNull ?? const <AppUser>[];
    final userMap = {
      for (final user in usersValue) user.uid: user,
    };

    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Transaction failures',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              TextButton(
                onPressed: () => setState(
                  () => _showAllFailures = !_showAllFailures,
                ),
                child: Text(_showAllFailures ? 'View less' : 'View all'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          failures.when(
            data: (items) {
              if (items.isEmpty) {
                return AppSectionCard(
                  child: Text(
                    'No failed transactions recorded yet.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: tokens.mutedText),
                  ),
                );
              }
              final visible = _showAllFailures ? items : items.take(5).toList();
              return Column(
                children: visible
                    .map(
                      (intent) => _FailedIntentTile(
                        intent: intent,
                        user: userMap[intent.uid],
                      ),
                    )
                    .toList(),
              );
            },
            loading: () => const _LoadingList(),
            error: (error, stack) => FirestoreErrorWidget(
              error: error,
              stackTrace: stack,
              title: 'Failed payments could not load',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPaymentDetails(SuccessPayment payment) async {
    final tokens = AppThemeTokens.of(context);
    final userFuture =
        ref.read(userRepositoryProvider).fetchUser(payment.uid);
    final createdAt = payment.createdAt;
    final timeLabel =
        createdAt != null ? formatTanzaniaDateTime(createdAt) : '—';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Payment details',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(AppIcons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                AppSectionCard(
                  child: Row(
                    children: [
                      Container(
                        height: 44,
                        width: 44,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(AppIcons.receipt_long),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_formatAmount(payment.amount, decimals: _currencyDecimals(payment.currency))} ${payment.currency}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_planLabel(payment.productId)} • ${payment.provider}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: tokens.mutedText),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        timeLabel,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: tokens.mutedText),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                FutureBuilder(
                  future: userFuture,
                  builder: (context, snapshot) {
                    final user = snapshot.data;
                    final displayName = user?.displayName?.trim().isNotEmpty ==
                            true
                        ? user!.displayName
                        : 'Member';
                    final username = user?.username?.trim().isNotEmpty == true
                        ? '@${user!.username}'
                        : payment.uid;
                    return AppSectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Purchased by',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: tokens.mutedText),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            displayName,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            username,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: tokens.mutedText),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(AppIcons.phone, size: 16, color: tokens.mutedText),
                              const SizedBox(width: 6),
                              Text(
                                payment.msisdn,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RevenueTabBar extends StatelessWidget {
  const _RevenueTabBar({required this.tokens});

  final AppThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
        );
    return TabBar(
      isScrollable: true,
      labelColor: colorScheme.primary,
      unselectedLabelColor: tokens.mutedText,
      indicatorColor: colorScheme.primary,
      labelStyle: labelStyle,
      unselectedLabelStyle: labelStyle?.copyWith(fontWeight: FontWeight.w600),
      tabs: const [
        Tab(text: 'Revenue'),
        Tab(text: 'Transaction failures'),
      ],
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
    this.trailing,
    this.amountText,
    this.amountStyle,
  });

  final String title;
  final double amount;
  final String currency;
  final String subtitle;
  final Color color;
  final Widget? trailing;
  final String? amountText;
  final TextStyle? amountStyle;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return AppSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: tokens.mutedText,
                    ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 6),
          Text(
            amountText ??
                '${_formatAmount(amount, decimals: _currencyDecimals(currency))} $currency',
            style: amountStyle ??
                Theme.of(context).textTheme.titleLarge?.copyWith(
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

class _RevenueHeroCard extends StatelessWidget {
  const _RevenueHeroCard({
    required this.amount,
    required this.currency,
    required this.subtitle,
    required this.percentLabel,
  });

  final double amount;
  final String currency;
  final String subtitle;
  final String percentLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final amountText = '${_formatAmount(amount, decimals: currency == 'USD' ? 2 : 0)} $currency';
    final colorScheme = Theme.of(context).colorScheme;
    final baseColor = colorScheme.primary;
    final baseDark = Color.lerp(baseColor, Colors.black, 0.12) ?? baseColor;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [baseColor, baseDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: tokens.shadow,
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _RevenuePatternPainter(
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(AppIcons.attach_money, color: Colors.white),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  percentLabel,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Total Revenue',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            amountText,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                ),
          ),
        ],
          ),
        ],
      ),
    );
  }
}

class _SubscriptionsCard extends StatelessWidget {
  const _SubscriptionsCard({
    required this.payments,
    required this.loading,
  });

  final List<SuccessPayment> payments;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    if (loading) {
      return const _LoadingCard();
    }
    final now = DateTime.now();
    final activeCutoff = now.subtract(const Duration(days: 30));
    final recentCutoff = now.subtract(const Duration(days: 7));
    final activeUids = <String>{};
    final newUids = <String>{};

    for (final payment in payments) {
      final createdAt = payment.createdAt;
      if (createdAt == null) continue;
      if (createdAt.isAfter(activeCutoff)) {
        activeUids.add(payment.uid);
      }
      if (createdAt.isAfter(recentCutoff)) {
        newUids.add(payment.uid);
      }
    }

    return AppSectionCard(
      child: Row(
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFFFEDD5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(AppIcons.people_alt_outlined, color: Color(0xFFF97316)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Subscriptions',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.mutedText,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${activeUids.length}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                  'Active users',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.mutedText,
                      ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEDD5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '+${newUids.length}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFF97316),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RevenueTrendCard extends StatelessWidget {
  const _RevenueTrendCard({
    required this.payments,
    required this.currency,
    required this.showUsd,
    required this.range,
    required this.onRangeChanged,
  });

  final List<SuccessPayment> payments;
  final String currency;
  final bool showUsd;
  final _TrendRange range;
  final ValueChanged<_TrendRange> onRangeChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final trend = _buildTrendData(range, payments, showUsd);
    final maxValue =
        trend.values.isEmpty ? 0.0 : trend.values.reduce(math.max).toDouble();
    final maxY = maxValue <= 0 ? 1.0 : maxValue * 1.2;
    final spots = trend.values.asMap().entries
        .map((entry) => FlSpot(entry.key.toDouble(), entry.value))
        .toList();

    return AppSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Revenue Trend',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              _TrendToggle(range: range, onChanged: onRangeChanged),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            trend.subtitle,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: tokens.mutedText),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: tokens.border,
                    strokeWidth: 1,
                    dashArray: [6, 6],
                  ),
                  getDrawingVerticalLine: (value) => FlLine(
                    color: tokens.border,
                    strokeWidth: 1,
                    dashArray: [6, 6],
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    left: BorderSide(color: tokens.border),
                    bottom: BorderSide(color: tokens.border),
                  ),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      interval: maxY / 3,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(
                            _formatAmount(value, decimals: 0),
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: tokens.mutedText),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        final label = index >= 0 && index < trend.labels.length
                            ? trend.labels[index]
                            : '';
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            label,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: tokens.mutedText),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: Theme.of(context).colorScheme.primary,
                    barWidth: 3,
                    belowBarData: BarAreaData(
                      show: true,
                      color:
                          Theme.of(context).colorScheme.primary.withOpacity(0.12),
                    ),
                    dotData: FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Totals shown in $currency',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: tokens.mutedText),
          ),
        ],
      ),
    );
  }
}

class _TrendToggle extends StatelessWidget {
  const _TrendToggle({
    required this.range,
    required this.onChanged,
  });

  final _TrendRange range;
  final ValueChanged<_TrendRange> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Wrap(
      spacing: 6,
      children: [
        _TrendChip(
          label: 'Daily',
          selected: range == _TrendRange.daily,
          onTap: () => onChanged(_TrendRange.daily),
          tokens: tokens,
        ),
        _TrendChip(
          label: 'Weekly',
          selected: range == _TrendRange.weekly,
          onTap: () => onChanged(_TrendRange.weekly),
          tokens: tokens,
        ),
        _TrendChip(
          label: 'Monthly',
          selected: range == _TrendRange.monthly,
          onTap: () => onChanged(_TrendRange.monthly),
          tokens: tokens,
        ),
      ],
    );
  }
}

class _TrendChip extends StatelessWidget {
  const _TrendChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.tokens,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final AppThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? colorScheme.primary.withOpacity(0.12) : tokens.surfaceAlt,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? colorScheme.primary : tokens.border,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: selected ? colorScheme.primary : tokens.mutedText,
              ),
        ),
      ),
    );
  }
}

class _RevenuePatternPainter extends CustomPainter {
  _RevenuePatternPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    const spacing = 28.0;
    for (var x = -size.height; x < size.width + size.height; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
    }

    final dotPaint = Paint()..color = color.withOpacity(0.45);
    for (var y = 16.0; y < size.height; y += 40) {
      for (var x = 16.0; x < size.width; x += 48) {
        canvas.drawCircle(Offset(x, y), 1.6, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RevenuePatternPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _PlanDistributionCard extends StatelessWidget {
  const _PlanDistributionCard({
    required this.payments,
    required this.currency,
    required this.showUsd,
  });

  final List<SuccessPayment> payments;
  final String currency;
  final bool showUsd;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final items = _buildPlanDistribution(payments);
    if (items.isEmpty) {
      return AppSectionCard(
        child: Text(
          'No subscriptions recorded yet.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: tokens.mutedText),
        ),
      );
    }
    final total = items.fold<int>(0, (sum, item) => sum + item.count);

    return AppSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Plan Distribution',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'By subscription type',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: tokens.mutedText),
          ),
          const SizedBox(height: 12),
          ...items.map((item) {
            final progress = total == 0 ? 0 : item.count / total;
            final avg = item.count == 0 ? 0 : item.amount / item.count;
            final displayAmount = showUsd ? avg / 2500 : avg;
            final amountText = _formatAmount(
              displayAmount.toDouble(),
              decimals: showUsd ? 2 : 0,
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PlanDistributionRow(
                label: item.label,
                count: item.count,
                amountText: '$amountText $currency per subscription',
                progress: progress.toDouble(),
                color: item.color,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _PlanDistributionRow extends StatelessWidget {
  const _PlanDistributionRow({
    required this.label,
    required this.count,
    required this.amountText,
    required this.progress,
    required this.color,
  });

  final String label;
  final int count;
  final String amountText;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            Text(
              '$count',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: progress,
            color: color,
            backgroundColor: color.withOpacity(0.16),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          amountText,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: tokens.mutedText),
        ),
      ],
    );
  }
}

class _PaymentListTile extends StatelessWidget {
  const _PaymentListTile({
    required this.payment,
    this.onTap,
  });

  final SuccessPayment payment;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final createdAt = payment.createdAt;
    final timeLabel =
        createdAt != null ? formatTanzaniaDateTime(createdAt) : '—';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AppSectionCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    height: 46,
                    width: 46,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(AppIcons.credit_card, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_formatAmount(payment.amount, decimals: _currencyDecimals(payment.currency))} ${payment.currency}',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _planLabel(payment.productId),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: tokens.mutedText),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _ProviderChip(provider: payment.provider),
                      const SizedBox(height: 6),
                      Text(
                        timeLabel,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: tokens.mutedText),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FailedIntentTile extends StatelessWidget {
  const _FailedIntentTile({
    required this.intent,
    required this.user,
    this.onTap,
  });

  final PaymentIntent intent;
  final AppUser? user;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final time = intent.updatedAt ?? intent.createdAt;
    final timeLabel = time != null ? formatTanzaniaDateTime(time) : '—';
    final displayNameRaw = (user?.displayName ?? '').trim();
    final displayName = displayNameRaw.isNotEmpty ? displayNameRaw : 'Member';
    final phone = intent.msisdn.isNotEmpty
        ? intent.msisdn
        : (user?.phoneNumber?.isNotEmpty == true
            ? user!.phoneNumber!
            : '—');
    final statusLabel = _failureLabel(intent.status);
    final statusColor =
        _failureColor(intent.status, Theme.of(context).colorScheme, tokens);
    final providerLabel = _providerInfo(intent.provider).label;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AppSectionCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 46,
                    width: 46,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      AppIcons.report,
                      size: 20,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_formatAmount(intent.amount, decimals: _currencyDecimals(intent.currency))} ${intent.currency}',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_planLabel(intent.productId)} • $providerLabel',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: tokens.mutedText),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              AppIcons.person,
                              size: 14,
                              color: tokens.mutedText,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                displayName,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: tokens.mutedText),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              AppIcons.phone,
                              size: 14,
                              color: tokens.mutedText,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                phone,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: tokens.mutedText),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _FailureStatusChip(
                        label: statusLabel,
                        color: statusColor,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        timeLabel,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: tokens.mutedText),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FailureStatusChip extends StatelessWidget {
  const _FailureStatusChip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
      ),
    );
  }
}

class _ProviderChip extends StatelessWidget {
  const _ProviderChip({required this.provider});

  final String provider;

  @override
  Widget build(BuildContext context) {
    final info = _providerInfo(provider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: info.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        info.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: info.color,
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

class _CurrencyToggle extends StatelessWidget {
  const _CurrencyToggle({
    required this.showUsd,
    required this.onChanged,
  });

  final bool showUsd;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Wrap(
      spacing: 6,
      children: [
        _CurrencyChip(
          label: 'TZS',
          selected: !showUsd,
          onSelected: () => onChanged(false),
          tokens: tokens,
        ),
        _CurrencyChip(
          label: 'USD',
          selected: showUsd,
          onSelected: () => onChanged(true),
          tokens: tokens,
        ),
      ],
    );
  }
}

class _CurrencyChip extends StatelessWidget {
  const _CurrencyChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    required this.tokens,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final AppThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? colorScheme.primary.withOpacity(0.12) : tokens.surfaceAlt,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? colorScheme.primary : tokens.border,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: selected ? colorScheme.primary : tokens.mutedText,
              ),
        ),
      ),
    );
  }
}

String _formatAmount(double value, {required int decimals}) {
  final formatter = NumberFormat.decimalPattern('en_US')
    ..minimumFractionDigits = decimals
    ..maximumFractionDigits = decimals;
  return formatter.format(value);
}

int _currencyDecimals(String currency) {
  return currency.toUpperCase() == 'USD' ? 2 : 0;
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

String _weekdayLabel(DateTime date) {
  const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return labels[(date.weekday - 1).clamp(0, 6)];
}

String _trendLabel(List<SuccessPayment> payments) {
  if (payments.isEmpty) {
    return '0.0%';
  }
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  double todayTotal = 0;
  double yesterdayTotal = 0;
  for (final payment in payments) {
    final createdAt = payment.createdAt;
    if (createdAt == null) continue;
    final day = DateTime(createdAt.year, createdAt.month, createdAt.day);
    if (day == today) {
      todayTotal += payment.amount;
    } else if (day == yesterday) {
      yesterdayTotal += payment.amount;
    }
  }
  if (yesterdayTotal <= 0) {
    return '0.0%';
  }
  final change = ((todayTotal - yesterdayTotal) / yesterdayTotal) * 100;
  final sign = change >= 0 ? '+' : '';
  return '$sign${change.toStringAsFixed(1)}%';
}

List<_PlanDistributionItem> _buildPlanDistribution(
  List<SuccessPayment> payments,
) {
  final map = <String, _PlanDistributionItem>{
    'premium_monthly': _PlanDistributionItem(
      label: 'Premium Monthly',
      color: const Color(0xFF2563EB),
    ),
    'premium_weekly': _PlanDistributionItem(
      label: 'Premium Weekly',
      color: const Color(0xFF7C3AED),
    ),
    'premium_daily': _PlanDistributionItem(
      label: 'Premium Daily',
      color: const Color(0xFF16A34A),
    ),
  };
  for (final payment in payments) {
    final item = map[payment.productId];
    if (item == null) continue;
    item.count += 1;
    item.amount += payment.amount;
  }
  return map.values.where((item) => item.count > 0).toList();
}

class _PlanDistributionItem {
  _PlanDistributionItem({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;
  int count = 0;
  double amount = 0;
}

class _ProviderInfo {
  const _ProviderInfo({required this.label, required this.color});

  final String label;
  final Color color;
}

_ProviderInfo _providerInfo(String provider) {
  final key = provider.toLowerCase();
  switch (key) {
    case 'vodacom':
      return const _ProviderInfo(label: 'vodacom', color: Color(0xFFE60000));
    case 'airtel':
      return const _ProviderInfo(label: 'airtel', color: Color(0xFF2563EB));
    case 'tigo':
      return const _ProviderInfo(label: 'tigo', color: Color(0xFF0033A0));
    case 'mixx':
      return const _ProviderInfo(label: 'mixx', color: Color(0xFFFFD100));
    case 'halopesa':
      return const _ProviderInfo(label: 'halopesa', color: Color(0xFF00A651));
    default:
      return _ProviderInfo(label: provider, color: const Color(0xFF64748B));
  }
}

String _failureLabel(String status) {
  final key = status.toLowerCase();
  switch (key) {
    case 'pending':
    case 'created':
      return 'Pending';
    case 'failed':
      return 'Failed';
    case 'expired':
      return 'Expired';
    case 'cancelled':
    case 'canceled':
      return 'Cancelled';
    default:
      return status;
  }
}

Color _failureColor(
  String status,
  ColorScheme colorScheme,
  AppThemeTokens tokens,
) {
  final key = status.toLowerCase();
  switch (key) {
    case 'pending':
      return colorScheme.primary;
    case 'failed':
      return colorScheme.error;
    case 'expired':
    case 'cancelled':
    case 'canceled':
      return tokens.warning;
    default:
      return colorScheme.error;
  }
}

class _TrendData {
  const _TrendData({
    required this.labels,
    required this.values,
    required this.subtitle,
  });

  final List<String> labels;
  final List<double> values;
  final String subtitle;
}

_TrendData _buildTrendData(
  _TrendRange range,
  List<SuccessPayment> payments,
  bool showUsd,
) {
  final now = DateTime.now();
  switch (range) {
    case _TrendRange.weekly:
      return _buildWeeklyTrend(now, payments, showUsd);
    case _TrendRange.monthly:
      return _buildMonthlyTrend(now, payments, showUsd);
    case _TrendRange.daily:
    default:
      return _buildDailyTrend(now, payments, showUsd);
  }
}

_TrendData _buildDailyTrend(
  DateTime now,
  List<SuccessPayment> payments,
  bool showUsd,
) {
  final start = DateTime(now.year, now.month, now.day)
      .subtract(const Duration(days: 6));
  final totals = List<double>.filled(7, 0);
  for (final payment in payments) {
    final createdAt = payment.createdAt;
    if (createdAt == null) continue;
    final day = DateTime(createdAt.year, createdAt.month, createdAt.day);
    final diff = day.difference(start).inDays;
    if (diff < 0 || diff > 6) continue;
    totals[diff] += payment.amount;
  }
  if (showUsd) {
    for (var i = 0; i < totals.length; i += 1) {
      totals[i] = totals[i] / 2500;
    }
  }
  final labels = List.generate(
    7,
    (index) => _weekdayLabel(start.add(Duration(days: index))),
  );
  return _TrendData(
    labels: labels,
    values: totals,
    subtitle: 'Last 7 days performance',
  );
}

_TrendData _buildWeeklyTrend(
  DateTime now,
  List<SuccessPayment> payments,
  bool showUsd,
) {
  final weekStart = _weekStart(now);
  final start = weekStart.subtract(const Duration(days: 7 * 5));
  final totals = List<double>.filled(6, 0);
  for (final payment in payments) {
    final createdAt = payment.createdAt;
    if (createdAt == null) continue;
    final createdWeek = _weekStart(createdAt);
    final diffDays = createdWeek.difference(start).inDays;
    final index = diffDays ~/ 7;
    if (index < 0 || index > 5) continue;
    totals[index] += payment.amount;
  }
  if (showUsd) {
    for (var i = 0; i < totals.length; i += 1) {
      totals[i] = totals[i] / 2500;
    }
  }
  final labels = List.generate(
    6,
    (index) => _shortMonthDay(start.add(Duration(days: index * 7))),
  );
  return _TrendData(
    labels: labels,
    values: totals,
    subtitle: 'Last 6 weeks performance',
  );
}

_TrendData _buildMonthlyTrend(
  DateTime now,
  List<SuccessPayment> payments,
  bool showUsd,
) {
  final start = DateTime(now.year, now.month - 5, 1);
  final totals = List<double>.filled(6, 0);
  for (final payment in payments) {
    final createdAt = payment.createdAt;
    if (createdAt == null) continue;
    final index = (createdAt.year - start.year) * 12 +
        (createdAt.month - start.month);
    if (index < 0 || index > 5) continue;
    totals[index] += payment.amount;
  }
  if (showUsd) {
    for (var i = 0; i < totals.length; i += 1) {
      totals[i] = totals[i] / 2500;
    }
  }
  final labels = List.generate(
    6,
    (index) {
      final date = DateTime(start.year, start.month + index, 1);
      return _shortMonth(date.month);
    },
  );
  return _TrendData(
    labels: labels,
    values: totals,
    subtitle: 'Last 6 months performance',
  );
}

DateTime _weekStart(DateTime date) {
  return DateTime(date.year, date.month, date.day)
      .subtract(Duration(days: date.weekday - 1));
}

String _shortMonthDay(DateTime date) {
  return '${_shortMonth(date.month)} ${date.day}';
}

String _shortMonth(int month) {
  const labels = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return labels[(month - 1).clamp(0, 11)];
}
