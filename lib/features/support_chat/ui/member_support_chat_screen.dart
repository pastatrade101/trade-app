import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/app_theme.dart';
import '../../../app/providers.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/app_section_card.dart';
import '../data/support_chat_repo.dart';
import 'widgets/chat_guidelines_banner.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/message_input.dart';
import '../../premium/presentation/paywall_router.dart';
import 'package:stock_investment_flutter/app/app_icons.dart';

final _supportSettingsProvider = StreamProvider<SupportSettings>((ref) {
  return ref.watch(supportChatRepositoryProvider).watchSupportSettings();
});

final _supportThreadProvider =
    StreamProvider.family<SupportThread?, String>((ref, uid) {
  return ref.watch(supportChatRepositoryProvider).watchThread(uid);
});

final _supportMessagesProvider =
    StreamProvider.family<SupportMessagePage, String>((ref, uid) {
  return ref.watch(supportChatRepositoryProvider).watchLatestMessages(uid);
});

class MemberSupportChatScreen extends ConsumerStatefulWidget {
  const MemberSupportChatScreen({super.key, required this.uid});

  final String uid;

  @override
  ConsumerState<MemberSupportChatScreen> createState() =>
      _MemberSupportChatScreenState();
}

class _MemberSupportChatScreenState
    extends ConsumerState<MemberSupportChatScreen> {
  static const _guidelinesPrefKey = 'support_chat_guidelines_dismissed';
  static const _pageSize = 30;

  bool _showGuidelines = false;
  bool _prefsLoaded = false;
  bool _offlineNoticeShown = false;
  bool _loadingOlder = false;
  bool _hasMore = true;
  QueryDocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  final List<SupportMessage> _olderMessages = [];

  @override
  void initState() {
    super.initState();
    _loadGuidelinesFlag();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_markRead());
    });
  }

  Future<void> _loadGuidelinesFlag() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool(_guidelinesPrefKey) ?? false;
    if (!mounted) {
      return;
    }
    setState(() {
      _showGuidelines = !dismissed;
      _prefsLoaded = true;
    });
  }

  Future<void> _dismissGuidelines() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_guidelinesPrefKey, true);
    if (!mounted) {
      return;
    }
    setState(() => _showGuidelines = false);
  }

  Future<void> _markRead() async {
    await ref.read(supportChatRepositoryProvider).markMemberRead(widget.uid);
  }

  Future<void> _loadOlderMessages() async {
    if (_loadingOlder || _lastDoc == null || !_hasMore) {
      return;
    }
    setState(() => _loadingOlder = true);
    final page = await ref
        .read(supportChatRepositoryProvider)
        .fetchOlderMessages(uid: widget.uid, startAfter: _lastDoc!);
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

  void _handleSend({
    required String text,
    required bool isOnline,
  }) {
    ref.read(supportChatRepositoryProvider).sendMemberMessage(
          uid: widget.uid,
          text: text,
        );
    if (!isOnline && !_offlineNoticeShown) {
      _offlineNoticeShown = true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Support is offline. You’ll get a reply during office hours.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final membership = ref.watch(userMembershipProvider).value;
    final settings = ref.watch(_supportSettingsProvider);
    final thread = ref.watch(_supportThreadProvider(widget.uid));
    final messages = ref.watch(_supportMessagesProvider(widget.uid));
    final tokens = AppThemeTokens.of(context);

    final isPremiumActive =
        ref.read(membershipServiceProvider).isPremiumActive(membership);
    final settingsValue = settings.valueOrNull ?? SupportSettings.fromJson(null);
    final nowTz = _tzNow();
    final isOnline = settingsValue.isWithinOfficeHours(nowTz);
    final premiumRequired = settingsValue.premiumOnly && !isPremiumActive;
    final isBlocked = thread.valueOrNull?.isBlocked ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat with Mchambuzi Kai'),
        actions: [
          _StatusChip(isOnline: isOnline),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          if (_prefsLoaded && _showGuidelines)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: ChatGuidelinesBanner(onDismiss: _dismissGuidelines),
            ),
          if (premiumRequired)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _PremiumGateCard(
                onUpgrade: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PaywallRouter(
                        sourceScreen: 'SupportChat',
                      ),
                    ),
                  );
                },
              ),
            ),
          if (isBlocked)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: AppSectionCard(
                child: Text(
                  'You can’t message right now.',
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
                    final isMine = message.senderUid == widget.uid;
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
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
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
            enabled: !premiumRequired && !isBlocked,
            hintText: premiumRequired
                ? 'Upgrade to chat'
                : (isBlocked ? 'Messaging disabled' : 'Type a message'),
            onSend: (text) => _handleSend(text: text, isOnline: isOnline),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.isOnline});

  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final color = isOnline ? const Color(0xFF10B981) : const Color(0xFFF97316);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(AppIcons.flash_on, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            isOnline ? 'Online' : 'Offline',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _PremiumGateCard extends StatelessWidget {
  const _PremiumGateCard({required this.onUpgrade});

  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return AppSectionCard(
      child: Row(
        children: [
          const Icon(AppIcons.lock, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Upgrade to Premium to chat with Mchambuzi Kai',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: tokens.mutedText),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: onUpgrade, child: const Text('Upgrade')),
        ],
      ),
    );
  }
}

DateTime _tzNow() {
  return DateTime.now().toUtc().add(const Duration(hours: 3));
}
