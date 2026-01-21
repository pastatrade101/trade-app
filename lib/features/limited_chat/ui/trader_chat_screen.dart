import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../app/providers.dart';
import '../../../core/models/app_user.dart';
import '../../../core/utils/time_format.dart';
import '../data/chat_repository.dart';
import '../models/chat_conversation.dart';
import '../models/chat_message.dart';
import 'widgets/chat_composer.dart';
import 'widgets/chat_message_bubble.dart';

class TraderChatScreen extends ConsumerStatefulWidget {
  const TraderChatScreen({
    super.key,
    required this.conversation,
    required this.member,
  });

  final ChatConversation conversation;
  final AppUser? member;

  @override
  ConsumerState<TraderChatScreen> createState() => _TraderChatScreenState();
}

class _TraderChatScreenState extends ConsumerState<TraderChatScreen> {
  static const int _maxCharsPerMessage = 300;
  bool _sending = false;

  Future<void> _sendMessage(String text) async {
    if (_sending) {
      return;
    }
    setState(() => _sending = true);
    try {
      await ref.read(chatRepositoryProvider).sendTraderMessage(
            memberUid: widget.conversation.memberUid,
            text: text,
          );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final traderUid = ref.watch(authStateProvider).value?.uid ?? '';
    final memberName = (widget.member?.displayName ?? '').trim().isNotEmpty
        ? widget.member!.displayName
        : 'Member';

    return Scaffold(
      appBar: AppBar(title: Text(memberName)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: ref.read(chatRepositoryProvider).watchMessages(
                    conversationId: widget.conversation.id,
                  ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data ?? const <ChatMessage>[];
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'No messages yet.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: tokens.mutedText),
                    ),
                  );
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMine = message.senderUid == traderUid;
                    final timeLabel = message.createdAt != null
                        ? formatTanzaniaDateTime(
                            message.createdAt!,
                            pattern: 'HH:mm',
                          )
                        : '—';
                    return ChatMessageBubble(
                      message: message.text,
                      isMine: isMine,
                      timeLabel: timeLabel,
                      status: message.status,
                    );
                  },
                );
              },
            ),
          ),
          ChatComposer(
            enabled: !_sending,
            maxLength: _maxCharsPerMessage,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}
