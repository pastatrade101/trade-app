import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../app/app_icons.dart';
import '../../models/chat_message.dart';

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.timeLabel,
    this.status = MessageStatus.sent,
    this.onRetry,
  });

  final String message;
  final bool isMine;
  final String timeLabel;
  final MessageStatus status;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final bubbleColor = isMine
        ? Theme.of(context).colorScheme.primary
        : tokens.surfaceAlt;
    final textColor = isMine
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    const radius = Radius.circular(16);

    final timeStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: isMine ? Colors.white70 : tokens.mutedText,
        );

    Widget? statusChild;
    if (isMine) {
      switch (status) {
        case MessageStatus.sending:
          statusChild = Text(
            'Sending…',
            key: const ValueKey('sending'),
            style: timeStyle,
          );
          break;
        case MessageStatus.sent:
          statusChild = Icon(
            AppIcons.check,
            key: const ValueKey('sent'),
            size: 14,
            color: isMine ? Colors.white70 : tokens.mutedText,
          );
          break;
        case MessageStatus.failed:
          statusChild = GestureDetector(
            key: const ValueKey('failed'),
            onTap: onRetry,
            child: Text(
              'Failed · Tap to retry',
              style: timeStyle?.copyWith(
                color: isMine ? Colors.white : tokens.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
          break;
      }
    }

    final statusWidget = statusChild == null
        ? null
        : AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              );
            },
            child: statusChild,
          );

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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(timeLabel, style: timeStyle),
                  if (statusWidget != null) ...[
                    const SizedBox(width: 6),
                    statusWidget,
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
