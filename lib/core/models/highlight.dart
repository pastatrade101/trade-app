import '../utils/firestore_helpers.dart';

class DailyHighlight {
  const DailyHighlight({
    required this.id,
    required this.type,
    required this.targetId,
    required this.title,
    required this.subtitle,
    required this.dateKey,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String type;
  final String targetId;
  final String title;
  final String subtitle;
  final String dateKey;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory DailyHighlight.fromJson(String id, Map<String, dynamic> json) {
    return DailyHighlight(
      id: id,
      type: json['type'] ?? 'signal',
      targetId: json['targetId'] ?? '',
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
      dateKey: json['dateKey'] ?? '',
      isActive: json['isActive'] ?? false,
      createdAt: timestampToDate(json['createdAt']),
      updatedAt: timestampToDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'targetId': targetId,
      'title': title,
      'subtitle': subtitle,
      'dateKey': dateKey,
      'isActive': isActive,
      'createdAt': dateToTimestamp(createdAt),
      'updatedAt': dateToTimestamp(updatedAt),
    };
  }
}
