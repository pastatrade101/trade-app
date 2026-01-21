import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../app/providers.dart';
import '../../../core/services/membership_service.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/app_section_card.dart';
import '../../../services/analytics_service.dart';
import '../data/chat_repository.dart';
import '../models/chat_message.dart';
import '../models/chat_quota.dart';
import 'widgets/chat_composer.dart';
import 'widgets/chat_message_bubble.dart';
import 'widgets/quota_indicator.dart';
import '../../premium/presentation/paywall_router.dart';
import 'package:stock_investment_flutter/app/app_icons.dart';

class MemberChatScreen extends ConsumerStatefulWidget {
  const MemberChatScreen({
    super.key,
    required this.traderUid,
    this.traderName,
  });

  final String traderUid;
  final String? traderName;

  @override
  ConsumerState<MemberChatScreen> createState() => _MemberChatScreenState();
}

class _MemberChatScreenState extends ConsumerState<MemberChatScreen> {
  static const int _maxCharsPerMessage = 300;

  late final String _traderUid;
  final List<ChatMessage> _localMessages = [];
  final ScrollController _scrollController = ScrollController();
  ChatQuotaStatus? _quota;
  bool _loadingQuota = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _traderUid = widget.traderUid;
    AnalyticsService.instance
        .logEvent('chat_open', params: {'traderUid': widget.traderUid});
    _refreshQuota();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshQuota() async {
    final traderUid = _traderUid;
    if (traderUid == null || traderUid.isEmpty) {
      setState(() => _loadingQuota = false);
      return;
    }
    final membership = ref.read(userMembershipProvider).value;
    final isPremium = ref
        .read(membershipServiceProvider)
        .isPremiumActive(membership);
    if (!isPremium) {
      setState(() => _loadingQuota = false);
      return;
    }
    setState(() => _loadingQuota = true);
    try {
      final quota =
          await ref.read(chatRepositoryProvider).fetchQuota(traderUid: traderUid);
      if (!mounted) {
        return;
      }
      setState(() {
        _quota = quota;
        _errorMessage = null;
      });
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.message ?? 'Unable to load chat quota.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Unable to load chat quota.');
      }
    } finally {
      if (mounted) {
        setState(() => _loadingQuota = false);
      }
    }
  }

  Future<void> _sendMessage(String text) async {
    final traderUid = _traderUid;
    final user = ref.read(currentUserProvider).value;
    if (traderUid.isEmpty || user == null) {
      return;
    }

    final clientMessageId = _newClientMessageId(user.uid);
    final optimistic = ChatMessage.optimistic(
      clientMessageId: clientMessageId,
      senderUid: user.uid,
      senderRole: 'member',
      text: text,
      charCount: text.length,
    );

    setState(() {
      _localMessages.insert(0, optimistic);
      _errorMessage = null;
    });
    _scrollToLatest();

    await _sendMessageToServer(
      traderUid: traderUid,
      text: text,
      clientMessageId: clientMessageId,
    );
  }

  Future<void> _sendMessageToServer({
    required String traderUid,
    required String text,
    required String clientMessageId,
  }) async {
    try {
      final quota = await ref.read(chatRepositoryProvider).sendMessage(
            traderUid: traderUid,
            text: text,
            clientMessageId: clientMessageId,
          );
      if (!mounted) {
        return;
      }
      _updateLocalStatus(clientMessageId, MessageStatus.sent);
      setState(() => _quota = quota);
      AnalyticsService.instance.logEvent(
        'chat_send',
        params: {
          'traderUid': traderUid,
          'charCount': text.length,
        },
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) {
        return;
      }
      _updateLocalStatus(clientMessageId, MessageStatus.failed);
      if (error.code == 'resource-exhausted') {
        final endsAt =
            error.details is Map ? error.details['windowEndsAt'] : null;
        final remainingMessages =
            error.details is Map ? error.details['remainingMessages'] : null;
        final remainingChars =
            error.details is Map ? error.details['remainingChars'] : null;
        final resetLabel = endsAt != null
            ? formatTanzaniaDateTime(
                DateTime.fromMillisecondsSinceEpoch(endsAt),
                pattern: 'MMM d, HH:mm',
              )
            : 'soon';
        setState(() {
          _errorMessage =
              'Chat limit reached. Try again after $resetLabel. '
              'Remaining: ${remainingMessages ?? 0} msgs, ${remainingChars ?? 0} chars.';
        });
      } else {
        setState(() => _errorMessage = error.message ?? 'Failed to send message.');
      }
    } catch (_) {
      if (mounted) {
        _updateLocalStatus(clientMessageId, MessageStatus.failed);
        setState(() => _errorMessage = 'Failed to send message.');
      }
    }
  }

  void _updateLocalStatus(String clientMessageId, MessageStatus status) {
    final index = _localMessages.indexWhere(
      (message) => message.clientMessageId == clientMessageId,
    );
    if (index == -1) {
      return;
    }
    setState(() {
      _localMessages[index] = _localMessages[index].copyWith(status: status);
    });
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  String _newClientMessageId(String uid) {
    final randomSuffix = Random().nextInt(999999);
    return '${uid}_${DateTime.now().millisecondsSinceEpoch}_$randomSuffix';
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    final membership = ref.watch(userMembershipProvider).value;
    final isPremium = ref
        .read(membershipServiceProvider)
        .isPremiumActive(membership);
    final tokens = AppThemeTokens.of(context);
    final traderUid = _traderUid;
    final traderName = widget.traderName?.trim().isNotEmpty == true
        ? widget.traderName!.trim()
        : 'Mchambuzi Kai';

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (traderUid == null || traderUid.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chat with Mchambuzi Kai')),
        body: Center(
          child: Text(
            'Trader account is not configured yet.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: tokens.mutedText),
          ),
        ),
      );
    }

    final conversationId =
        ref.read(chatRepositoryProvider).conversationId(user.uid, traderUid);
    final canSend = isPremium &&
        (_quota == null ||
            (_quota!.remainingMessages > 0 && _quota!.remainingChars > 0));

    if (isPremium && _quota == null && !_loadingQuota) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _refreshQuota();
        }
      });
    }

    return Scaffold(
      appBar: AppBar(title: Text('Chat with $traderName')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                if (_loadingQuota)
                  const LinearProgressIndicator(minHeight: 2),
                if (!isPremium)
                  AppSectionCard(
                    child: Row(
                      children: [
                        const Icon(AppIcons.lock, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Upgrade to Premium to chat with Mchambuzi Kai.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: tokens.mutedText),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const PaywallRouter(
                                  sourceScreen: 'Chat',
                                ),
                              ),
                            );
                          },
                          child: const Text('Upgrade'),
                        ),
                      ],
                    ),
                  )
                else
                  QuotaIndicator(quota: _quota),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 8),
                  AppSectionCard(
                    child: Text(
                      _errorMessage!,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: tokens.mutedText),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: ref
                  .read(chatRepositoryProvider)
                  .watchMessages(conversationId: conversationId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final remoteMessages = snapshot.data ?? const <ChatMessage>[];
                final remoteClientIds = remoteMessages
                    .map((message) => message.clientMessageId)
                    .whereType<String>()
                    .toSet();
                if (_localMessages.isNotEmpty && remoteClientIds.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) {
                      return;
                    }
                    final before = _localMessages.length;
                    _localMessages.removeWhere((message) =>
                        message.clientMessageId != null &&
                        remoteClientIds.contains(message.clientMessageId));
                    if (before != _localMessages.length) {
                      setState(() {});
                    }
                  });
                }
                final localMessages = _localMessages
                    .where((message) =>
                        message.clientMessageId == null ||
                        !remoteClientIds.contains(message.clientMessageId))
                    .toList();
                final combinedMessages = <ChatMessage>[
                  ...remoteMessages,
                  ...localMessages,
                ]..sort((a, b) {
                    final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                    final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                    return bTime.compareTo(aTime);
                  });

                if (combinedMessages.isEmpty) {
                  return Center(
                    child: Text(
                      'Start a conversation.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: tokens.mutedText),
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: combinedMessages.length,
                  itemBuilder: (context, index) {
                    final message = combinedMessages[index];
                    final isMine = message.senderUid == user.uid;
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
                      onRetry: message.status == MessageStatus.failed && isMine
                          ? () {
                              final clientId = message.clientMessageId;
                              if (clientId == null) {
                                _sendMessage(message.text);
                                return;
                              }
                              if (remoteClientIds.contains(clientId)) {
                                _updateLocalStatus(clientId, MessageStatus.sent);
                                return;
                              }
                              _updateLocalStatus(clientId, MessageStatus.sending);
                              _sendMessageToServer(
                                traderUid: traderUid,
                                text: message.text,
                                clientMessageId: clientId,
                              );
                            }
                          : null,
                    );
                  },
                );
              },
            ),
          ),
          ChatComposer(
            enabled: canSend,
            maxLength: _maxCharsPerMessage,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}
