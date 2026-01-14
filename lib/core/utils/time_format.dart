import 'package:intl/intl.dart';

const Duration tanzaniaOffset = Duration(hours: 3);

DateTime toTanzaniaTime(DateTime date) {
  return date.toUtc().add(tanzaniaOffset);
}

String formatTanzaniaDateTime(DateTime date, {String pattern = 'MMM d, HH:mm'}) {
  return DateFormat(pattern).format(toTanzaniaTime(date));
}

String formatCountdown(Duration remaining) {
  if (remaining.inSeconds <= 0) {
    return '0m';
  }
  final days = remaining.inDays;
  final hours = remaining.inHours % 24;
  final minutes = remaining.inMinutes % 60;
  if (days > 0) {
    return '${days}d ${hours}h';
  }
  if (hours > 0) {
    return '${hours}h ${minutes}m';
  }
  return '${minutes}m';
}

String tanzaniaDateKey([DateTime? now]) {
  final date = toTanzaniaTime(now ?? DateTime.now());
  return DateFormat('yyyy-MM-dd').format(date);
}
