import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../core/widgets/app_section_card.dart';
import '../../models/chat_quota.dart';

class QuotaIndicator extends StatelessWidget {
  const QuotaIndicator({
    super.key,
    required this.quota,
  });

  final ChatQuotaStatus? quota;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    if (quota == null) {
      return const SizedBox.shrink();
    }
    final resetLabel = quota!.windowEndsAt != null
        ? formatTanzaniaDateTime(quota!.windowEndsAt!, pattern: 'MMM d, HH:mm')
        : '—';
    final remainingMessages = quota!.remainingMessages;
    final remainingChars = quota!.remainingChars;
    return AppSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.timer_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Chat quota',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              Text(
                'Resets $resetLabel',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: tokens.mutedText),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _QuotaStat(
                  label: 'Messages left',
                  value: '$remainingMessages',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuotaStat(
                  label: 'Chars left',
                  value: '$remainingChars',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuotaStat extends StatelessWidget {
  const _QuotaStat({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: tokens.mutedText),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
