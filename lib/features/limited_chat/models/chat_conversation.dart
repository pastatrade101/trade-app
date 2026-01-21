import '../../../core/utils/firestore_helpers.dart';

class ChatConversation {
  final String id;
  final String memberUid;
  final String traderUid;
  final String lastMessage;
  final String lastSender;
  final DateTime? updatedAt;

  const ChatConversation({
    required this.id,
    required this.memberUid,
    required this.traderUid,
    required this.lastMessage,
    required this.lastSender,
    required this.updatedAt,
  });

  factory ChatConversation.fromJson(String id, Map<String, dynamic> json) {
    return ChatConversation(
      id: id,
      memberUid: json['memberUid'] ?? '',
      traderUid: json['traderUid'] ?? '',
      lastMessage: json['lastMessage'] ?? '',
      lastSender: json['lastSender'] ?? '',
      updatedAt: timestampToDate(json['updatedAt']),
    );
  }
}
