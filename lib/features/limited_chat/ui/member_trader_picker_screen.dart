import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../app/providers.dart';
import '../../../core/models/app_user.dart';
import '../../../core/utils/role_helpers.dart';
import 'member_chat_screen.dart';

final _supportTradersProvider = StreamProvider<List<AppUser>>((ref) {
  return ref.watch(userRepositoryProvider).watchSupportTraders(limit: 200);
});

class MemberTraderPickerScreen extends ConsumerWidget {
  const MemberTraderPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final traders = ref.watch(_supportTradersProvider);
    final tokens = AppThemeTokens.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Choose a trader')),
      body: traders.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Text(
                'No traders available yet.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: tokens.mutedText),
              ),
            );
          }
          return ListTileTheme(
            data: const ListTileThemeData(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minLeadingWidth: 0,
              horizontalTitleGap: 12,
            ),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 16),
              itemCount: items.length,
              separatorBuilder: (context, _) => Padding(
                padding: const EdgeInsets.only(left: 72),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: Theme.of(context).dividerColor.withOpacity(0.6),
                ),
              ),
              itemBuilder: (context, index) {
                final trader = items[index];
                return _TraderTile(
                  trader: trader,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MemberChatScreen(
                          traderUid: trader.uid,
                          traderName: _displayName(trader),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            'Unable to load traders.',
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

class _TraderTile extends StatelessWidget {
  const _TraderTile({
    required this.trader,
    required this.onTap,
  });

  final AppUser trader;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final name = _displayName(trader);
    final roleText = roleLabel(trader.role);
    return ListTile(
      onTap: onTap,
      leading: _Avatar(
        imageUrl: trader.avatarUrl,
        label: name,
      ),
      title: Text(
        name,
        style: Theme.of(context)
            .textTheme
            .bodyLarge
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        roleText,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: tokens.mutedText),
      ),
    );
  }
}

String _displayName(AppUser user) {
  final displayName = user.displayName.trim();
  if (displayName.isNotEmpty) {
    return displayName;
  }
  final username = user.username.trim();
  if (username.isNotEmpty) {
    return username;
  }
  return 'Trader';
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
    final initials = trimmed.isNotEmpty ? trimmed.substring(0, 1) : 'T';
    final colorScheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: 22,
      backgroundColor: colorScheme.primary.withOpacity(0.12),
      backgroundImage:
          imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
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
