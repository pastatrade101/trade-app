import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';

class ChatGuidelinesBanner extends StatelessWidget {
  const ChatGuidelinesBanner({
    super.key,
    required this.onDismiss,
  });

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chat Guidelines',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Use this chat for signal clarification, session timing, and risk guidance.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: tokens.mutedText),
          ),
          const SizedBox(height: 4),
          Text(
            'No new signals requests, no account management, no guaranteed profits.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: tokens.mutedText),
          ),
          const SizedBox(height: 4),
          Text(
            'Trading involves risk. This is educational support only.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: tokens.mutedText),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onDismiss,
              child: const Text('Got it'),
            ),
          ),
        ],
      ),
    );
  }
}
