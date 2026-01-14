import '../utils/firestore_helpers.dart';

class UserMembership {
  final String tier;
  final String status;
  final DateTime? startedAt;
  final DateTime? expiresAt;
  final String? lastPaymentRef;
  final DateTime? updatedAt;

  const UserMembership({
    required this.tier,
    required this.status,
    required this.startedAt,
    required this.expiresAt,
    required this.lastPaymentRef,
    required this.updatedAt,
  });

  factory UserMembership.free() {
    return const UserMembership(
      tier: 'free',
      status: 'inactive',
      startedAt: null,
      expiresAt: null,
      lastPaymentRef: null,
      updatedAt: null,
    );
  }

  factory UserMembership.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return UserMembership.free();
    }
    return UserMembership(
      tier: json['tier'] ?? 'free',
      status: json['status'] ?? 'inactive',
      startedAt: timestampToDate(json['startedAt']),
      expiresAt: timestampToDate(json['expiresAt']),
      lastPaymentRef: json['lastPaymentRef'],
      updatedAt: timestampToDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tier': tier,
      'status': status,
      'startedAt': dateToTimestamp(startedAt),
      'expiresAt': dateToTimestamp(expiresAt),
      'lastPaymentRef': lastPaymentRef,
      'updatedAt': dateToTimestamp(updatedAt),
    };
  }

  bool isPremiumActive({DateTime? now}) {
    final current = now ?? DateTime.now();
    return tier == 'premium' &&
        status == 'active' &&
        expiresAt != null &&
        expiresAt!.isAfter(current);
  }
}
