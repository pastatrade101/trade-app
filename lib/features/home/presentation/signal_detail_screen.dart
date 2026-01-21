import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../app/providers.dart';
import '../../../core/models/signal.dart';
import '../../../core/models/signal_premium_details.dart';
import '../../../core/models/trading_session_config.dart';
import '../../../core/utils/role_helpers.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/firestore_error_widget.dart';
import '../../reports/presentation/report_dialog.dart';
import '../../profile/presentation/trader_profile_screen.dart';
import '../../premium/presentation/premium_paywall_screen.dart';
import '../../../services/analytics_service.dart';
import 'package:stock_investment_flutter/app/app_icons.dart';

final signalDetailProvider = StreamProvider.family<Signal?, String>((ref, id) {
  return ref.read(signalRepositoryProvider).watchSignal(id);
});

final signalPremiumDetailsProvider = StreamProvider.family<
    SignalPremiumDetails?,
    ({
      String signalId,
      bool canView,
    })>((ref, args) {
  if (!args.canView) {
    return Stream.value(null);
  }
  return ref.watch(signalRepositoryProvider).watchPremiumDetails(args.signalId);
});

class SignalDetailScreen extends ConsumerStatefulWidget {
  const SignalDetailScreen({super.key, required this.signalId});

  final String signalId;

  @override
  ConsumerState<SignalDetailScreen> createState() => _SignalDetailScreenState();
}

class _SignalDetailScreenState extends ConsumerState<SignalDetailScreen> {
  final _adminNoteController = TextEditingController();
  bool _adminLoading = false;
  Timer? _clock;
  bool _loggedView = false;

  @override
  void dispose() {
    _clock?.cancel();
    _adminNoteController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _resolveSignal(Signal signal, String outcome) async {
    if (_adminLoading) return;
    setState(() {
      _adminLoading = true;
    });
    final note = _adminNoteController.text.trim();
    final data = <String, Object?>{
      'status': 'resolved',
      'finalOutcome': outcome,
      'resolvedBy': 'admin',
      'resolvedAt': FieldValue.serverTimestamp(),
      'lockVotes': true,
    };
    if (note.isNotEmpty) {
      data['adminNote'] = note;
    } else {
      data['adminNote'] = FieldValue.delete();
    }
    try {
      await ref.read(signalRepositoryProvider).updateSignal(signal.id, data);
      _adminNoteController.clear();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to resolve signal: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _adminLoading = false;
        });
      }
    }
  }

  Future<void> _toggleSaved({
    required String uid,
    required String signalId,
    required bool isSaved,
  }) async {
    try {
      final repo = ref.read(signalRepositoryProvider);
      if (isSaved) {
        await repo.removeSavedSignal(uid: uid, signalId: signalId);
        if (mounted) {
          AppToast.info(context, 'Removed from saved');
        }
      } else {
        await repo.saveSignal(uid: uid, signalId: signalId);
        if (mounted) {
          AppToast.success(context, 'Saved signal');
        }
      }
    } catch (_) {
      if (mounted) {
        AppToast.error(context, 'Unable to save signal');
      }
    }
  }

  Future<void> _toggleHide(Signal signal) async {
    if (_adminLoading) return;
    setState(() {
      _adminLoading = true;
    });
    final newStatus = signal.status == 'hidden' ? 'open' : 'hidden';
    try {
      await ref.read(signalRepositoryProvider).updateSignal(signal.id, {
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update status: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _adminLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final signalState = ref.watch(signalDetailProvider(widget.signalId));
    final currentUser = ref.watch(currentUserProvider).value;
    final isPremiumActive = ref.watch(isPremiumActiveProvider);
    final sessionConfig =
        ref.watch(tradingSessionConfigProvider).asData?.value ??
            TradingSessionConfig.fallback();
    final tokens = AppThemeTokens.of(context);

    if (!_loggedView) {
      final signal = signalState.value;
      if (signal != null) {
        _loggedView = true;
        AnalyticsService.instance.logEvent(
          'signal_open',
          params: {
            'signalId': signal.id,
            'traderUid': signal.uid,
            'pair': signal.pair,
          },
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Signal details'),
        actions: [
          if (currentUser != null && !isAdmin(currentUser.role))
            StreamBuilder<bool>(
              stream: ref
                  .read(signalRepositoryProvider)
                  .watchSavedSignal(currentUser.uid, widget.signalId),
              builder: (context, snapshot) {
                final isSaved = snapshot.data ?? false;
                return IconButton(
                  tooltip: isSaved ? 'Saved' : 'Save',
                  icon: Icon(
                    isSaved ? AppIcons.bookmark : AppIcons.bookmark_border,
                  ),
                  onPressed: () => _toggleSaved(
                    uid: currentUser.uid,
                    signalId: widget.signalId,
                    isSaved: isSaved,
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(AppIcons.flag),
            onPressed: () async {
              await showDialog(
                context: context,
                builder: (_) => ReportDialog(
                  targetType: 'signal',
                  targetId: widget.signalId,
                ),
              );
            },
          ),
        ],
      ),
      body: signalState.when(
        data: (signal) {
          if (signal == null) {
            return const Center(child: Text('Signal not found'));
          }
          final colorScheme = Theme.of(context).colorScheme;
          final canViewPremium = isPremiumActive ||
              (currentUser?.role == 'admin') ||
              (currentUser?.uid == signal.uid);
          final isLocked = signal.premiumOnly && !canViewPremium;
          final premiumDetailsState = signal.premiumOnly
              ? ref.watch(signalPremiumDetailsProvider((
                  signalId: widget.signalId,
                  canView: canViewPremium,
                )))
              : const AsyncValue<SignalPremiumDetails?>.data(null);
          final premiumDetails = premiumDetailsState.valueOrNull;
          final entryText = _entryText(
            premiumDetails?.entryPrice ?? signal.entryPrice,
            premiumDetails?.entryRange ?? signal.entryRange,
            locked: isLocked,
          );
          final dateText = formatTanzaniaDateTime(signal.validUntil);
          final sessionLabel = sessionConfig.labelFor(signal.session);
          final now = DateTime.now();
          final tradeStart = signal.openedAt ?? signal.createdAt;
          final tradeEnd = signal.validUntil;
          final tradeProgress = _progressBetween(tradeStart, tradeEnd, now);
          final finalOutcomeLabel = signal.finalOutcome;
          final showResolveButtons =
              signal.status == 'open' ||
              signal.status == 'voting' ||
              signal.status == 'expired_unverified';
          final isAdminUser = currentUser != null && isAdmin(currentUser.role);
          final resolvedAtText = signal.resolvedAt != null
              ? formatTanzaniaDateTime(signal.resolvedAt!)
              : null;
          final openPaywall = () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const PremiumPaywallScreen(
                  sourceScreen: 'SignalDetails',
                ),
              ),
            );
          };

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (signal.imageUrl != null && !isLocked)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InteractiveViewer(
                        child: Image.network(signal.imageUrl!),
                      ),
                    ),
                  _SignalTradeCard(
                    signal: signal,
                    entryText: entryText,
                    dateText: dateText,
                    sessionLabel: sessionLabel,
                    expiresIn: _buildExpiresInLabel(signal.validUntil, now),
                    premiumDetails: premiumDetails,
                    isLocked: isLocked,
                    onUpgrade: isLocked ? openPaywall : null,
                    isPremiumLoading:
                        signal.premiumOnly &&
                        canViewPremium &&
                        premiumDetailsState.isLoading,
                  ),
                  if (finalOutcomeLabel != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Chip(
                              backgroundColor: _outcomeColor(
                                      finalOutcomeLabel,
                                      Theme.of(context).colorScheme,
                                      tokens)
                                  .withOpacity(0.15),
                              side: BorderSide(
                                color: _outcomeColor(
                                        finalOutcomeLabel,
                                        Theme.of(context).colorScheme,
                                        tokens)
                                    .withOpacity(0.6),
                              ),
                              label: Text('Final outcome: $finalOutcomeLabel'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Resolved by ${signal.resolvedBy ?? 'admin'}'
                          '${resolvedAtText != null ? ' · $resolvedAtText' : ''}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    )
                  else if (signal.status != 'open')
                    Row(
                      children: [
                        Chip(label: Text(_statusLabel(signal.status))),
                      ],
                    ),
                  const SizedBox(height: 12),
                  if (signal.status == 'open') ...[
                    _ProgressBar(
                      label: 'Trade progress',
                      value: tradeProgress,
                    ),
                    const SizedBox(height: 12),
                  ],
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TraderProfileScreen(uid: signal.uid),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        Text(
                          signal.posterNameSnapshot,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (signal.posterVerifiedSnapshot)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(
                              AppIcons.verified,
                              size: 16,
                              color: colorScheme.primary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (isLocked)
                    _LockedReasoningCard(onUpgrade: openPaywall)
                  else
                    _ReasoningCard(
                      reasoning: premiumDetails?.reason ?? signal.reasoning,
                      tags: signal.tags,
                    ),
                  if (isAdminUser) ...[
                    const Divider(height: 32),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Admin actions',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _adminNoteController,
                              decoration: const InputDecoration(
                                labelText: 'Admin note (optional)',
                              ),
                              maxLines: 2,
                            ),
                            const SizedBox(height: 8),
                            if (showResolveButtons)
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: ['TP', 'SL', 'BE', 'PARTIAL']
                                    .map((outcome) => ElevatedButton(
                                          onPressed: _adminLoading
                                              ? null
                                              : () => _resolveSignal(
                                                  signal, outcome),
                                          child: Text('Resolve $outcome'),
                                        ))
                                    .toList(),
                              ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: _adminLoading
                                  ? null
                                  : () => _toggleHide(signal),
                              child: Text(signal.status == 'hidden'
                                  ? 'Unhide signal'
                                  : 'Hide signal'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: FirestoreErrorWidget(
              error: error,
              stackTrace: stack,
              title: 'Signal failed to load',
            ),
          ),
        ),
    );
  }
}

class _SignalTradeCard extends StatelessWidget {
  const _SignalTradeCard({
    required this.signal,
    required this.entryText,
    required this.dateText,
    required this.sessionLabel,
    required this.expiresIn,
    required this.premiumDetails,
    required this.isLocked,
    required this.isPremiumLoading,
    this.onUpgrade,
  });

  final Signal signal;
  final String entryText;
  final String dateText;
  final String sessionLabel;
  final String expiresIn;
  final SignalPremiumDetails? premiumDetails;
  final bool isLocked;
  final bool isPremiumLoading;
  final VoidCallback? onUpgrade;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final isBuy = signal.direction.toLowerCase() == 'buy';
    final directionColor = isBuy ? tokens.success : colorScheme.error;
    final statusLabel = _statusLabel(signal.status);
    final statusColor = _statusColor(signal.status, colorScheme, tokens);
    final tp1Value = isLocked ? null : (premiumDetails?.tp1 ?? signal.tp1);
    final stopLossValue =
        isLocked ? null : (premiumDetails?.stopLoss ?? signal.stopLoss);
    final tp2Value = isLocked ? null : (premiumDetails?.tp2 ?? signal.tp2);
    final entryTypeText = isLocked
        ? 'Premium'
        : (premiumDetails?.entryType ?? signal.entryType);
    final riskText = signal.riskLevel;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isLocked)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.primary.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(AppIcons.lock, size: 18, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Premium signal details are locked.',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: onUpgrade,
                      child: const Text('Upgrade'),
                    ),
                  ],
                ),
              ),
            if (!isLocked && isPremiumLoading)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Loading premium details...',
                      style: textTheme.bodySmall?.copyWith(
                        color: tokens.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        signal.pair,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      _Pill(
                        label: signal.direction,
                        color: directionColor,
                      ),
                      if (signal.premiumOnly)
                        _Pill(
                          label: 'Premium Signal',
                          color: colorScheme.primary,
                          dense: true,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _Pill(
                  label: statusLabel,
                  color: statusColor,
                  dense: true,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _SignalStat(
                        label: 'Entry',
                        value: entryText,
                        valueColor: textTheme.bodyLarge?.color,
                        icon: AppIcons.login,
                      ),
                      const SizedBox(height: 10),
                      _SignalStat(
                        label: 'TP1',
                        value: tp1Value?.toStringAsFixed(2) ?? '--',
                        valueColor:
                            tp1Value != null ? tokens.success : tokens.mutedText,
                        icon: AppIcons.flag_outlined,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      _SignalStat(
                        label: 'SL',
                        value: stopLossValue?.toStringAsFixed(2) ?? '--',
                        valueColor: stopLossValue != null
                            ? colorScheme.error
                            : tokens.mutedText,
                        icon: AppIcons.stop_circle_outlined,
                      ),
                      const SizedBox(height: 10),
                      _SignalStat(
                        label: 'TP2',
                        value: tp2Value?.toStringAsFixed(2) ?? '--',
                        valueColor:
                            tp2Value != null ? tokens.success : tokens.mutedText,
                        icon: AppIcons.flag,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _SignalStat(
                    label: 'Type',
                    value: entryTypeText,
                    valueColor: textTheme.bodyLarge?.color,
                    icon: AppIcons.tune,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SignalStat(
                    label: 'Risk',
                    value: riskText,
                    valueColor: textTheme.bodyLarge?.color,
                    icon: AppIcons.shield_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            AppIcons.person_outline,
                            size: 14,
                            color: tokens.mutedText,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              signal.posterNameSnapshot,
                              style: textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (signal.posterVerifiedSnapshot) ...[
                            const SizedBox(width: 4),
                            Icon(
                              AppIcons.verified,
                              size: 14,
                              color: colorScheme.primary,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            AppIcons.schedule,
                            size: 14,
                            color: tokens.mutedText,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Session: $sessionLabel',
                              style: textTheme.bodySmall?.copyWith(
                                color: tokens.mutedText,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          AppIcons.event,
                          size: 14,
                          color: tokens.mutedText,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Expires at: $dateText',
                          style: textTheme.bodySmall?.copyWith(
                            color: tokens.mutedText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          AppIcons.timer,
                          size: 14,
                          color: tokens.mutedText,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          expiresIn,
                          style: textTheme.bodySmall?.copyWith(
                            color: tokens.mutedText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _entryText(
  double? entryPrice,
  EntryRange? entryRange, {
  bool locked = false,
}) {
  if (locked) {
    return 'Locked';
  }
  if (entryPrice != null) {
    return entryPrice.toStringAsFixed(2);
  }
  if (entryRange != null) {
    return '${entryRange.min.toStringAsFixed(2)} - ${entryRange.max.toStringAsFixed(2)}';
  }
  return '--';
}

class _ReasoningCard extends StatelessWidget {
  const _ReasoningCard({
    required this.reasoning,
    required this.tags,
  });

  final String reasoning;
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(AppIcons.lightbulb_outline, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Trader reasoning',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              reasoning,
              style: textTheme.bodyMedium?.copyWith(
                height: 1.4,
              ),
            ),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: tags
                    .map((tag) => Chip(
                          label: Text(tag),
                          backgroundColor: tokens.surface,
                          labelStyle: textTheme.labelSmall?.copyWith(
                            color: tokens.mutedText,
                            fontWeight: FontWeight.w600,
                          ),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LockedReasoningCard extends StatelessWidget {
  const _LockedReasoningCard({required this.onUpgrade});

  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(AppIcons.lock_outline, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Trader reasoning',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Upgrade to unlock the full trade reasoning and strategy notes.',
              style: textTheme.bodyMedium?.copyWith(
                height: 1.4,
                color: tokens.mutedText,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onUpgrade,
                child: const Text('Upgrade to Premium'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _SignalStat extends StatelessWidget {
  const _SignalStat({
    required this.label,
    required this.value,
    required this.valueColor,
    this.icon,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        SizedBox(
          width: 58,
          child: Row(
            children: [
              if (icon != null)
                Icon(
                  icon,
                  size: 14,
                  color: tokens.mutedText,
                ),
              if (icon != null) const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: textTheme.labelSmall?.copyWith(
                    color: tokens.mutedText,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.color,
    this.dense = false,
  });

  final String label;
  final Color color;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: dense ? 4 : 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.label,
    required this.value,
  });

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: clamped,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${(clamped * 100).toStringAsFixed(0)}% complete',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

String _statusLabel(String status) {
  final normalized = status.toLowerCase();
  if (normalized == 'open') {
    return 'ACTIVE';
  }
  if (normalized == 'voting') {
    return 'CLOSED';
  }
  if (normalized == 'expired_unverified') {
    return 'UNVERIFIED';
  }
  return status.toUpperCase();
}

Color _statusColor(String status, ColorScheme colorScheme, AppThemeTokens tokens) {
  final normalized = status.toLowerCase();
  if (normalized == 'open') {
    return colorScheme.primary;
  }
  if (normalized == 'voting') {
    return tokens.mutedText;
  }
  if (normalized == 'resolved' || normalized == 'closed') {
    return tokens.mutedText;
  }
  if (normalized == 'expired_unverified') {
    return tokens.warning;
  }
  return tokens.warning;
}

Color _outcomeColor(
  String outcome,
  ColorScheme colorScheme,
  AppThemeTokens tokens,
) {
  switch (outcome.toUpperCase()) {
    case 'TP':
      return tokens.success;
    case 'SL':
      return colorScheme.error;
    case 'BE':
      return tokens.mutedText;
    case 'PARTIAL':
      return tokens.warning;
    default:
      return colorScheme.primary;
  }
}

double _progressBetween(DateTime start, DateTime end, DateTime now) {
  final startMs = start.millisecondsSinceEpoch;
  final endMs = end.millisecondsSinceEpoch;
  if (endMs <= startMs) {
    return 1.0;
  }
  final nowMs = now.millisecondsSinceEpoch;
  final progress = (nowMs - startMs) / (endMs - startMs);
  if (progress.isNaN) {
    return 0.0;
  }
  return progress.clamp(0.0, 1.0);
}

String _buildExpiresInLabel(DateTime expiresAt, DateTime now) {
  final remaining = expiresAt.difference(now);
  if (remaining.isNegative) {
    return 'Expired';
  }
  return 'Expires in ${formatCountdown(remaining)}';
}
