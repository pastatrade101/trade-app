import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../app/app_theme.dart';
import '../../../app/providers.dart';
import '../../../core/widgets/app_shimmer.dart';
import '../data/news_repository.dart';
import '../models/news_item.dart';
import 'news_webview_page.dart';

class NewsPage extends StatelessWidget {
  const NewsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final sources = NewsSource.values;
    return DefaultTabController(
      length: sources.length,
      child: Scaffold(
        body: _NewsPageBackground(
          child: SafeArea(
            child: Column(
              children: [
                TabBar(
                  tabs:
                      sources.map((source) => Tab(text: source.label)).toList(),
                ),
                Expanded(
                  child: TabBarView(
                    children: sources
                        .map((source) => NewsTab(source: source))
                        .toList(),
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

class _NewsPageBackground extends StatelessWidget {
  const _NewsPageBackground({required this.child});

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
                      Colors.white.withValues(alpha: 0.78),
                      tokens.background.withValues(alpha: 0.9),
                      tokens.background.withValues(alpha: 0.97),
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

class NewsTab extends ConsumerStatefulWidget {
  const NewsTab({super.key, required this.source});

  final NewsSource source;

  @override
  ConsumerState<NewsTab> createState() => _NewsTabState();
}

class _NewsTabState extends ConsumerState<NewsTab> with WidgetsBindingObserver {
  static const Duration _refreshInterval = Duration(minutes: 2);

  late Future<NewsFeedResult> _future;
  DateTime? _lastLoadedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _future = _load(forceRefresh: true);
  }

  @override
  void didUpdateWidget(covariant NewsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _future = _load(forceRefresh: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }
    final lastLoadedAt = _lastLoadedAt;
    if (lastLoadedAt == null ||
        DateTime.now().difference(lastLoadedAt) >= _refreshInterval) {
      setState(() {
        _future = _load(forceRefresh: true);
      });
    }
  }

  Future<NewsFeedResult> _load({bool forceRefresh = false}) async {
    final result = await ref.read(newsRepositoryProvider).fetchNewsFeed(
          widget.source,
          forceRefresh: forceRefresh,
        );
    _lastLoadedAt = DateTime.now();
    return result;
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load(forceRefresh: true);
    });
    await _future;
  }

  Future<void> _openNews(NewsItem item) async {
    final uri = Uri.tryParse(item.link);
    if (uri == null) {
      _showSnack('Invalid news link.');
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

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NewsFeedResult>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _buildLoading();
        }
        if (snapshot.hasError) {
          return _buildMessage(
            title: 'Unable to load news',
            subtitle: 'Pull to refresh or try again in a moment.',
            onRetry: _refresh,
          );
        }
        final result = snapshot.data;
        final items = result?.items ?? [];
        if (items.isEmpty) {
          return _buildMessage(
            title: 'No news yet',
            subtitle: 'Fresh headlines will appear here.',
            onRetry: _refresh,
          );
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: items.length + (result?.servedFromCache == true ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (result?.servedFromCache == true && index == 0) {
                return _CacheWarningCard(
                  fetchedAt: result?.fetchedAt,
                );
              }
              final itemIndex =
                  result?.servedFromCache == true ? index - 1 : index;
              final item = items[itemIndex];
              return _NewsCard(
                item: item,
                timeAgo: _timeAgo(item.publishedAt),
                onTap: () => _openNews(item),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildLoading() {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: 6,
        itemBuilder: (context, index) {
          return const AppShimmerBox(
            height: 110,
            margin: EdgeInsets.only(bottom: 12),
          );
        },
      ),
    );
  }

  Widget _buildMessage({
    required String title,
    required String subtitle,
    VoidCallback? onRetry,
  }) {
    final tokens = AppThemeTokens.of(context);
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: tokens.mutedText),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _timeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.isNegative) {
      return 'Just now';
    }
    if (diff.inMinutes < 1) {
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
    return DateFormat('MMM d').format(date);
  }
}

class _CacheWarningCard extends StatelessWidget {
  const _CacheWarningCard({required this.fetchedAt});

  final DateTime? fetchedAt;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final updatedAt = fetchedAt == null
        ? 'Latest sync time unavailable'
        : 'Last synced ${DateFormat('MMM d, HH:mm').format(fetchedAt!.toLocal())}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tokens.warning.withValues(alpha: 0.32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Showing cached headlines',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            '$updatedAt. Pull to refresh for a live RSS fetch.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: tokens.mutedText,
                ),
          ),
        ],
      ),
    );
  }
}

class _NewsCard extends StatefulWidget {
  const _NewsCard({
    required this.item,
    required this.timeAgo,
    required this.onTap,
  });

  final NewsItem item;
  final String timeAgo;
  final VoidCallback onTap;

  @override
  State<_NewsCard> createState() => _NewsCardState();
}

class _NewsCardState extends State<_NewsCard> {
  bool _expanded = false;

  void _toggleExpanded() {
    setState(() {
      _expanded = !_expanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    const radius = 16.0;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tokens.surface.withValues(alpha: 0.52),
                tokens.surface.withValues(alpha: 0.38),
              ],
            ),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.item.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                widget.timeAgo,
                style: TextStyle(
                  color: tokens.mutedText,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.item.description,
                maxLines: _expanded ? 12 : 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: tokens.mutedText),
              ),
              if (widget.item.description.length > 120) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _toggleExpanded,
                    child: Text(_expanded ? 'Show less' : 'Read more'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      textStyle: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
