import '../../../core/utils/firestore_helpers.dart';

enum MessageStatus { sending, sent, failed }

class ChatMessage {
  final String id;
  final String senderUid;
  final String senderRole;
  final String text;
  final int charCount;
  final DateTime? createdAt;
  final String? clientMessageId;
  final MessageStatus status;

  const ChatMessage({
    required this.id,
    required this.senderUid,
    required this.senderRole,
    required this.text,
    required this.charCount,
    required this.createdAt,
    required this.clientMessageId,
    required this.status,
  });

  factory ChatMessage.fromJson(String id, Map<String, dynamic> json) {
    return ChatMessage(
      id: id,
      senderUid: json['senderUid'] ?? '',
      senderRole: json['senderRole'] ?? 'member',
      text: json['text'] ?? '',
      charCount: (json['charCount'] as num?)?.toInt() ?? 0,
      createdAt: timestampToDate(json['createdAt']),
      clientMessageId: json['clientMessageId'] as String?,
      status: MessageStatus.sent,
    );
  }

  factory ChatMessage.optimistic({
    required String clientMessageId,
    required String senderUid,
    required String senderRole,
    required String text,
    required int charCount,
  }) {
    return ChatMessage(
      id: clientMessageId,
      senderUid: senderUid,
      senderRole: senderRole,
      text: text,
      charCount: charCount,
      createdAt: DateTime.now(),
      clientMessageId: clientMessageId,
      status: MessageStatus.sending,
    );
  }

  ChatMessage copyWith({
    MessageStatus? status,
    DateTime? createdAt,
  }) {
    return ChatMessage(
      id: id,
      senderUid: senderUid,
      senderRole: senderRole,
      text: text,
      charCount: charCount,
      createdAt: createdAt ?? this.createdAt,
      clientMessageId: clientMessageId,
      status: status ?? this.status,
    );
  }
}
