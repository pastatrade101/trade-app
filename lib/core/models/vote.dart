import '../utils/firestore_helpers.dart';

class SignalVote {
  final String uid;
  final String outcomeType;
  final String? note;
  final int? trustLevel;
  final double? weight;
  final DateTime createdAt;

  const SignalVote({
    required this.uid,
    required this.outcomeType,
    required this.note,
    this.trustLevel,
    this.weight,
    required this.createdAt,
  });

  factory SignalVote.fromJson(String uid, Map<String, dynamic> json) {
    final trustLevel = (json['trustLevel'] ?? 1).toInt();
    final weight = (json['weight'] ?? _weightForTrustLevel(trustLevel)).toDouble();
    return SignalVote(
      uid: uid,
      outcomeType: json['outcomeType'] ?? '',
      note: json['note'],
      trustLevel: trustLevel,
      weight: weight,
      createdAt: timestampToDate(json['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'outcomeType': outcomeType,
      'note': note,
      if (trustLevel != null) 'trustLevel': trustLevel,
      if (weight != null) 'weight': weight,
      'createdAt': dateToTimestamp(createdAt),
    };
  }
}

double _weightForTrustLevel(int trustLevel) {
  switch (trustLevel) {
    case 2:
      return 2.0;
    case 1:
      return 1.0;
    default:
      return 0.2;
  }
}
