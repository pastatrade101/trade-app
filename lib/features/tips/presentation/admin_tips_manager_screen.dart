import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../app/providers.dart';
import '../../../core/models/tip.dart';
import '../../../core/repositories/tip_repository.dart';
import '../../../core/widgets/app_section_card.dart';
import 'create_tip_screen.dart';
import 'tip_detail_screen.dart';
import 'tip_widgets.dart';

class AdminTipsManagerScreen extends ConsumerStatefulWidget {
  const AdminTipsManagerScreen({super.key});

  @override
  ConsumerState<AdminTipsManagerScreen> createState() =>
      _AdminTipsManagerScreenState();
}

class _AdminTipsManagerScreenState extends ConsumerState<AdminTipsManagerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    final isActiveTrader = user?.role == 'trader' && user?.traderStatus == 'active';
    if (user == null || !isActiveTrader) {
      return const Scaffold(
        body: Center(child: Text('Trader access required.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tips manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TipCreateScreen()),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Drafts'),
            Tab(text: 'Published'),
            Tab(text: 'Archived'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTab(context, uid: user.uid, status: 'draft'),
          _buildTab(context, uid: user.uid, status: 'published'),
          _buildTab(context, uid: user.uid, status: 'archived'),
        ],
      ),
    );
  }

  Widget _buildTab(BuildContext context,
      {required String uid, required String status}) {
    return TipsPagedList(
      loader: (startAfter) => ref
          .read(tipRepositoryProvider)
          .fetchTipsByStatusForAuthor(
            status: status,
            uid: uid,
            startAfter: startAfter,
          ),
      itemBuilder: (tip) => _AdminTipCard(
        tip: tip,
        onTap: () => _openTipDetail(context, tip),
        onAction: (action) => _handleAction(context, tip, action),
      ),
      emptyTitle: 'No ${status} tips',
      emptySubtitle: 'Tips will appear here once created.',
    );
  }

  void _openTipDetail(BuildContext context, TraderTip tip) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TipDetailScreen(tipId: tip.id, initialTip: tip),
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    TraderTip tip,
    _AdminTipAction action,
  ) async {
    final repo = ref.read(tipRepositoryProvider);
    try {
      switch (action) {
        case _AdminTipAction.publish:
          await repo.updateTip(tip.id, {'status': 'published'});
          break;
        case _AdminTipAction.archive:
          await repo.updateTip(tip.id, {'status': 'archived'});
          break;
        case _AdminTipAction.unarchive:
          await repo.updateTip(tip.id, {'status': 'published'});
          break;
        case _AdminTipAction.feature:
          await repo.updateTip(tip.id, {'isFeatured': true});
          break;
        case _AdminTipAction.unfeature:
          await repo.updateTip(tip.id, {'isFeatured': false});
          break;
        case _AdminTipAction.delete:
          final confirmed = await _confirmDelete(context, tip.title);
          if (!confirmed) {
            return;
          }
          await repo.deleteTip(tip);
          break;
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action failed: $error')),
        );
      }
    }
  }

  Future<bool> _confirmDelete(BuildContext context, String title) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete tip?'),
        content: Text('Delete "$title" and its media?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

enum _AdminTipAction {
  publish,
  archive,
  unarchive,
  feature,
  unfeature,
  delete,
}

class _AdminTipCard extends StatelessWidget {
  const _AdminTipCard({
    required this.tip,
    required this.onTap,
    required this.onAction,
  });

  final TraderTip tip;
  final VoidCallback onTap;
  final ValueChanged<_AdminTipAction> onAction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = AppThemeTokens.of(context).mutedText;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: AppSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _StatusChip(label: tip.status),
                    const Spacer(),
                    PopupMenuButton<_AdminTipAction>(
                      onSelected: onAction,
                      itemBuilder: (_) => _buildActions(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  tip.title,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  tip.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(color: muted),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text(tip.type)),
                    ...tip.tags.map((tag) => Chip(label: Text(tag))),
                    if (tip.isFeatured) const Chip(label: Text('Featured')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<PopupMenuEntry<_AdminTipAction>> _buildActions() {
    final actions = <PopupMenuEntry<_AdminTipAction>>[];
    if (tip.status == 'draft') {
      actions.add(const PopupMenuItem(
        value: _AdminTipAction.publish,
        child: Text('Publish'),
      ));
    }
    if (tip.status == 'published') {
      actions.add(const PopupMenuItem(
        value: _AdminTipAction.archive,
        child: Text('Archive'),
      ));
    }
    if (tip.status == 'archived') {
      actions.add(const PopupMenuItem(
        value: _AdminTipAction.unarchive,
        child: Text('Unarchive'),
      ));
    }
    if (tip.isFeatured) {
      actions.add(const PopupMenuItem(
        value: _AdminTipAction.unfeature,
        child: Text('Unfeature'),
      ));
    } else {
      actions.add(const PopupMenuItem(
        value: _AdminTipAction.feature,
        child: Text('Feature'),
      ));
    }
    actions.add(const PopupMenuDivider());
    actions.add(const PopupMenuItem(
      value: _AdminTipAction.delete,
      child: Text('Delete'),
    ));
    return actions;
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    Color background;
    Color textColor;
    switch (label) {
      case 'published':
        background = colorScheme.secondary.withOpacity(0.15);
        textColor = colorScheme.secondary;
        break;
      case 'archived':
        background = Colors.grey.withOpacity(0.2);
        textColor = Colors.grey.shade700;
        break;
      default:
        background = colorScheme.primary.withOpacity(0.12);
        textColor = colorScheme.primary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
