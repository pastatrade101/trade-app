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
        appBar: AppBar(
          title: const Text('News'),
          bottom: TabBar(
            tabs: sources
                .map((source) => Tab(text: source.label))
                .toList(),
          ),
        ),
        body: TabBarView(
          children: sources
              .map((source) => NewsTab(source: source))
              .toList(),
        ),
      ),
    );
  }
}

class NewsTab extends ConsumerStatefulWidget {
  const NewsTab({super.key, required this.source});

  final NewsSource source;

  @override
  ConsumerState<NewsTab> createState() => _NewsTabState();
}

class _NewsTabState extends ConsumerState<NewsTab> {
  late Future<List<NewsItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<NewsItem>> _load() {
    return ref.read(newsRepositoryProvider).fetchNews(widget.source);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
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
    return FutureBuilder<List<NewsItem>>(
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
        final items = snapshot.data ?? [];
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
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = items[index];
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
    return Material(
      color: tokens.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tokens.border),
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
