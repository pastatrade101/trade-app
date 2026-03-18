import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../app/providers.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/models/tip.dart';
import '../../../core/models/trading_session_config.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/app_section_card.dart';
import '../../../core/widgets/app_reveal.dart';
import '../../../core/widgets/app_shimmer.dart';
import '../../tips/presentation/tip_detail_screen.dart';
import '../../tips/presentation/tip_widgets.dart';
import '../../news/models/news_item.dart';
import '../../news/presentation/news_webview_page.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../testimonials/presentation/testimonials_screen.dart';
import '../data/signal_feed_controller.dart';
import 'signal_card.dart';
import 'signal_detail_screen.dart';
import 'package:stock_investment_flutter/app/app_icons.dart';

final tipsOfDayProvider =
    FutureProvider.autoDispose<List<TraderTip>>((ref) async {
  final tips = await ref
      .read(tipRepositoryProvider)
      .fetchLatestTips(status: 'published', limit: 100);
  final todayKey = tanzaniaDateKey();
  return tips
      .where((tip) => tanzaniaDateKey(tip.createdAt) == todayKey)
      .toList();
});

final analysisHighlightsProvider =
    FutureProvider.autoDispose<List<NewsItem>>((ref) async {
  return ref.read(newsRepositoryProvider).fetchAnalysisHighlights(limit: 5);
});

class SignalFeedScreen extends ConsumerStatefulWidget {
  const SignalFeedScreen({super.key});

  @override
  ConsumerState<SignalFeedScreen> createState() => _SignalFeedScreenState();
}

class _SignalFeedScreenState extends ConsumerState<SignalFeedScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  List<String> _sessionKeys = const [];
  static const String _allPairsValue = '__all_pairs__';
  static const String _tipsTabKey = '__tips_tab__';
  static const String _reviewsTabKey = '__reviews_tab__';
  static const String _asiaSessionKey = 'ASIA';

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
    final currentUser = ref.watch(currentUserProvider).value;
    final profileLeading = _ProfileAppBarIdentity(
      avatarUrl: currentUser?.avatarUrl ?? '',
      username: currentUser?.username ?? currentUser?.displayName ?? '',
      country: currentUser?.country ?? '',
      onTap: currentUser == null
          ? null
          : () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProfileScreen(user: currentUser),
                ),
              );
            },
    );
    final sessionConfigState = ref.watch(tradingSessionConfigProvider);
    final sessionConfig =
        sessionConfigState.asData?.value ?? TradingSessionConfig.fallback();
    final enabledSessions = sessionConfig.enabledSessionsOrdered();
    final sessions = enabledSessions.isNotEmpty
        ? enabledSessions
        : TradingSessionConfig.fallback().enabledSessionsOrdered();
    final tabs = _buildTabs(sessions);
    final watchedFilter = ref.watch(signalFeedFilterProvider);
    final baseFilter = watchedFilter.view == SignalFeedView.active
        ? watchedFilter
        : watchedFilter.copyWith(view: SignalFeedView.active);
    if (watchedFilter.view != SignalFeedView.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(signalFeedFilterProvider.notifier).state = baseFilter;
      });
    }
    _scheduleTabSync(tabs);

    final tabController = _tabController;

    if (tabController == null) {
      return Scaffold(
        body: _TabContentBackground(
          child: SafeArea(
            top: true,
            bottom: false,
            child: Column(
              children: [
                SizedBox(
                  height: kToolbarHeight,
                  child: Row(
                    children: [
                      Expanded(child: profileLeading),
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: _PairFilterAction(
                          onTap: () => _openPairPicker(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final tokens = AppThemeTokens.of(context);
    final tabBar = TabBar(
      controller: tabController,
      isScrollable: true,
      labelColor: tokens.warning,
      unselectedLabelColor: tokens.mutedText,
      indicatorColor: tokens.warning,
      labelPadding: const EdgeInsets.symmetric(horizontal: 12),
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
      unselectedLabelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
      tabs: [
        ...tabs.map(
          (tab) => Tab(
            child: Text(
              tab.label,
              overflow: TextOverflow.visible,
            ),
          ),
        ),
      ],
    );

    return Scaffold(
      body: _TabContentBackground(
        child: SafeArea(
          top: true,
          bottom: false,
          child: NestedScrollView(
            physics: const ClampingScrollPhysics(),
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _PinnedHeaderDelegate(
                    minExtent: kToolbarHeight,
                    maxExtent: kToolbarHeight,
                    child: _StickyHeaderSurface(
                      child: Row(
                        children: [
                          Expanded(child: profileLeading),
                          Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: _PairFilterAction(
                              onTap: () => _openPairPicker(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Column(
                      children: [
                        _AnalysisHighlightsCarousel(
                          onOpen: (item) => _openAnalysis(context, item),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _PinnedHeaderDelegate(
                    minExtent: 54,
                    maxExtent: 54,
                    child: _StickyHeaderSurface(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: tabBar,
                      ),
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: tabController,
              children: tabs.map((tab) {
                if (tab.key == _reviewsTabKey) {
                  return const TestimonialsScreen(embedded: true);
                }
                if (tab.key == _tipsTabKey) {
                  return const _TipsOfDayTab();
                }
                final session = tab.session!;
                final filter = baseFilter.copyWith(session: session.key);
                return _SignalFeedList(
                  key: ValueKey(
                    'signals_${session.key}_${baseFilter.pair}_${baseFilter.view.name}',
                  ),
                  filter: filter,
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  List<_SignalFeedTab> _buildTabs(List<TradingSession> sessions) {
    final tabs = <_SignalFeedTab>[];
    var insertedReviews = false;

    for (final session in sessions) {
      if (session.key == _asiaSessionKey) {
        tabs.add(
          const _SignalFeedTab(
            key: _reviewsTabKey,
            label: 'Reviews',
          ),
        );
        insertedReviews = true;
        continue;
      }
      tabs.add(
        _SignalFeedTab(
          key: session.key,
          label: session.label,
          session: session,
        ),
      );
    }

    if (!insertedReviews) {
      tabs.add(
        const _SignalFeedTab(
          key: _reviewsTabKey,
          label: 'Reviews',
        ),
      );
    }

    tabs.add(
      const _SignalFeedTab(
        key: _tipsTabKey,
        label: 'Daily Tips',
      ),
    );

    return tabs;
  }

  void _scheduleTabSync(List<_SignalFeedTab> tabs) {
    final keys = tabs.map((tab) => tab.key).toList(growable: false);
    if (listEquals(keys, _sessionKeys)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyTabs(keys);
    });
  }

  void _applyTabs(List<String> keys) {
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

  void _openAnalysis(BuildContext context, NewsItem item) {
    final uri = Uri.tryParse(item.link);
    if (uri == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid analysis link.')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NewsWebViewPage(
          url: uri.toString(),
          title: item.title,
        ),
      ),
    );
  }
}

class _SignalFeedTab {
  const _SignalFeedTab({
    required this.key,
    required this.label,
    this.session,
  });

  final String key;
  final String label;
  final TradingSession? session;
}

class _PinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _PinnedHeaderDelegate({
    required this.minExtent,
    required this.maxExtent,
    required this.child,
  });

  @override
  final double minExtent;

  @override
  final double maxExtent;

  final Widget child;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _PinnedHeaderDelegate oldDelegate) {
    return minExtent != oldDelegate.minExtent ||
        maxExtent != oldDelegate.maxExtent ||
        child != oldDelegate.child;
  }
}

class _StickyHeaderSurface extends StatelessWidget {
  const _StickyHeaderSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isLightTheme
              ? [
                  tokens.background.withValues(alpha: 0.97),
                  tokens.background.withValues(alpha: 0.92),
                ]
              : [
                  tokens.background.withValues(alpha: 0.9),
                  tokens.background.withValues(alpha: 0.84),
                ],
        ),
        border: Border(
          bottom: BorderSide(
            color: tokens.border.withValues(alpha: 0.7),
          ),
        ),
      ),
      child: child,
    );
  }
}

class _TabContentBackground extends StatelessWidget {
  const _TabContentBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/tab.jpg',
          fit: BoxFit.cover,
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isLightTheme
                  ? [
                      Colors.white.withValues(alpha: 0.88),
                      tokens.background.withValues(alpha: 0.95),
                      tokens.background.withValues(alpha: 0.99),
                    ]
                  : [
                      Colors.black.withValues(alpha: 0.68),
                      tokens.background.withValues(alpha: 0.84),
                      tokens.background.withValues(alpha: 0.92),
                    ],
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _ProfileAppBarIdentity extends StatelessWidget {
  const _ProfileAppBarIdentity({
    required this.avatarUrl,
    required this.username,
    required this.country,
    required this.onTap,
  });

  final String avatarUrl;
  final String username;
  final String country;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final name = username.trim().isNotEmpty ? username.trim() : 'Profile';
    final countryText = country.trim().isNotEmpty ? country.trim() : '';
    final initialsSource = name;
    final initials =
        initialsSource.isNotEmpty ? initialsSource[0].toUpperCase() : 'P';
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundImage:
                  avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
              child: avatarUrl.isEmpty
                  ? Text(
                      initials,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  if (countryText.isNotEmpty)
                    Text(
                      countryText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7),
                          ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TipsOfDayTab extends ConsumerWidget {
  const _TipsOfDayTab();

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(tipsOfDayProvider);
    await ref.read(tipsOfDayProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tipsState = ref.watch(tipsOfDayProvider);
    final bottomInset = _signalPageBottomInset(context);

    return tipsState.when(
      loading: () => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 24, 16, bottomInset),
        children: const [
          AppShimmerBox(height: 140, radius: 20),
          SizedBox(height: 12),
          AppShimmerBox(height: 140, radius: 20),
          SizedBox(height: 12),
          AppShimmerBox(height: 140, radius: 20),
        ],
      ),
      error: (error, stack) => RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(24, 80, 24, bottomInset),
          children: [
            const Text(
              'Unable to load today\'s tips.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => _refresh(ref),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
      data: (tips) {
        if (tips.isEmpty) {
          return RefreshIndicator(
            onRefresh: () => _refresh(ref),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(24, 80, 24, bottomInset),
              children: const [
                Text(
                  'No tips for today yet.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => _refresh(ref),
          child: ListView.separated(
            key: const PageStorageKey('tips_of_day'),
            padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: tips.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final tip = tips[index];
              return RepaintBoundary(
                child: AppReveal(
                  delay: Duration(milliseconds: 40 * (index % 6)),
                  child: TipCard(
                    tip: tip,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TipDetailScreen(tipId: tip.id),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _PairFilterAction extends ConsumerWidget {
  const _PairFilterAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(signalFeedFilterProvider);
    final tokens = AppThemeTokens.of(context);
    final label = filter.pair == null
        ? 'All pairs'
        : (AppConstants.instrumentLabels[filter.pair] ?? filter.pair!);
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
                size: 16, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
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
    final categories = AppConstants.instrumentCategories;
    final height = MediaQuery.of(context).size.height * 0.86;
    final selectedAll = selectedPair == null;

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
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              children: [
                _PairOptionTile(
                  label: 'All pairs',
                  isSelected: selectedAll,
                  tokens: tokens,
                  colorScheme: colorScheme,
                  onTap: () => Navigator.of(context).pop(allPairsValue),
                ),
                for (final category in categories) ...[
                  const SizedBox(height: 16),
                  Text(
                    category.label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: tokens.mutedText,
                          letterSpacing: 0.3,
                        ),
                  ),
                  const SizedBox(height: 8),
                  for (final option in category.options)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _PairOptionTile(
                        label: option.label,
                        isSelected: option.symbol == selectedPair,
                        tokens: tokens,
                        colorScheme: colorScheme,
                        onTap: () => Navigator.of(context).pop(option.symbol),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PairOptionTile extends StatelessWidget {
  const _PairOptionTile({
    required this.label,
    required this.isSelected,
    required this.tokens,
    required this.colorScheme,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final AppThemeTokens tokens;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? tokens.surfaceAlt : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? colorScheme.primary : tokens.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                AppIcons.stacked_line_chart,
                size: 18,
                color: isSelected ? colorScheme.primary : tokens.mutedText,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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
  }
}

class _AnalysisHighlightsCarousel extends ConsumerStatefulWidget {
  const _AnalysisHighlightsCarousel({
    required this.onOpen,
  });

  final ValueChanged<NewsItem> onOpen;

  @override
  ConsumerState<_AnalysisHighlightsCarousel> createState() =>
      _AnalysisHighlightsCarouselState();
}

class _AnalysisHighlightsCarouselState
    extends ConsumerState<_AnalysisHighlightsCarousel> {
  late final PageController _controller;
  int _activeIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.92);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final analysisState = ref.watch(analysisHighlightsProvider);
    return analysisState.when(
      loading: () => const AppShimmerBox(
        height: 152,
        radius: 20,
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 8),
              child: Text(
                'Analysis Highlights',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            SizedBox(
              height: 152,
              child: PageView.builder(
                controller: _controller,
                itemCount: items.length,
                onPageChanged: (index) {
                  if (!mounted) return;
                  setState(() {
                    _activeIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _AnalysisHighlightCard(
                      item: item,
                      onTap: () => widget.onOpen(item),
                    ),
                  );
                },
              ),
            ),
            if (items.length > 1) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(items.length, (index) {
                  final active = index == _activeIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: active
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context)
                              .colorScheme
                              .outline
                              .withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  );
                }),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _AnalysisHighlightCard extends StatelessWidget {
  const _AnalysisHighlightCard({
    required this.item,
    required this.onTap,
  });

  final NewsItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final metaColor = colorScheme.onSurface.withValues(alpha: 0.76);
    final descriptionColor = colorScheme.onSurface.withValues(alpha: 0.84);
    final cleanedDescription = _cleanDescription(item.description);
    return AppSectionCard(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  isDark
                      ? colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.62,
                        )
                      : colorScheme.surface,
                  isDark
                      ? tokens.surface
                      : colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.92,
                        ),
                ],
              ),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(
                  alpha: isDark ? 0.55 : 0.9,
                ),
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        AppIcons.stacked_line_chart,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _newsAgeLabel(item.publishedAt),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: metaColor,
                                  ),
                        ),
                      ),
                      Icon(
                        AppIcons.arrow_forward,
                        size: 16,
                        color: metaColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    cleanedDescription.isNotEmpty
                        ? cleanedDescription
                        : 'Tap to open full analysis from the latest RSS feed.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: descriptionColor,
                          height: 1.35,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _cleanDescription(String input) {
  if (input.trim().isEmpty) {
    return '';
  }
  final noHtml = input
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll(RegExp(r'&nbsp;?', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'&amp;?', caseSensitive: false), '&')
      .replaceAll(RegExp(r'&quot;?', caseSensitive: false), '"')
      .replaceAll(RegExp(r'&#39;?', caseSensitive: false), '\'')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return noHtml;
}

String _newsAgeLabel(DateTime publishedAt) {
  final now = DateTime.now();
  final diff = now.difference(publishedAt);
  if (diff.isNegative || diff.inMinutes < 1) {
    return 'Just now';
  }
  if (diff.inMinutes < 60) {
    return '${diff.inMinutes}m ago';
  }
  if (diff.inHours < 24) {
    return '${diff.inHours}h ago';
  }
  if (diff.inDays < 7) {
    return '${diff.inDays}d ago';
  }
  return formatTanzaniaDateTime(publishedAt, pattern: 'MMM d');
}

double _signalPageBottomInset(BuildContext context) {
  return MediaQuery.paddingOf(context).bottom + 118;
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
    final bottomInset = _signalPageBottomInset(context);

    if (feedState.isLoading && signals.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => ref
            .read(signalFeedControllerProvider(widget.filter).notifier)
            .loadInitial(),
        child: ListView(
          key: PageStorageKey(
            'signals_${widget.filter.session}_${widget.filter.pair}_${widget.filter.view.name}',
          ),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16, 24, 16, bottomInset),
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
            'signals_${widget.filter.session}_${widget.filter.pair}_${widget.filter.view.name}',
          ),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(24, 80, 24, bottomInset),
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
            'signals_${widget.filter.session}_${widget.filter.pair}_${widget.filter.view.name}',
          ),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(24, 80, 24, bottomInset),
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
        onNotification: (notification) => _handleScroll(notification, hasMore),
        child: ListView.separated(
          key: PageStorageKey(
            'signals_${widget.filter.session}_${widget.filter.pair}_${widget.filter.view.name}',
          ),
          padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset),
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
