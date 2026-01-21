import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../app/app_theme.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/signal.dart';
import '../../../core/models/signal_premium_details.dart';
import '../../../core/models/trading_session_config.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/app_toast.dart';
import '../../premium/presentation/premium_paywall_screen.dart';
import 'package:stock_investment_flutter/app/app_icons.dart';

class SignalCard extends ConsumerWidget {
  const SignalCard({super.key, required this.signal, required this.onTap});

  final Signal signal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider).value;
    final isPremiumActive = ref.watch(isPremiumActiveProvider);
    final canSave = currentUser != null && currentUser.role != 'admin';
    final tokens = AppThemeTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final canViewPremium = isPremiumActive ||
        currentUser?.role == 'admin' ||
        currentUser?.uid == signal.uid;
    final isLocked = signal.premiumOnly && !canViewPremium;
    final sessionConfig = ref.watch(tradingSessionConfigProvider).asData?.value ??
        TradingSessionConfig.fallback();
    final sessionLabel = sessionConfig.labelFor(signal.session);
    final dateText = formatTanzaniaDateTime(signal.validUntil);
    final remaining = signal.validUntil.difference(DateTime.now());
    final expiresIn = remaining.isNegative
        ? 'Expired'
        : 'Expires in ${formatCountdown(remaining)}';
    final isBuy = signal.direction.toLowerCase() == 'buy';
    final directionColor = isBuy ? tokens.success : colorScheme.error;
    final statusLabel = _statusLabel(signal.status);
    final statusColor = _statusColor(signal.status, colorScheme, tokens);

    if (isLocked) {
      return _LockedSignalCard(
        signal: signal,
        canSave: canSave,
        currentUser: currentUser,
        onTap: onTap,
        sessionLabel: sessionLabel,
        dateText: dateText,
        expiresIn: expiresIn,
        directionColor: directionColor,
        statusLabel: statusLabel,
        statusColor: statusColor,
      );
    }

    if (signal.premiumOnly && canViewPremium) {
      return StreamBuilder<SignalPremiumDetails?>(
        stream: ref.read(signalRepositoryProvider).watchPremiumDetails(signal.id),
        builder: (context, snapshot) {
          final details = snapshot.data;
          if (details == null && snapshot.connectionState == ConnectionState.waiting) {
            return _LoadingPremiumCard(
              signal: signal,
              onTap: onTap,
              sessionLabel: sessionLabel,
              dateText: dateText,
              expiresIn: expiresIn,
              directionColor: directionColor,
              statusLabel: statusLabel,
              statusColor: statusColor,
            );
          }
          return _SignalCardBody(
            signal: signal,
            onTap: onTap,
            canSave: canSave,
            currentUser: currentUser,
            entryText: _entryText(
              details?.entryPrice,
              details?.entryRange,
            ),
            tp1: details?.tp1,
            stopLoss: details?.stopLoss,
            tp2: details?.tp2,
            sessionLabel: sessionLabel,
            dateText: dateText,
            expiresIn: expiresIn,
            directionColor: directionColor,
            statusLabel: statusLabel,
            statusColor: statusColor,
          );
        },
      );
    }

    return _SignalCardBody(
      signal: signal,
      onTap: onTap,
      canSave: canSave,
      currentUser: currentUser,
      entryText: _entryText(signal.entryPrice, signal.entryRange),
      tp1: signal.tp1,
      stopLoss: signal.stopLoss,
      tp2: signal.tp2,
      sessionLabel: sessionLabel,
      dateText: dateText,
      expiresIn: expiresIn,
      directionColor: directionColor,
      statusLabel: statusLabel,
      statusColor: statusColor,
    );
  }
}

String _entryText(double? entryPrice, EntryRange? entryRange) {
  if (entryPrice != null) {
    return entryPrice.toStringAsFixed(2);
  }
  if (entryRange != null) {
    return '${entryRange.min.toStringAsFixed(2)} - ${entryRange.max.toStringAsFixed(2)}';
  }
  return '--';
}

class _SignalCardBody extends ConsumerWidget {
  const _SignalCardBody({
    required this.signal,
    required this.onTap,
    required this.canSave,
    required this.currentUser,
    required this.entryText,
    required this.tp1,
    required this.stopLoss,
    required this.tp2,
    required this.sessionLabel,
    required this.dateText,
    required this.expiresIn,
    required this.directionColor,
    required this.statusLabel,
    required this.statusColor,
  });

  final Signal signal;
  final VoidCallback onTap;
  final bool canSave;
  final AppUser? currentUser;
  final String entryText;
  final double? tp1;
  final double? stopLoss;
  final double? tp2;
  final String sessionLabel;
  final String dateText;
  final String expiresIn;
  final Color directionColor;
  final String statusLabel;
  final Color statusColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = AppThemeTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final tp1Value = tp1 ?? signal.tp1;
    final stopLossValue = stopLoss ?? signal.stopLoss;
    final tp2Value = tp2 ?? signal.tp2;
    final currentUserId = currentUser?.uid;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (canSave && currentUserId != null)
                    StreamBuilder<bool>(
                      stream: ref
                          .read(signalRepositoryProvider)
                          .watchSavedSignal(currentUserId!, signal.id),
                      builder: (context, snapshot) {
                        final isSaved = snapshot.data ?? false;
                        final uid = currentUserId!;
                        return IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: isSaved ? 'Saved' : 'Save',
                          icon: Icon(
                            isSaved ? AppIcons.bookmark : AppIcons.bookmark_border,
                            color: isSaved ? colorScheme.primary : null,
                          ),
                          onPressed: () async {
                            try {
                              final repo = ref.read(signalRepositoryProvider);
                              if (isSaved) {
                                await repo.removeSavedSignal(
                                  uid: uid,
                                  signalId: signal.id,
                                );
                                if (context.mounted) {
                                  AppToast.info(context, 'Removed from saved');
                                }
                              } else {
                                await repo.saveSignal(
                                  uid: uid,
                                  signalId: signal.id,
                                );
                                if (context.mounted) {
                                  AppToast.success(context, 'Saved signal');
                                }
                              }
                            } catch (error) {
                              if (context.mounted) {
                                AppToast.error(context, 'Unable to save signal');
                              }
                            }
                          },
                        );
                      },
                    ),
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
                          value: tp1Value.toStringAsFixed(2),
                          valueColor: tokens.success,
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
                          value: stopLossValue.toStringAsFixed(2),
                          valueColor: colorScheme.error,
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
      ),
    );
  }
}

class _LockedSignalCard extends ConsumerWidget {
  const _LockedSignalCard({
    required this.signal,
    required this.canSave,
    required this.currentUser,
    required this.onTap,
    required this.sessionLabel,
    required this.dateText,
    required this.expiresIn,
    required this.directionColor,
    required this.statusLabel,
    required this.statusColor,
  });

  final Signal signal;
  final bool canSave;
  final AppUser? currentUser;
  final VoidCallback onTap;
  final String sessionLabel;
  final String dateText;
  final String expiresIn;
  final Color directionColor;
  final String statusLabel;
  final Color statusColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = AppThemeTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final currentUserId = currentUser?.uid;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                        _Pill(
                          label: 'Premium Signal',
                          color: colorScheme.primary,
                          dense: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (canSave && currentUserId != null)
                    StreamBuilder<bool>(
                      stream: ref
                          .read(signalRepositoryProvider)
                          .watchSavedSignal(currentUserId!, signal.id),
                      builder: (context, snapshot) {
                        final isSaved = snapshot.data ?? false;
                        final uid = currentUserId!;
                        return IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: isSaved ? 'Saved' : 'Save',
                          icon: Icon(
                            isSaved ? AppIcons.bookmark : AppIcons.bookmark_border,
                            color: isSaved ? colorScheme.primary : null,
                          ),
                          onPressed: () async {
                            try {
                              final repo = ref.read(signalRepositoryProvider);
                              if (isSaved) {
                                await repo.removeSavedSignal(
                                  uid: uid,
                                  signalId: signal.id,
                                );
                                if (context.mounted) {
                                  AppToast.info(context, 'Removed from saved');
                                }
                              } else {
                                await repo.saveSignal(
                                  uid: uid,
                                  signalId: signal.id,
                                );
                                if (context.mounted) {
                                  AppToast.success(context, 'Saved signal');
                                }
                              }
                            } catch (error) {
                              if (context.mounted) {
                                AppToast.error(context, 'Unable to save signal');
                              }
                            }
                          },
                        );
                      },
                    ),
                  _Pill(
                    label: statusLabel,
                    color: statusColor,
                    dense: true,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: tokens.border),
                ),
                child: Row(
                  children: [
                    Icon(AppIcons.lock, color: tokens.mutedText),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Upgrade to view full entry, SL, TP, and reason.',
                        style: textTheme.bodySmall?.copyWith(
                          color: tokens.mutedText,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const PremiumPaywallScreen(
                              sourceScreen: 'SignalCard',
                            ),
                          ),
                        );
                      },
                      child: const Text('Upgrade'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Session: $sessionLabel',
                    style: textTheme.bodySmall?.copyWith(
                      color: tokens.mutedText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Expires at: $dateText',
                    style: textTheme.bodySmall?.copyWith(
                      color: tokens.mutedText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    expiresIn,
                    style: textTheme.bodySmall?.copyWith(
                      color: tokens.mutedText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingPremiumCard extends StatelessWidget {
  const _LoadingPremiumCard({
    required this.signal,
    required this.onTap,
    required this.sessionLabel,
    required this.dateText,
    required this.expiresIn,
    required this.directionColor,
    required this.statusLabel,
    required this.statusColor,
  });

  final Signal signal;
  final VoidCallback onTap;
  final String sessionLabel;
  final String dateText;
  final String expiresIn;
  final Color directionColor;
  final String statusLabel;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          signal.pair,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        _Pill(label: signal.direction, color: directionColor),
                        _Pill(
                          label: 'Premium Signal',
                          color: Theme.of(context).colorScheme.primary,
                          dense: true,
                        ),
                      ],
                    ),
                  ),
                  _Pill(label: statusLabel, color: statusColor, dense: true),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Loading premium details...',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: tokens.mutedText,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Session: $sessionLabel',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: tokens.mutedText,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Expires at: $dateText',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: tokens.mutedText,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    expiresIn,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: tokens.mutedText,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ],
          ),
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
