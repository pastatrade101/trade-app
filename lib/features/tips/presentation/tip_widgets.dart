import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/app_theme.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/tip.dart';
import '../../../core/repositories/tip_repository.dart';
import '../../../core/widgets/app_section_card.dart';

typedef TipsPageLoader = Future<TipPage> Function(
  DocumentSnapshot<Map<String, dynamic>>? startAfter,
);

typedef TipItemBuilder = Widget Function(TraderTip tip);

class TipsPagedList extends ConsumerStatefulWidget {
  const TipsPagedList({
    super.key,
    required this.loader,
    required this.itemBuilder,
    required this.emptyTitle,
    required this.emptySubtitle,
    this.header,
    this.footer,
    this.resetKey,
    this.padding,
  });

  final TipsPageLoader loader;
  final TipItemBuilder itemBuilder;
  final String emptyTitle;
  final String emptySubtitle;
  final Widget? header;
  final Widget? footer;
  final String? resetKey;
  final EdgeInsetsGeometry? padding;

  @override
  ConsumerState<TipsPagedList> createState() => _TipsPagedListState();
}

class _TipsPagedListState extends ConsumerState<TipsPagedList> {
  final ScrollController _scrollController = ScrollController();
  final List<TraderTip> _tips = [];
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool _isLoading = false;
  bool _hasMore = true;
  bool _initialLoad = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _loadMore();
  }

  @override
  void didUpdateWidget(covariant TipsPagedList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.resetKey != oldWidget.resetKey) {
      _resetAndLoad();
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 240) {
      _loadMore();
    }
  }

  Future<void> _resetAndLoad() async {
    setState(() {
      _tips.clear();
      _lastDoc = null;
      _hasMore = true;
      _initialLoad = true;
      _error = null;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) {
      return;
    }
    setState(() => _isLoading = true);
    try {
      final page = await widget.loader(_lastDoc);
      if (!mounted) {
        return;
      }
      setState(() {
        _tips.addAll(page.tips);
        _lastDoc = page.lastDoc;
        _hasMore = page.hasMore;
        _initialLoad = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _initialLoad = false;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = widget.padding ?? const EdgeInsets.all(16);
    if (_initialLoad && _tips.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _tips.isEmpty) {
      return _ErrorState(
        message: _error!,
        onRetry: _loadMore,
      );
    }
    if (_tips.isEmpty) {
      return _EmptyState(
        title: widget.emptyTitle,
        subtitle: widget.emptySubtitle,
      );
    }

    final headerCount = widget.header != null ? 1 : 0;
    final footerCount = widget.footer != null ? 1 : 0;
    final loadingCount = _isLoading && _tips.isNotEmpty ? 1 : 0;
    final totalCount = headerCount + _tips.length + loadingCount + footerCount;

    return ListView.builder(
      controller: _scrollController,
      padding: padding,
      itemCount: totalCount,
      itemBuilder: (context, index) {
        var currentIndex = index;
        if (widget.header != null) {
          if (currentIndex == 0) {
            return widget.header!;
          }
          currentIndex -= 1;
        }
        if (currentIndex < _tips.length) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: widget.itemBuilder(_tips[currentIndex]),
          );
        }
        currentIndex -= _tips.length;
        if (_isLoading && currentIndex == 0) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (widget.footer != null) {
          return Padding(
            padding: const EdgeInsets.only(top: 4),
            child: widget.footer!,
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class TipCard extends ConsumerWidget {
  const TipCard({
    super.key,
    required this.tip,
    required this.onTap,
  });

  final TraderTip tip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final primary = Theme.of(context).colorScheme.primary;
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Badge(
                            label: tip.type,
                            backgroundColor: primary.withOpacity(0.12),
                            textColor: primary,
                          ),
                          ...tip.tags.take(4).map(
                            (tag) => _TagChip(label: tag),
                          ),
                        ],
                      ),
                    ),
                    if (tip.isFeatured)
                      Padding(
                        padding: const EdgeInsets.only(left: 8, top: 2),
                        child: Icon(
                          Icons.push_pin,
                          size: 18,
                          color: primary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
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
                  style: textTheme.bodyMedium?.copyWith(color: muted),
                ),
                const SizedBox(height: 12),
                _ActionLine(text: tip.action),
                const SizedBox(height: 12),
                _AuthorFooter(
                  authorName: tip.authorName,
                  primary: primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TipInteractionsRow extends ConsumerStatefulWidget {
  const TipInteractionsRow({
    super.key,
    required this.tip,
    required this.currentUser,
    this.compact = false,
  });

  final TraderTip tip;
  final AppUser? currentUser;
  final bool compact;

  @override
  ConsumerState<TipInteractionsRow> createState() =>
      _TipInteractionsRowState();
}

class _TipInteractionsRowState extends ConsumerState<TipInteractionsRow> {
  late int _likesCount;
  late int _savesCount;
  bool _likeBusy = false;
  bool _saveBusy = false;

  @override
  void initState() {
    super.initState();
    _likesCount = widget.tip.likesCount;
    _savesCount = widget.tip.savesCount;
  }

  @override
  void didUpdateWidget(covariant TipInteractionsRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tip.likesCount != widget.tip.likesCount) {
      _likesCount = widget.tip.likesCount;
    }
    if (oldWidget.tip.savesCount != widget.tip.savesCount) {
      _savesCount = widget.tip.savesCount;
    }
  }

  Future<void> _toggleLike(bool isLiked) async {
    final user = widget.currentUser;
    if (user == null || _likeBusy) {
      return;
    }
    setState(() => _likeBusy = true);
    try {
      final newState = await ref.read(tipRepositoryProvider).toggleLike(
            tipId: widget.tip.id,
            uid: user.uid,
          );
      setState(() {
        _likesCount = max(0, _likesCount + (newState ? 1 : -1));
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update like.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _likeBusy = false);
      }
    }
  }

  Future<void> _toggleSave(bool isSaved) async {
    final user = widget.currentUser;
    if (user == null || _saveBusy) {
      return;
    }
    setState(() => _saveBusy = true);
    try {
      final newState = await ref.read(tipRepositoryProvider).toggleSave(
            tipId: widget.tip.id,
            uid: user.uid,
          );
      setState(() {
        _savesCount = max(0, _savesCount + (newState ? 1 : -1));
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update save.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saveBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.currentUser;
    final textTheme = Theme.of(context).textTheme;
    final iconSize = widget.compact ? 18.0 : 20.0;
    final labelStyle = widget.compact
        ? textTheme.labelSmall
        : textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600);

    return Row(
      children: [
        StreamBuilder<bool>(
          stream: user == null
              ? const Stream<bool>.empty()
              : ref
                  .read(tipRepositoryProvider)
                  .watchLikeStatus(tipId: widget.tip.id, uid: user.uid),
          builder: (context, snapshot) {
            final isLiked = snapshot.data ?? false;
            return TextButton.icon(
              onPressed: user == null
                  ? null
                  : () => _toggleLike(isLiked),
              icon: Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                size: iconSize,
                color: isLiked ? Colors.redAccent : null,
              ),
              label: Text('$_likesCount', style: labelStyle),
            );
          },
        ),
        const SizedBox(width: 4),
        StreamBuilder<bool>(
          stream: user == null
              ? const Stream<bool>.empty()
              : ref
                  .read(tipRepositoryProvider)
                  .watchSaveStatus(tipId: widget.tip.id, uid: user.uid),
          builder: (context, snapshot) {
            final isSaved = snapshot.data ?? false;
            return TextButton.icon(
              onPressed: user == null
                  ? null
                  : () => _toggleSave(isSaved),
              icon: Icon(
                isSaved ? Icons.bookmark : Icons.bookmark_border,
                size: iconSize,
              ),
              label: Text('$_savesCount', style: labelStyle),
            );
          },
        ),
      ],
    );
  }
}

class TipDisclaimer extends StatelessWidget {
  const TipDisclaimer({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Educational only. Not financial advice.',
      style: Theme.of(context)
          .textTheme
          .bodySmall
          ?.copyWith(color: AppThemeTokens.of(context).mutedText),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
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

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: tokens.surfaceAlt,
        border: Border.all(color: tokens.border),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _ActionLine extends StatelessWidget {
  const _ActionLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        children: [
          Icon(Icons.flash_on, size: 16, color: tokens.warning),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Action: $text',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthorFooter extends StatelessWidget {
  const _AuthorFooter({
    required this.authorName,
    required this.primary,
  });

  final String authorName;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: primary.withOpacity(0.1),
          child: Text(
            _initials(authorName),
            style: textTheme.labelSmall?.copyWith(
              color: primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            authorName,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppThemeTokens.of(context).mutedText),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Unable to load tips',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppThemeTokens.of(context).mutedText),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) {
    return 'U';
  }
  final buffer = StringBuffer();
  for (final part in parts.take(2)) {
    if (part.isNotEmpty) {
      buffer.write(part[0].toUpperCase());
    }
  }
  return buffer.isEmpty ? 'U' : buffer.toString();
}
