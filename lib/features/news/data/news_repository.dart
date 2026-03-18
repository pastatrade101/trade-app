import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';

import '../../../firebase_options.dart';
import '../models/news_item.dart';

enum NewsSource {
  fxstreetForex,
  fxstreetCrypto,
  fxstreetAnalysis,
}

extension NewsSourceInfo on NewsSource {
  String get label {
    switch (this) {
      case NewsSource.fxstreetForex:
        return 'Forex';
      case NewsSource.fxstreetCrypto:
        return 'Crypto';
      case NewsSource.fxstreetAnalysis:
        return 'Analysis';
    }
  }

  String get queryValue {
    switch (this) {
      case NewsSource.fxstreetForex:
        return 'fxstreet_forex';
      case NewsSource.fxstreetCrypto:
        return 'fxstreet_crypto';
      case NewsSource.fxstreetAnalysis:
        return 'fxstreet_analysis';
    }
  }
}

class NewsRepository {
  NewsRepository({
    http.Client? httpClient,
    String? projectId,
    String region = 'us-central1',
    Duration timeout = const Duration(seconds: 12),
  })  : _httpClient = httpClient ?? http.Client(),
        _projectId =
            projectId ?? DefaultFirebaseOptions.currentPlatform.projectId,
        _region = region,
        _timeout = timeout;

  final http.Client _httpClient;
  final String _projectId;
  final String _region;
  final Duration _timeout;
  static const String _analysisCacheKey = 'news_analysis_cache_v1';
  static const String _analysisFingerprintKey = 'news_analysis_cache_fp_v1';
  static const String _rssUserAgent = 'MarketResolveTZRSS/1.0';

  static const Map<NewsSource, String> _directRssUrls = {
    NewsSource.fxstreetForex: 'https://www.fxstreet.com/rss/news',
    NewsSource.fxstreetCrypto: 'https://www.fxstreet.com/rss/crypto',
    NewsSource.fxstreetAnalysis: 'https://www.fxstreet.com/rss/analysis',
  };

  Uri _buildUri(NewsSource source, {bool forceRefresh = false}) {
    final query = <String, String>{'source': source.queryValue};
    if (forceRefresh) {
      query['refresh'] = '1';
      query['t'] = DateTime.now().millisecondsSinceEpoch.toString();
    }
    return Uri.https(
      '${_region}-${_projectId}.cloudfunctions.net',
      '/news',
      query,
    );
  }

  Future<List<NewsItem>> fetchNews(
    NewsSource source, {
    bool forceRefresh = false,
  }) async {
    final result = await fetchNewsFeed(
      source,
      forceRefresh: forceRefresh,
    );
    return result.items;
  }

  Future<NewsFeedResult> fetchNewsFeed(
    NewsSource source, {
    bool forceRefresh = false,
  }) async {
    try {
      final response = await _getWithRetry(
        _buildUri(source, forceRefresh: forceRefresh),
      );
      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic>) {
        throw StateError('Unexpected news response.');
      }
      final itemsRaw = payload['items'];
      final fetchedAt = _parseFetchedAt(payload['lastFetchedAt']);
      final servedFromCache = payload['servedFromCache'] == true ||
          payload['warning'] == 'served_from_cache';
      final items = itemsRaw is List
          ? (itemsRaw
              .whereType<Map>()
              .map((item) => NewsItem.fromJson(Map<String, dynamic>.from(item)))
              .toList()
            ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt)))
          : const <NewsItem>[];

      if (servedFromCache || items.isEmpty) {
        final directItems = await _tryFetchDirectRss(source);
        if (directItems.isNotEmpty) {
          return NewsFeedResult(
            items: directItems,
            servedFromCache: false,
            fetchedAt: DateTime.now().toUtc(),
          );
        }
      }

      return NewsFeedResult(
        items: items,
        servedFromCache: servedFromCache,
        fetchedAt: fetchedAt,
      );
    } catch (_) {
      final directItems = await _tryFetchDirectRss(source);
      if (directItems.isNotEmpty) {
        return NewsFeedResult(
          items: directItems,
          servedFromCache: false,
          fetchedAt: DateTime.now().toUtc(),
        );
      }
      rethrow;
    }
  }

  Future<List<NewsItem>> fetchAnalysisHighlights({int limit = 5}) async {
    final safeLimit = limit.clamp(1, 12).toInt();
    final prefs = await SharedPreferences.getInstance();
    final cached = _normalizeItems(_readCachedItems(prefs), safeLimit);

    try {
      final fresh = _normalizeItems(
        await fetchNews(NewsSource.fxstreetAnalysis),
        safeLimit,
      );

      if (fresh.isEmpty) {
        return cached;
      }

      final freshFingerprint = _analysisFingerprint(fresh);
      final cachedFingerprint = prefs.getString(_analysisFingerprintKey) ??
          _analysisFingerprint(cached);

      if (cached.isEmpty || freshFingerprint != cachedFingerprint) {
        await _writeCachedItems(prefs, fresh);
        return fresh;
      }

      return cached;
    } catch (_) {
      if (cached.isNotEmpty) {
        return cached;
      }
      rethrow;
    }
  }

  Future<http.Response> _getWithRetry(Uri uri) async {
    http.Response? lastResponse;
    Object? lastError;

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await _httpClient.get(uri).timeout(_timeout);
        lastResponse = response;
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return response;
        }
        lastError = StateError(
          'News request failed (${response.statusCode}): ${response.body}',
        );
      } catch (error) {
        lastError = error;
      }
    }

    if (lastError != null) {
      throw lastError;
    }
    if (lastResponse != null) {
      throw StateError(
        'News request failed (${lastResponse.statusCode}).',
      );
    }
    throw StateError('Unable to fetch news.');
  }

  List<NewsItem> _readCachedItems(SharedPreferences prefs) {
    final raw = prefs.getString(_analysisCacheKey);
    if (raw == null || raw.isEmpty) {
      return const <NewsItem>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <NewsItem>[];
      }
      return decoded
          .whereType<Map>()
          .map((item) => NewsItem.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      return const <NewsItem>[];
    }
  }

  Future<void> _writeCachedItems(
    SharedPreferences prefs,
    List<NewsItem> items,
  ) async {
    final encoded = jsonEncode(items.map((item) => item.toJson()).toList());
    await prefs.setString(_analysisCacheKey, encoded);
    await prefs.setString(_analysisFingerprintKey, _analysisFingerprint(items));
  }

  List<NewsItem> _normalizeItems(List<NewsItem> items, int limit) {
    final deduped = <String, NewsItem>{};
    for (final item in items) {
      final idKey = item.id.trim().isNotEmpty
          ? item.id.trim()
          : '${item.link}_${item.publishedAt.toUtc().toIso8601String()}';
      if (!deduped.containsKey(idKey)) {
        deduped[idKey] = item;
      }
    }
    final normalized = deduped.values
        .where((item) =>
            item.title.trim().isNotEmpty && item.link.trim().isNotEmpty)
        .toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return normalized.take(limit).toList();
  }

  String _analysisFingerprint(List<NewsItem> items) {
    return items
        .map(
          (item) =>
              '${item.id}|${item.link}|${item.publishedAt.toUtc().toIso8601String()}',
        )
        .join('||');
  }

  DateTime? _parseFetchedAt(Object? value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  Future<List<NewsItem>> _tryFetchDirectRss(NewsSource source) async {
    final url = _directRssUrls[source];
    if (url == null) {
      return const <NewsItem>[];
    }

    try {
      final response = await _httpClient.get(
        Uri.parse(url),
        headers: const {
          'User-Agent': _rssUserAgent,
          'Accept':
              'application/rss+xml, application/xml, text/xml;q=0.9, */*;q=0.8',
        },
      ).timeout(_timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const <NewsItem>[];
      }

      return _parseRssItems(response.body);
    } catch (_) {
      return const <NewsItem>[];
    }
  }

  List<NewsItem> _parseRssItems(String xmlText) {
    final document = XmlDocument.parse(xmlText);
    final itemNodes = document.findAllElements('item');
    final items = <NewsItem>[];

    for (final node in itemNodes) {
      final title = _normalizeText(_nodeText(node, 'title'));
      final link = _normalizeText(_nodeText(node, 'link'));
      if (title.isEmpty || link.isEmpty) {
        continue;
      }

      final description = _stripHtml(
        () {
          final descriptionText = _nodeText(node, 'description');
          if (descriptionText.isNotEmpty) {
            return descriptionText;
          }
          return _nodeText(node, 'content:encoded');
        }(),
      );
      final publishedAt = _parsePublishedAt(
            () {
              final pubDate = _nodeText(node, 'pubDate');
              if (pubDate.isNotEmpty) {
                return pubDate;
              }
              final published = _nodeText(node, 'published');
              if (published.isNotEmpty) {
                return published;
              }
              return _nodeText(node, 'dc:date');
            }(),
          ) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      final guid = _normalizeText(_nodeText(node, 'guid'));
      final id = guid.isNotEmpty
          ? guid
          : '${link}_${publishedAt.toUtc().toIso8601String()}';

      items.add(
        NewsItem(
          id: id,
          title: title,
          link: link,
          description: description,
          publishedAt: publishedAt.toUtc(),
        ),
      );
    }

    final deduped = <String, NewsItem>{};
    for (final item in items) {
      deduped.putIfAbsent(item.id, () => item);
    }

    final result = deduped.values.toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return result;
  }

  String _nodeText(XmlElement parent, String name) {
    for (final child in parent.children.whereType<XmlElement>()) {
      if (child.name.qualified == name || child.name.local == name) {
        return child.innerText;
      }
    }
    return '';
  }

  String _normalizeText(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _stripHtml(String value) {
    return value
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  DateTime? _parsePublishedAt(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final iso = DateTime.tryParse(trimmed);
    if (iso != null) {
      return iso.toUtc();
    }
    const patterns = [
      'EEE, dd MMM yyyy HH:mm:ss zzz',
      'EEE, d MMM yyyy HH:mm:ss zzz',
      'EEE, dd MMM yyyy HH:mm zzz',
      'yyyy-MM-ddTHH:mm:ssZ',
    ];
    for (final pattern in patterns) {
      try {
        return DateFormat(pattern, 'en_US').parseUtc(trimmed);
      } catch (_) {
        continue;
      }
    }
    return null;
  }
}

class NewsFeedResult {
  const NewsFeedResult({
    required this.items,
    required this.servedFromCache,
    required this.fetchedAt,
  });

  final List<NewsItem> items;
  final bool servedFromCache;
  final DateTime? fetchedAt;
}
