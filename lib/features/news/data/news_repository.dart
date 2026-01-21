import 'dart:convert';

import 'package:http/http.dart' as http;

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

  Uri _buildUri(NewsSource source) {
    return Uri.https(
      '${_region}-${_projectId}.cloudfunctions.net',
      '/news',
      {'source': source.queryValue},
    );
  }

  Future<List<NewsItem>> fetchNews(NewsSource source) async {
    final response = await _getWithRetry(_buildUri(source));
    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic>) {
      throw StateError('Unexpected news response.');
    }
    final itemsRaw = payload['items'];
    if (itemsRaw is! List) {
      return [];
    }
    return itemsRaw
        .whereType<Map>()
        .map((item) => NewsItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();
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
}
