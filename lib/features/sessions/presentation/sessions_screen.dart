import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../app/app_icons.dart';
import '../../../core/widgets/app_section_card.dart';
import '../../../core/utils/time_format.dart';
import '../data/sessions_service.dart';
import '../../../services/analytics_service.dart';

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  final SessionsService _service = SessionsService();
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final sessions = _service.buildSessions(now: _now);
    final overlap =
        SessionsService.isWeekend(_now) ? null : _nextOverlap(_now);

    return Scaffold(
      appBar: AppBar(title: const Text('Sessions')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (overlap != null) ...[
            _OverlapCard(overlap: overlap),
            const SizedBox(height: 16),
          ],
          Text(
            'Trading Sessions',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          for (final session in sessions) ...[
            _SessionCard(session: session),
            const SizedBox(height: 12),
          ],
          Text(
            'Times shown in Tanzania (Africa/Dar_es_Salaam).',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: tokens.mutedText),
          ),
        ],
      ),
    );
  }
}

class _OverlapInfo {
  const _OverlapInfo({
    required this.title,
    required this.subtitle,
    required this.countdownLabel,
  });

  final String title;
  final String subtitle;
  final String countdownLabel;
}

_OverlapInfo? _nextOverlap(DateTime now) {
  final defs = SessionsService.definitions;
  final windows = <_SessionWindow>[];

  for (final def in defs) {
    for (var offset = 0; offset <= 1; offset++) {
      final base = DateTime(now.year, now.month, now.day).add(
        Duration(days: offset),
      );
      final start = DateTime(
        base.year,
        base.month,
        base.day,
        def.openHour,
        def.openMinute,
      );
      var end = DateTime(
        base.year,
        base.month,
        base.day,
        def.closeHour,
        def.closeMinute,
      );
      if (!end.isAfter(start)) {
        end = end.add(const Duration(days: 1));
      }
      windows.add(
        _SessionWindow(
          key: def.key,
          name: def.name,
          start: start,
          end: end,
        ),
      );
    }
  }

  _OverlapCandidate? best;
  for (var i = 0; i < windows.length; i++) {
    for (var j = i + 1; j < windows.length; j++) {
      final a = windows[i];
      final b = windows[j];
      final start = a.start.isAfter(b.start) ? a.start : b.start;
      final end = a.end.isBefore(b.end) ? a.end : b.end;
      if (!end.isAfter(start)) {
        continue;
      }
      final overlapStart = start.isAfter(now) ? start : now;
      if (!end.isAfter(overlapStart)) {
        continue;
      }
      if (best == null || start.isBefore(best.start)) {
        best = _OverlapCandidate(
          start: start,
          end: end,
          a: a,
          b: b,
        );
      }
    }
  }

  if (best == null) {
    return null;
  }

  final isLive = now.isAfter(best.start) && now.isBefore(best.end);
  final label = isLive
      ? 'Ends in ${formatCountdown(best.end.difference(now))}'
      : 'Starts in ${formatCountdown(best.start.difference(now))}';

  return _OverlapInfo(
    title: 'Next Overlap',
    subtitle: '${best.a.name} & ${best.b.name}',
    countdownLabel: label,
  );
}

class _OverlapCard extends StatelessWidget {
  const _OverlapCard({required this.overlap});

  final _OverlapInfo overlap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.primary.withOpacity(0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            overlap.title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            overlap.subtitle,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            overlap.countdownLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                ),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session});

  final TradingSessionInfo session;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final status = session.status;
    final isOpen = status == TradingSessionStatus.open;
    final borderColor = isOpen
        ? tokens.success
        : (status == TradingSessionStatus.upcoming
            ? tokens.warning
            : tokens.border);
    final background = isOpen
        ? tokens.success.withOpacity(0.08)
        : Theme.of(context).colorScheme.surface;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: tokens.shadow,
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: colorScheme.primary.withOpacity(0.12),
                child: Icon(
                  AppIcons.public,
                  color: colorScheme.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Session',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: tokens.mutedText),
                    ),
                  ],
                ),
              ),
              _StatusPill(status: status),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _TimeBlock(
                  label: 'Opens',
                  time: session.formatTime(session.opensAt),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TimeBlock(
                  label: 'Closes',
                  time: session.formatTime(session.closesAt),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: tokens.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: tokens.border),
            ),
            child: Row(
              children: [
                Icon(
                  AppIcons.trending_up,
                  size: 16,
                  color: tokens.mutedText,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    session.countdownLabel(),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: tokens.mutedText),
                  ),
                ),
              ],
            ),
          ),
          if (isOpen) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  height: 8,
                  width: 8,
                  decoration: BoxDecoration(
                    color: tokens.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Live Trading',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: tokens.success),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TimeBlock extends StatelessWidget {
  const _TimeBlock({
    required this.label,
    required this.time,
  });

  final String label;
  final String time;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(AppIcons.access_time, size: 14, color: tokens.mutedText),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: tokens.mutedText),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          time,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final TradingSessionStatus status;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    late Color background;
    late Color foreground;
    late String label;
    switch (status) {
      case TradingSessionStatus.open:
        background = tokens.success.withOpacity(0.18);
        foreground = tokens.success;
        label = 'OPEN';
        break;
      case TradingSessionStatus.upcoming:
        background = tokens.warning.withOpacity(0.18);
        foreground = tokens.warning;
        label = 'CLOSED';
        break;
      case TradingSessionStatus.closed:
        background = colorScheme.onSurface.withOpacity(0.08);
        foreground = tokens.mutedText;
        label = 'CLOSED';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _SessionWindow {
  const _SessionWindow({
    required this.key,
    required this.name,
    required this.start,
    required this.end,
  });

  final String key;
  final String name;
  final DateTime start;
  final DateTime end;
}

class _OverlapCandidate {
  const _OverlapCandidate({
    required this.start,
    required this.end,
    required this.a,
    required this.b,
  });

  final DateTime start;
  final DateTime end;
  final _SessionWindow a;
  final _SessionWindow b;
}
