import '../../../core/utils/firestore_helpers.dart';

class ChatQuota {
  final String memberUid;
  final String traderUid;
  final DateTime? windowStartAt;
  final DateTime? windowEndsAt;
  final int messagesUsed;
  final int charsUsed;
  final DateTime? updatedAt;

  const ChatQuota({
    required this.memberUid,
    required this.traderUid,
    required this.windowStartAt,
    required this.windowEndsAt,
    required this.messagesUsed,
    required this.charsUsed,
    required this.updatedAt,
  });

  factory ChatQuota.fromJson(Map<String, dynamic> json) {
    return ChatQuota(
      memberUid: json['memberUid'] ?? '',
      traderUid: json['traderUid'] ?? '',
      windowStartAt: timestampToDate(json['windowStartAt']),
      windowEndsAt: timestampToDate(json['windowEndsAt']),
      messagesUsed: (json['messagesUsed'] as num?)?.toInt() ?? 0,
      charsUsed: (json['charsUsed'] as num?)?.toInt() ?? 0,
      updatedAt: timestampToDate(json['updatedAt']),
    );
  }
}

class ChatQuotaStatus {
  final DateTime? windowEndsAt;
  final int remainingMessages;
  final int remainingChars;
  final int messagesUsed;
  final int charsUsed;

  const ChatQuotaStatus({
    required this.windowEndsAt,
    required this.remainingMessages,
    required this.remainingChars,
    required this.messagesUsed,
    required this.charsUsed,
  });
}
