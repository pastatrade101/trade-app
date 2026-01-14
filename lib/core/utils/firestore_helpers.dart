import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? timestampToDate(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  return null;
}

Timestamp? dateToTimestamp(DateTime? date) {
  if (date == null) {
    return null;
  }
  return Timestamp.fromDate(date);
}
