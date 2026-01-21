import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../app/providers.dart';
import '../../../core/models/app_user.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/app_section_card.dart';
import '../data/support_chat_repo.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/message_input.dart';

final _traderThreadProvider =
    StreamProvider.family<SupportThread?, String>((ref, uid) {
  return ref.watch(supportChatRepositoryProvider).watchThread(uid);
});

final _traderMessagesProvider =
    StreamProvider.family<SupportMessagePage, String>((ref, uid) {
  return ref.watch(supportChatRepositoryProvider).watchLatestMessages(uid);
});

class TraderChatScreen extends ConsumerStatefulWidget {
  const TraderChatScreen({
    super.key,
    required this.threadUid,
    this.member,
  });

  final String threadUid;
  final AppUser? member;

  @override
  ConsumerState<TraderChatScreen> createState() => _TraderChatScreenState();
}

class _TraderChatScreenState extends ConsumerState<TraderChatScreen> {
  static const _pageSize = 30;
  bool _loadingOlder = false;
  bool _hasMore = true;
  QueryDocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  final List<SupportMessage> _olderMessages = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_markRead());
    });
  }

  Future<void> _markRead() async {
    await ref.read(supportChatRepositoryProvider).markTraderRead(
          widget.threadUid,
        );
  }

  Future<void> _loadOlderMessages() async {
    if (_loadingOlder || _lastDoc == null || !_hasMore) {
      return;
    }
    setState(() => _loadingOlder = true);
    final page = await ref
        .read(supportChatRepositoryProvider)
        .fetchOlderMessages(uid: widget.threadUid, startAfter: _lastDoc!);
    if (!mounted) {
      return;
    }
    setState(() {
      _olderMessages.addAll(page.messages);
      _lastDoc = page.lastDoc;
      _hasMore = page.messages.isNotEmpty;
      _loadingOlder = false;
    });
  }

  Future<void> _toggleBlocked(bool isBlocked) async {
    await ref.read(supportChatRepositoryProvider).setBlocked(
          widget.threadUid,
          isBlocked,
        );
  }

  @override
  Widget build(BuildContext context) {
    final thread = ref.watch(_traderThreadProvider(widget.threadUid));
    final messages = ref.watch(_traderMessagesProvider(widget.threadUid));
    final tokens = AppThemeTokens.of(context);
    final traderUid = ref.watch(authStateProvider).value?.uid ?? '';

    final displayName = (widget.member?.displayName ?? '').trim().isNotEmpty
        ? widget.member!.displayName
        : 'Member';
    final isBlocked = thread.valueOrNull?.isBlocked ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(displayName),
        actions: [
          if (thread.valueOrNull != null)
            TextButton(
              onPressed: () => _toggleBlocked(!isBlocked),
              child: Text(isBlocked ? 'Unblock' : 'Block'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          if (isBlocked)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: AppSectionCard(
                child: Text(
                  'This member is blocked from messaging.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: tokens.mutedText),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: messages.when(
              data: (page) {
                _lastDoc ??= page.lastDoc;
                if (_olderMessages.isEmpty) {
                  _hasMore = page.messages.length >= _pageSize;
                }
                final allMessages = [
                  ...page.messages,
                  ..._olderMessages,
                ];
                if (allMessages.isEmpty) {
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
                  itemCount: allMessages.length + (_hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (_hasMore && index == allMessages.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextButton(
                          onPressed: _loadingOlder ? null : _loadOlderMessages,
                          child: _loadingOlder
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Load older'),
                        ),
                      );
                    }
                    final message = allMessages[index];
                    final isMine = message.senderUid == traderUid;
                    final timeLabel = message.createdAt != null
                        ? formatTanzaniaDateTime(
                            message.createdAt!,
                            pattern: 'HH:mm',
                          )
                        : '—';
                    return ChatBubble(
                      message: message.text,
                      isMine: isMine,
                      timeLabel: timeLabel,
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text(
                  'Failed to load chat.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: tokens.mutedText),
                ),
              ),
            ),
          ),
          MessageInput(
            enabled: !isBlocked,
            hintText: isBlocked ? 'Messaging disabled' : 'Reply to member',
            onSend: (text) {
              ref.read(supportChatRepositoryProvider).sendTraderMessage(
                    threadUid: widget.threadUid,
                    senderUid: traderUid,
                    text: text,
                  );
            },
          ),
        ],
      ),
    );
  }
}
