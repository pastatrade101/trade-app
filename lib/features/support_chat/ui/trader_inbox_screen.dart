import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../app/providers.dart';
import '../../../core/models/app_user.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/app_section_card.dart';
import '../data/support_chat_repo.dart';
import 'trader_chat_screen.dart';

final _supportThreadsProvider = StreamProvider<List<SupportThread>>((ref) {
  return ref.watch(supportChatRepositoryProvider).watchThreads(limit: 200);
});

final _supportUsersProvider = StreamProvider<List<AppUser>>((ref) {
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SupportThread> _filterThreads(
    List<SupportThread> items,
    Map<String, AppUser> userMap,
  ) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return items;
    }
    return items.where((thread) {
      final user = userMap[thread.uid];
      final name = (user?.displayName ?? '').toLowerCase();
      final message = thread.lastMessage.toLowerCase();
      return name.contains(query) || message.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final threads = ref.watch(_supportThreadsProvider);
    final users = ref.watch(_supportUsersProvider);
    final tokens = AppThemeTokens.of(context);

    final userMap = {
      for (final user in users.valueOrNull ?? const <AppUser>[])
        user.uid: user,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Support Inbox')),
      body: threads.when(
        data: (items) {
          final filtered = _filterThreads(items, userMap);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppSectionCard(
                useShadow: true,
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Support Inbox',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) =>
                            setState(() => _query = value),
                        decoration: InputDecoration(
                          hintText: 'Search conversations...',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: tokens.surfaceAlt,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: tokens.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: tokens.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Divider(
                      height: 1,
                      color: Theme.of(context).dividerColor.withOpacity(0.6),
                    ),
                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'No support threads yet.',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: tokens.mutedText),
                        ),
                      )
                    else
                      ListTileTheme(
                        data: const ListTileThemeData(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          minLeadingWidth: 0,
                          horizontalTitleGap: 12,
                        ),
                        child: ListView.separated(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filtered.length,
                          separatorBuilder: (context, _) => Padding(
                            padding: const EdgeInsets.only(left: 72),
                            child: Divider(
                              height: 1,
                              thickness: 1,
                              color:
                                  Theme.of(context).dividerColor.withOpacity(0.6),
                            ),
                          ),
                          itemBuilder: (context, index) {
                            final thread = filtered[index];
                            final user = userMap[thread.uid];
                            return _SupportThreadTile(
                              thread: thread,
                              user: user,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => TraderChatScreen(
                                      threadUid: thread.uid,
                                      member: user,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            'Failed to load support inbox.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: tokens.mutedText),
          ),
        ),
      ),
    );
  }
}

class _SupportThreadTile extends StatelessWidget {
  const _SupportThreadTile({
    required this.thread,
    required this.user,
    required this.onTap,
  });

  final SupportThread thread;
  final AppUser? user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final name = (user?.displayName ?? '').trim().isNotEmpty
        ? user!.displayName
        : 'Member';
    final subtitle = thread.lastMessage.isNotEmpty
        ? thread.lastMessage
        : 'New conversation';
    final timeLabel = thread.lastMessageAt != null
        ? formatTanzaniaDateTime(thread.lastMessageAt!, pattern: 'MMM d, HH:mm')
        : '—';
    return ListTile(
      onTap: onTap,
      leading: _Avatar(
        imageUrl: user?.avatarUrl ?? '',
        label: name,
        showStatus: thread.lastSender == 'member',
      ),
      title: Text(
        name,
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
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            timeLabel,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: tokens.mutedText),
          ),
          if (thread.unreadForTrader > 0) ...[
            const SizedBox(height: 6),
            _UnreadBadge(count: thread.unreadForTrader),
          ],
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.imageUrl,
    required this.label,
    required this.showStatus,
  });

  final String imageUrl;
  final String label;
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    final trimmed = label.trim();
    final initials = trimmed.isNotEmpty ? trimmed.substring(0, 1) : 'M';
    final colorScheme = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
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
        ),
        if (showStatus)
          Positioned(
            bottom: -1,
            right: -1,
            child: Container(
              height: 12,
              width: 12,
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
