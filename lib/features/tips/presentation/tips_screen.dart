import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/tip.dart';
import '../../../core/utils/role_helpers.dart';
import 'create_tip_screen.dart';
import 'tip_detail_screen.dart';
import '../tip_config.dart';
import 'tip_widgets.dart';
import 'package:stock_investment_flutter/app/app_icons.dart';

class TipsScreen extends StatelessWidget {
  const TipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TipsListScreen();
  }
}

class TipsListScreen extends ConsumerWidget {
  const TipsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    final isActiveTrader =
        isTrader(user?.role) && user?.traderStatus == 'active';
    final canCreate =
        isActiveTrader && (!requireVerifiedTrader || user?.isVerified == true);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Trader Tips'),
          actions: [
            if (canCreate)
              IconButton(
                icon: const Icon(AppIcons.add),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const TipCreateScreen(),
                    ),
                  );
                },
              ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Featured'),
              Tab(text: 'Latest'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            TipsPagedList(
              loader: (startAfter) =>
                  ref.read(tipRepositoryProvider).fetchFeaturedTips(
                        startAfter: startAfter,
                      ),
              itemBuilder: (tip) => TipCard(
                tip: tip,
                onTap: () => _openTipDetail(context, tip),
              ),
              emptyTitle: 'No featured tips yet',
              emptySubtitle: 'Featured insights appear here once published.',
              footer: const TipDisclaimer(),
            ),
            _LatestTipsTab(currentUser: user),
          ],
        ),
      ),
    );
  }

  void _openTipDetail(BuildContext context, TraderTip tip) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TipDetailScreen(tipId: tip.id, initialTip: tip),
      ),
    );
  }
}

class _LatestTipsTab extends ConsumerStatefulWidget {
  const _LatestTipsTab({required this.currentUser});

  final AppUser? currentUser;

  @override
  ConsumerState<_LatestTipsTab> createState() => _LatestTipsTabState();
}

class _LatestTipsTabState extends ConsumerState<_LatestTipsTab> {
  String _selectedType = 'All';

  @override
  Widget build(BuildContext context) {
    final types = ['All', ...tipTypes];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: DropdownButtonFormField<String>(
            value: _selectedType,
            decoration: const InputDecoration(labelText: 'Filter by type'),
            items: types
                .map((type) => DropdownMenuItem(
                      value: type,
                      child: Text(type),
                    ))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedType = value);
              }
            },
          ),
        ),
        Expanded(
          child: TipsPagedList(
            resetKey: _selectedType,
            loader: (startAfter) {
              final repo = ref.read(tipRepositoryProvider);
              if (_selectedType == 'All') {
                return repo.fetchPublishedTips(startAfter: startAfter);
              }
              return repo.fetchTypeTips(
                type: _selectedType,
                startAfter: startAfter,
              );
            },
            itemBuilder: (tip) => TipCard(
              tip: tip,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TipDetailScreen(
                      tipId: tip.id,
                      initialTip: tip,
                    ),
                  ),
                );
              },
            ),
            emptyTitle: 'No tips available',
            emptySubtitle: 'Published tips will appear here.',
            footer: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TipDisclaimer(),
            ),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          ),
        ),
      ],
    );
  }
}
