import 'package:intl/intl.dart';

import '../../../core/utils/time_format.dart';

enum TradingSessionStatus { open, upcoming, closed }

class TradingSessionInfo {
  const TradingSessionInfo({
    required this.key,
    required this.name,
    required this.opensAt,
    required this.closesAt,
    required this.nextOpen,
    required this.status,
    required this.opensIn,
    required this.closesIn,
  });

  final String key;
  final String name;
  final DateTime opensAt;
  final DateTime closesAt;
  final DateTime nextOpen;
  final TradingSessionStatus status;
  final Duration opensIn;
  final Duration closesIn;

  String formatTime(DateTime time) {
    return DateFormat('HH:mm').format(time);
  }

  String windowLabel() {
    return '${formatTime(opensAt)} – ${formatTime(closesAt)}';
  }

  String statusLabel() {
    switch (status) {
      case TradingSessionStatus.open:
        return 'OPEN';
      case TradingSessionStatus.upcoming:
        return 'OPENS IN';
      case TradingSessionStatus.closed:
        return 'CLOSED';
    }
  }

  String countdownLabel() {
    if (status == TradingSessionStatus.open) {
      return 'Closes in ${formatCountdown(closesIn)}';
    }
    return 'Opens in ${formatCountdown(opensIn)}';
  }

  String nextOpenLabel() {
    return formatTime(nextOpen);
  }
}

class SessionsService {
  static const List<SessionDefinition> definitions = [
    SessionDefinition('asia', 'Asia', 3, 0, 12, 0),
    SessionDefinition('london', 'London', 11, 0, 20, 0),
    SessionDefinition('new_york', 'New York', 16, 0, 1, 0),
  ];

  static bool isWeekend(DateTime date) {
    return date.weekday == DateTime.saturday ||
        date.weekday == DateTime.sunday;
  }

  List<TradingSessionInfo> buildSessions({DateTime? now}) {
    final current = now ?? DateTime.now();
    final date = DateTime(current.year, current.month, current.day);
    final weekend = isWeekend(current);
    final baseDate = weekend
        ? date.add(Duration(days: current.weekday == DateTime.saturday ? 2 : 1))
        : date;
    final sessions = <TradingSessionInfo>[];

    for (final session in definitions) {
      final opensAt = DateTime(
        baseDate.year,
        baseDate.month,
        baseDate.day,
        session.openHour,
        session.openMinute,
      );
      var closesAt = DateTime(
        baseDate.year,
        baseDate.month,
        baseDate.day,
        session.closeHour,
        session.closeMinute,
      );
      if (!closesAt.isAfter(opensAt)) {
        closesAt = closesAt.add(const Duration(days: 1));
      }

      TradingSessionStatus status;
      Duration opensIn = Duration.zero;
      Duration closesIn = Duration.zero;
      DateTime nextOpen = opensAt;

      if (weekend) {
        status = TradingSessionStatus.closed;
        opensIn = opensAt.difference(current);
      } else if (current.isBefore(opensAt)) {
        status = TradingSessionStatus.upcoming;
        opensIn = opensAt.difference(current);
      } else if (current.isBefore(closesAt)) {
        status = TradingSessionStatus.open;
        closesIn = closesAt.difference(current);
      } else {
        status = TradingSessionStatus.closed;
        nextOpen = opensAt.add(const Duration(days: 1));
        opensIn = nextOpen.difference(current);
      }

      sessions.add(
        TradingSessionInfo(
          key: session.key,
          name: session.name,
          opensAt: opensAt,
          closesAt: closesAt,
          nextOpen: nextOpen,
          status: status,
          opensIn: opensIn,
          closesIn: closesIn,
        ),
      );
    }

    return sessions;
  }
}

class SessionDefinition {
  const SessionDefinition(
    this.key,
    this.name,
    this.openHour,
    this.openMinute,
    this.closeHour,
    this.closeMinute,
  );

  final String key;
  final String name;
  final int openHour;
  final int openMinute;
  final int closeHour;
  final int closeMinute;
}
