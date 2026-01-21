import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../app/providers.dart';
import '../../../core/models/app_user.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/app_shimmer.dart';
import '../data/chat_repository.dart';
import '../models/chat_conversation.dart';
import 'trader_chat_screen.dart';

final _chatThreadsProvider = StreamProvider<List<ChatConversation>>((ref) {
  return ref.watch(chatRepositoryProvider).watchConversations(limit: 200);
});

final _chatUsersProvider = StreamProvider<List<AppUser>>((ref) {
  return ref.watch(userRepositoryProvider).watchUsers(limit: 500);
});

class TraderInboxScreen extends ConsumerStatefulWidget {
  const TraderInboxScreen({super.key});

  @override
  ConsumerState<TraderInboxScreen> createState() => _TraderInboxScreenState();
}

class _TraderInboxScreenState extends ConsumerState<TraderInboxScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  bool _searching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ChatConversation> _filterThreads(
    List<ChatConversation> items,
    Map<String, AppUser> userMap,
  ) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return items;
    }
    return items.where((thread) {
      final user = userMap[thread.memberUid];
      final name = (user?.displayName ?? '').toLowerCase();
      final message = thread.lastMessage.toLowerCase();
      return name.contains(query) || message.contains(query);
    }).toList();
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _query = '';
        _searchController.clear();
      }
    });
  }

  Widget _buildThreadList({
    required List<ChatConversation> items,
    required Map<String, AppUser> userMap,
  }) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No conversations yet.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppThemeTokens.of(context).mutedText),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListTileTheme(
      data: const ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        minLeadingWidth: 0,
        horizontalTitleGap: 12,
      ),
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: items.length,
        separatorBuilder: (context, _) => Divider(
          height: 1,
          thickness: 1,
          color: Theme.of(context).dividerColor.withOpacity(0.35),
        ),
        itemBuilder: (context, index) {
          final thread = items[index];
          final member = userMap[thread.memberUid];
          final duration = Duration(
            milliseconds: 180 + (index.clamp(0, 8) * 30),
          );
          return TweenAnimationBuilder<double>(
            key: ValueKey(thread.id),
            tween: Tween(begin: 0, end: 1),
            duration: duration,
            curve: Curves.easeOut,
            builder: (context, value, child) {
              final translateY = (1 - value) * 10;
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, translateY),
                  child: child,
                ),
              );
            },
            child: _ChatThreadTile(
              conversation: thread,
              member: member,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TraderChatScreen(
                      conversation: thread,
                      member: member,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final threads = ref.watch(_chatThreadsProvider);
    final users = ref.watch(_chatUsersProvider);

    final userMap = {
      for (final user in users.valueOrNull ?? const <AppUser>[])
        user.uid: user,
    };

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: _searching
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: const InputDecoration(
                    hintText: 'Search conversations...',
                    border: InputBorder.none,
                  ),
                )
              : const Text('Support Inbox'),
          actions: [
            IconButton(
              icon: Icon(_searching ? Icons.close : Icons.search),
              onPressed: _toggleSearch,
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'New'),
              Tab(text: 'Read'),
            ],
          ),
        ),
        body: threads.when(
          data: (items) {
            final filtered = _filterThreads(items, userMap);
            final unread = filtered
                .where((thread) => thread.lastSender == 'member')
                .toList();
            final read = filtered
                .where((thread) => thread.lastSender != 'member')
                .toList();
            return TabBarView(
              children: [
                _buildThreadList(items: unread, userMap: userMap),
                _buildThreadList(items: read, userMap: userMap),
              ],
            );
          },
        loading: () => const _InboxShimmer(),
          error: (error, _) => Center(
            child: Text(
              'Failed to load support inbox.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppThemeTokens.of(context).mutedText),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatThreadTile extends StatelessWidget {
  const _ChatThreadTile({
    required this.conversation,
    required this.member,
    required this.onTap,
  });

  final ChatConversation conversation;
  final AppUser? member;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final displayName = (member?.displayName ?? '').trim().isNotEmpty
        ? member!.displayName
        : 'Member';
    final subtitle = conversation.lastMessage.isNotEmpty
        ? conversation.lastMessage
        : 'New conversation';
    final timeLabel = conversation.updatedAt != null
        ? formatTanzaniaDateTime(conversation.updatedAt!, pattern: 'MMM d, HH:mm')
        : '—';
    return ListTile(
      onTap: onTap,
      leading: _Avatar(
        imageUrl: member?.avatarUrl ?? '',
        label: displayName,
      ),
      title: Text(
        displayName,
        style: Theme.of(context)
            .textTheme
            .bodyLarge
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: tokens.mutedText),
      ),
      trailing: Text(
        timeLabel,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: tokens.mutedText),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.imageUrl,
    required this.label,
  });

  final String imageUrl;
  final String label;

  @override
  Widget build(BuildContext context) {
    final trimmed = label.trim();
    final initials = trimmed.isNotEmpty ? trimmed.substring(0, 1) : 'M';
    final colorScheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: 22,
      backgroundColor: colorScheme.primary.withOpacity(0.12),
      backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
      child: imageUrl.isNotEmpty
          ? null
          : Text(
              initials.toUpperCase(),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
    );
  }
}

class _InboxShimmer extends StatelessWidget {
  const _InboxShimmer();

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        thickness: 1,
        color: Theme.of(context).dividerColor.withOpacity(0.35),
      ),
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              AppShimmer(
                child: Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: tokens.surfaceAlt,
                    shape: BoxShape.circle,
                    border: Border.all(color: tokens.border),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppShimmerBox(
                      height: 14,
                      width: 140,
                      radius: 8,
                      margin: const EdgeInsets.only(bottom: 8),
                    ),
                    AppShimmerBox(
                      height: 12,
                      width: 200,
                      radius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              AppShimmerBox(height: 10, width: 48, radius: 6),
            ],
          ),
        );
      },
    );
  }
}
