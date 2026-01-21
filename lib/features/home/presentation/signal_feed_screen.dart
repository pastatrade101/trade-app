import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';

import '../../../app/app_theme.dart';
import '../../../app/providers.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/models/highlight.dart';
import '../../../core/models/trading_session_config.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/app_section_card.dart';
import '../../../core/widgets/app_reveal.dart';
import '../../../core/widgets/app_shimmer.dart';
import '../../tips/presentation/tip_detail_screen.dart';
import '../../profile/presentation/trader_profile_screen.dart';
import '../data/signal_feed_controller.dart';
import 'saved_signals_screen.dart';
import 'signal_card.dart';
import 'signal_detail_screen.dart';
import 'package:stock_investment_flutter/app/app_icons.dart';

class SignalFeedScreen extends ConsumerStatefulWidget {
  const SignalFeedScreen({super.key});

  @override
  ConsumerState<SignalFeedScreen> createState() => _SignalFeedScreenState();
}

class _SignalFeedScreenState extends ConsumerState<SignalFeedScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  List<String> _sessionKeys = const [];
  List<TradingSession> _sessions = const [];
  static const String _allPairsValue = '__all_pairs__';

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionConfigState = ref.watch(tradingSessionConfigProvider);
    final sessionConfig = sessionConfigState.asData?.value ??
        TradingSessionConfig.fallback();
    final enabledSessions = sessionConfig.enabledSessionsOrdered();
    final sessions = enabledSessions.isNotEmpty
        ? enabledSessions
        : TradingSessionConfig.fallback().enabledSessionsOrdered();
    final baseFilter = ref.watch(signalFeedFilterProvider);
    _scheduleTabSync(sessions);

    final tabController = _tabController;

    if (tabController == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Signals'),
          actions: [
            IconButton(
              tooltip: 'Saved signals',
              icon: const Icon(AppIcons.bookmark_border),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SavedSignalsScreen(),
                  ),
                );
              },
            ),
          ],
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final dateKey = tanzaniaDateKey();
    final highlightStream =
        ref.read(highlightRepositoryProvider).watchHighlightByDate(dateKey);
    final tabBar = TabBar(
      controller: tabController,
      isScrollable: true,
      tabs: _sessions.map((session) => Tab(text: session.label)).toList(),
    );

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              pinned: true,
              title: const Text('Signals'),
              actions: [
                _PairFilterAction(
                  onTap: () => _openPairPicker(context),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Saved signals',
                  icon: const Icon(AppIcons.bookmark_border),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SavedSignalsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: StreamBuilder<DailyHighlight?>(
                stream: highlightStream,
                builder: (context, snapshot) {
                  final highlight = snapshot.data;
                  if (highlight == null || !highlight.isActive) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: _TodayHighlightCard(
                      highlight: highlight,
                      onTap: () => _openHighlight(context, highlight),
                    ),
                  );
                },
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarHeaderDelegate(tabBar: tabBar),
            ),
          ];
        },
        body: TabBarView(
          controller: tabController,
          children: List.generate(_sessions.length, (index) {
            final session = _sessions[index];
            final filter = baseFilter.copyWith(session: session.key);
            return _SignalFeedList(
              key: ValueKey('signals_${session.key}_${baseFilter.pair}'),
              filter: filter,
            );
          }),
        ),
      ),
    );
  }

  void _scheduleTabSync(List<TradingSession> sessions) {
    final keys = sessions.map((session) => session.key).toList();
    if (listEquals(keys, _sessionKeys)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyTabSessions(sessions, keys);
    });
  }

  void _applyTabSessions(List<TradingSession> sessions, List<String> keys) {
    final previousIndex = _tabController?.index ?? 0;
    final initialIndex = previousIndex.clamp(0, keys.length - 1).toInt();
    final controller = TabController(
      length: keys.length,
      vsync: this,
      initialIndex: initialIndex,
    );

    if (!mounted) {
      controller.dispose();
      return;
    }

    setState(() {
      _tabController?.dispose();
      _tabController = controller;
      _sessionKeys = keys;
      _sessions = sessions;
    });

  }

  Future<void> _openPairPicker(BuildContext context) async {
    final filter = ref.read(signalFeedFilterProvider);
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return _PairPickerSheet(
          selectedPair: filter.pair,
          allPairsValue: _allPairsValue,
        );
      },
    );
    if (selected == null) return;

    final nextPair = selected == _allPairsValue ? null : selected;
    if (nextPair == filter.pair) return;

    ref.read(signalFeedFilterProvider.notifier).state =
        filter.copyWith(pair: nextPair);
  }

  void _openHighlight(BuildContext context, DailyHighlight highlight) {
    switch (highlight.type) {
      case 'tip':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TipDetailScreen(tipId: highlight.targetId),
          ),
        );
        return;
      case 'trader':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TraderProfileScreen(uid: highlight.targetId),
          ),
        );
        return;
      default:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SignalDetailScreen(signalId: highlight.targetId),
          ),
        );
        return;
    }
  }
}

class _PairFilterAction extends ConsumerWidget {
  const _PairFilterAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(signalFeedFilterProvider);
    final tokens = AppThemeTokens.of(context);
    final label = filter.pair ?? 'All pairs';
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: tokens.surfaceAlt,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tokens.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.filter_alt_outlined,
                size: 16, color: colorScheme.primary),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            const SizedBox(width: 2),
            Icon(AppIcons.expand_more, size: 18, color: colorScheme.primary),
          ],
        ),
      ),
    );
  }
}

class _PairPickerSheet extends StatelessWidget {
  const _PairPickerSheet({
    required this.selectedPair,
    required this.allPairsValue,
  });

  final String? selectedPair;
  final String allPairsValue;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final items = <String?>[null, ...AppConstants.instruments];
    final height = MediaQuery.of(context).size.height * 0.86;

    return SizedBox(
      height: height,
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: tokens.border,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  'Select pair',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(AppIcons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final pair = items[index];
                final label = pair ?? 'All pairs';
                final isSelected =
                    (pair == null && selectedPair == null) ||
                        pair == selectedPair;
                final value = pair ?? allPairsValue;
                return Material(
                  color: isSelected ? tokens.surfaceAlt : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.of(context).pop(value),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? colorScheme.primary
                              : tokens.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            AppIcons.stacked_line_chart,
                            size: 18,
                            color: isSelected
                                ? colorScheme.primary
                                : tokens.mutedText,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              label,
                              style:
                                  Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              AppIcons.check_circle,
                              size: 20,
                              color: colorScheme.primary,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayHighlightCard extends ConsumerStatefulWidget {
  const _TodayHighlightCard({
    super.key,
    required this.highlight,
    required this.onTap,
  });

  final DailyHighlight highlight;
  final VoidCallback onTap;

  @override
  ConsumerState<_TodayHighlightCard> createState() =>
      _TodayHighlightCardState();
}

class _TodayHighlightCardState extends ConsumerState<_TodayHighlightCard> {
  String? _imageUrl;
  String? _paletteUrl;
  Color? _vibrantColor;

  @override
  void initState() {
    super.initState();
    _loadHighlightImage();
  }

  @override
  void didUpdateWidget(covariant _TodayHighlightCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.highlight.targetId != widget.highlight.targetId ||
        oldWidget.highlight.type != widget.highlight.type) {
      _loadHighlightImage();
    }
  }

  Future<void> _loadHighlightImage() async {
    String? url;
    try {
      switch (widget.highlight.type) {
        case 'tip':
          final tip = await ref
              .read(tipRepositoryProvider)
              .fetchTip(widget.highlight.targetId);
          url = tip?.imageUrl;
          break;
        case 'trader':
          final trader = await ref
              .read(userRepositoryProvider)
              .fetchUser(widget.highlight.targetId);
          url = trader?.bannerUrl;
          break;
        default:
          final signal = await ref
              .read(signalRepositoryProvider)
              .fetchSignal(widget.highlight.targetId);
          url = signal?.imageUrl;
          break;
      }
    } catch (_) {
      url = null;
    }

    if (!mounted) return;
    setState(() {
      _imageUrl = (url != null && url.isNotEmpty) ? url : null;
    });

    await _loadPalette(url);
  }

  Future<void> _loadPalette(String? url) async {
    if (url == null || url.isEmpty) {
      if (mounted) {
        setState(() {
          _paletteUrl = null;
          _vibrantColor = null;
        });
      }
      return;
    }
    if (_paletteUrl == url && _vibrantColor != null) {
      return;
    }
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        NetworkImage(url),
        size: const Size(200, 200),
        maximumColorCount: 12,
      );
      final swatch = palette.vibrantColor ??
          palette.darkVibrantColor ??
          palette.dominantColor ??
          palette.lightVibrantColor;
      if (mounted) {
        setState(() {
          _paletteUrl = url;
          _vibrantColor = swatch?.color;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _paletteUrl = url;
          _vibrantColor = null;
        });
      }
    }
  }

  Color _darken(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final darkened =
        hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return darkened.toColor();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final baseColor = _vibrantColor ?? tokens.heroStart;
    final endColor =
        _vibrantColor != null ? _darken(baseColor, 0.35) : tokens.heroEnd;
    final hasImage = _imageUrl != null;
    return AppSectionCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            child: Stack(
              children: [
                if (hasImage)
                  Positioned.fill(
                    child: Image.network(
                      _imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          baseColor.withOpacity(hasImage ? 0.6 : 0.9),
                          endColor.withOpacity(hasImage ? 0.85 : 0.95),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            "Today's Highlight",
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _HighlightChip(
                            label: widget.highlight.type,
                            textColor: Colors.white,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            borderColor: Colors.white.withOpacity(0.3),
                          ),
                          const Spacer(),
                          Icon(AppIcons.arrow_forward,
                              color: Colors.white70, size: 18),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.highlight.title,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.highlight.subtitle,
                        style: textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HighlightChip extends StatelessWidget {
  const _HighlightChip({
    required this.label,
    this.textColor,
    this.backgroundColor,
    this.borderColor,
  });

  final String label;
  final Color? textColor;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor ?? tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor ?? tokens.border),
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: textColor ?? tokens.mutedText,
            ),
      ),
    );
  }
}

class _SignalFeedList extends ConsumerStatefulWidget {
  const _SignalFeedList({
    super.key,
    required this.filter,
  });

  final SignalFeedFilter filter;

  @override
  ConsumerState<_SignalFeedList> createState() => _SignalFeedListState();
}

class _SignalFeedListState extends ConsumerState<_SignalFeedList>
    with AutomaticKeepAliveClientMixin {
  bool _isLoadingMore = false;

  @override
  bool get wantKeepAlive => true;

  Future<void> _maybeLoadMore(bool hasMore) async {
    final feedState = ref.read(signalFeedControllerProvider(widget.filter));
    if (_isLoadingMore || !hasMore || feedState.isLoading) {
      return;
    }
    setState(() => _isLoadingMore = true);
    try {
      await ref
          .read(signalFeedControllerProvider(widget.filter).notifier)
          .loadMore();
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  bool _handleScroll(ScrollNotification notification, bool hasMore) {
    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }
    if (notification.metrics.pixels >=
        notification.metrics.maxScrollExtent - 240) {
      _maybeLoadMore(hasMore);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final feedState = ref.watch(signalFeedControllerProvider(widget.filter));
    final data = feedState.valueOrNull;
    final signals = data?.signals ?? const [];
    final hasMore = data?.hasMore ?? false;

    if (feedState.isLoading && signals.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => ref
            .read(signalFeedControllerProvider(widget.filter).notifier)
            .loadInitial(),
        child: ListView(
          key: PageStorageKey(
            'signals_${widget.filter.session}_${widget.filter.pair}',
          ),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          children: const [
            _SignalCardSkeleton(),
            SizedBox(height: 12),
            _SignalCardSkeleton(),
            SizedBox(height: 12),
            _SignalCardSkeleton(),
          ],
        ),
      );
    }

    if (feedState.hasError && signals.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => ref
            .read(signalFeedControllerProvider(widget.filter).notifier)
            .loadInitial(),
        child: ListView(
          key: PageStorageKey(
            'signals_${widget.filter.session}_${widget.filter.pair}',
          ),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
          children: [
            const Text(
              'Unable to load signals.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => ref
                  .read(signalFeedControllerProvider(widget.filter).notifier)
                  .loadInitial(),
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }

    if (signals.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => ref
            .read(signalFeedControllerProvider(widget.filter).notifier)
            .loadInitial(),
        child: ListView(
          key: PageStorageKey(
            'signals_${widget.filter.session}_${widget.filter.pair}',
          ),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
          children: const [
            Text(
              'No signals yet.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final showLoader = _isLoadingMore;

    return RefreshIndicator(
      onRefresh: () => ref
          .read(signalFeedControllerProvider(widget.filter).notifier)
          .loadInitial(),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) =>
            _handleScroll(notification, hasMore),
        child: ListView.separated(
          key: PageStorageKey(
            'signals_${widget.filter.session}_${widget.filter.pair}',
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: signals.length + (showLoader ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index >= signals.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final signal = signals[index];
            return RepaintBoundary(
              child: AppReveal(
                delay: Duration(milliseconds: 40 * (index % 6)),
                child: SignalCard(
                  signal: signal,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SignalDetailScreen(signalId: signal.id),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SignalCardSkeleton extends StatelessWidget {
  const _SignalCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        AppShimmerBox(height: 140, radius: 20),
        SizedBox(height: 8),
        AppShimmerBox(height: 18, radius: 999, width: 140),
      ],
    );
  }
}

class _TabBarHeaderDelegate extends SliverPersistentHeaderDelegate {
  _TabBarHeaderDelegate({required this.tabBar});

  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      elevation: overlapsContent ? 2 : 0,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarHeaderDelegate oldDelegate) {
    return oldDelegate.tabBar != tabBar;
  }
}
