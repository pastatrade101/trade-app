import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  AnalyticsService._();

  static final AnalyticsService instance = AnalyticsService._();
  static const bool analyticsBuildEnabled =
      bool.fromEnvironment('ENABLE_ANALYTICS', defaultValue: true);
  static bool analyticsEnabled = analyticsBuildEnabled;

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final FirebaseAnalyticsObserver _observer =
      FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance);

  FirebaseAnalyticsObserver get observer => _observer;

  Future<void> setAnalyticsEnabled(bool enabled) async {
    if (!analyticsBuildEnabled) {
      analyticsEnabled = false;
      return;
    }
    analyticsEnabled = enabled;
    try {
      await _analytics.setAnalyticsCollectionEnabled(enabled);
    } catch (_) {}
  }

  Future<void> logScreenView(String screenName) async {
    if (!analyticsEnabled || !analyticsBuildEnabled) {
      return;
    }
    try {
      await _analytics.logScreenView(screenName: screenName);
      _debug('screen_view', {'screen': screenName});
    } catch (_) {}
  }

  Future<void> logScreen(
    String screenName, {
    String? classOverride,
  }) async {
    if (!analyticsEnabled || !analyticsBuildEnabled) {
      return;
    }
    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: classOverride,
      );
      _debug('screen_view', {'screen': screenName});
    } catch (_) {}
  }

  Future<void> logEvent(
    String name, {
    Map<String, Object?>? params,
  }) async {
    if (!analyticsEnabled || !analyticsBuildEnabled) {
      return;
    }
    try {
      final safeParams = _sanitizeParams(params);
      await _analytics.logEvent(name: name, parameters: safeParams);
      _debug(name, params);
    } catch (_) {}
  }

  Future<void> setUserId(String? uid) async {
    if (!analyticsEnabled || !analyticsBuildEnabled) {
      return;
    }
    try {
      await _analytics.setUserId(id: uid);
      _debug('set_user_id', {'uid': uid ?? 'null'});
    } catch (_) {}
  }

  Future<void> setUserProperty(String name, String value) async {
    if (!analyticsEnabled || !analyticsBuildEnabled) {
      return;
    }
    try {
      await _analytics.setUserProperty(name: name, value: value);
      _debug('set_user_property', {'name': name, 'value': value});
    } catch (_) {}
  }

  void _debug(String name, Map<String, Object?>? params) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('Analytics: $name ${params ?? const {}}');
  }

  Map<String, Object>? _sanitizeParams(Map<String, Object?>? params) {
    if (params == null) {
      return null;
    }
    final safe = <String, Object>{};
    params.forEach((key, value) {
      if (value == null) {
        return;
      }
      safe[key] = value;
    });
    return safe.isEmpty ? null : safe;
  }
}

// DebugView tips:
// Android: adb shell setprop debug.firebase.analytics.app <your.package.name>
// iOS: use Xcode to set -FIRAnalyticsDebugEnabled in scheme arguments.
