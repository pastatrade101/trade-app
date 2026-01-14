import '../utils/firestore_helpers.dart';

const String tradingSessionConfigDoc = 'config/tradingSessions';
const String defaultTradingTimezone = 'Africa/Dar_es_Salaam';
const int defaultSessionDurationMinutes = 120;
const List<String> tradingSessionKeys = ['LONDON', 'NEW_YORK', 'ASIA'];

const Map<String, String> tradingSessionLabels = {
  'LONDON': 'London',
  'NEW_YORK': 'New York',
  'ASIA': 'Asia',
};

class TradingSession {
  final String key;
  final String label;
  final bool enabled;
  final int durationMinutes;

  const TradingSession({
    required this.key,
    required this.label,
    required this.enabled,
    required this.durationMinutes,
  });

  factory TradingSession.fromJson(String key, Map<String, dynamic>? json) {
    final label = json?['label'] ?? tradingSessionLabels[key] ?? key;
    final enabled = json?['enabled'] ?? true;
    final duration = (json?['durationMinutes'] ?? defaultSessionDurationMinutes).toInt();
    return TradingSession(
      key: key,
      label: label,
      enabled: enabled,
      durationMinutes: duration,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'enabled': enabled,
      'durationMinutes': durationMinutes,
    };
  }
}

class TradingSessionConfig {
  final String timezone;
  final Map<String, TradingSession> sessions;
  final DateTime? updatedAt;

  const TradingSessionConfig({
    required this.timezone,
    required this.sessions,
    required this.updatedAt,
  });

  factory TradingSessionConfig.fallback() {
    final sessions = <String, TradingSession>{
      for (final key in tradingSessionKeys)
        key: TradingSession(
          key: key,
          label: tradingSessionLabels[key] ?? key,
          enabled: true,
          durationMinutes: defaultSessionDurationMinutes,
        ),
    };
    return TradingSessionConfig(
      timezone: defaultTradingTimezone,
      sessions: sessions,
      updatedAt: null,
    );
  }

  factory TradingSessionConfig.fromJson(Map<String, dynamic>? json) {
    final fallback = TradingSessionConfig.fallback();
    if (json == null) {
      return fallback;
    }
    final timezone = json['timezone'] ?? fallback.timezone;
    final sessionsJson = Map<String, dynamic>.from(json['sessions'] ?? const {});
    final sessions = <String, TradingSession>{};
    for (final key in tradingSessionKeys) {
      final entry = sessionsJson[key];
      sessions[key] = TradingSession.fromJson(
        key,
        entry is Map<String, dynamic> ? entry : null,
      );
    }
    return TradingSessionConfig(
      timezone: timezone,
      sessions: sessions,
      updatedAt: timestampToDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timezone': timezone,
      'sessions': {
        for (final entry in sessions.entries) entry.key: entry.value.toJson(),
      },
    };
  }

  List<TradingSession> enabledSessionsOrdered() {
    return tradingSessionKeys
        .map((key) => sessions[key])
        .whereType<TradingSession>()
        .where((session) => session.enabled)
        .toList();
  }

  String labelFor(String sessionKey) {
    return sessions[sessionKey]?.label ??
        tradingSessionLabels[sessionKey] ??
        sessionKey;
  }

  int durationFor(String sessionKey) {
    return sessions[sessionKey]?.durationMinutes ?? defaultSessionDurationMinutes;
  }
}
