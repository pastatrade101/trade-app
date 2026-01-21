import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.timeLabel,
  });

  final String message;
  final bool isMine;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final bubbleColor = isMine
        ? Theme.of(context).colorScheme.primary
        : tokens.surfaceAlt;
    final textColor = isMine ? Colors.white : Theme.of(context).colorScheme.onSurface;
    final radius = Radius.circular(16);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: radius,
              topRight: radius,
              bottomLeft: isMine ? radius : const Radius.circular(4),
              bottomRight: isMine ? const Radius.circular(4) : radius,
            ),
          ),
          child: Column(
            crossAxisAlignment:
                isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: textColor,
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                timeLabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isMine ? Colors.white70 : tokens.mutedText,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
