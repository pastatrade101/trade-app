import '../utils/firestore_helpers.dart';

class ReportItem {
  final String id;
  final String reporterUid;
  final String targetType;
  final String targetId;
  final String reason;
  final String details;
  final String status;
  final DateTime createdAt;

  const ReportItem({
    required this.id,
    required this.reporterUid,
    required this.targetType,
    required this.targetId,
    required this.reason,
    required this.details,
    required this.status,
    required this.createdAt,
  });

  factory ReportItem.fromJson(String id, Map<String, dynamic> json) {
    return ReportItem(
      id: id,
      reporterUid: json['reporterUid'] ?? '',
      targetType: json['targetType'] ?? '',
      targetId: json['targetId'] ?? '',
      reason: json['reason'] ?? '',
      details: json['details'] ?? '',
      status: json['status'] ?? 'open',
      createdAt: timestampToDate(json['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reporterUid': reporterUid,
      'targetType': targetType,
      'targetId': targetId,
      'reason': reason,
      'details': details,
      'status': status,
      'createdAt': dateToTimestamp(createdAt),
    };
  }
}
