import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_conversation.dart';
import '../models/chat_message.dart';
import '../models/chat_quota.dart';
import '../../../core/utils/firestore_guard.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository();
});

class ChatRepository {
  ChatRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _conversations =>
      _firestore.collection('conversations');

  Future<String?> resolveTraderUid() async {
    final settingsDoc =
        await _firestore.collection('settings').doc('support').get();
    final fromSettings = settingsDoc.data()?['traderUid'] as String?;
    if (fromSettings != null && fromSettings.trim().isNotEmpty) {
      return fromSettings.trim();
    }

    final snapshot = await _firestore
        .collection('users')
        .where('role', whereIn: ['admin', 'trader'])
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) {
      return null;
    }
    return snapshot.docs.first.id;
  }

  String conversationId(String memberUid, String traderUid) {
    return '${memberUid}_$traderUid';
  }

  Stream<ChatConversation?> watchConversation(String conversationId) {
    return guardAuthStream(() {
      return _conversations.doc(conversationId).snapshots().map((snapshot) {
        if (!snapshot.exists || snapshot.data() == null) {
          return null;
        }
        return ChatConversation.fromJson(snapshot.id, snapshot.data()!);
      });
    });
  }

  Stream<List<ChatConversation>> watchConversations({int limit = 200}) {
    return guardAuthStream(() {
      return _conversations
          .orderBy('updatedAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => ChatConversation.fromJson(doc.id, doc.data()))
              .toList());
    });
  }

  Stream<List<ChatMessage>> watchMessages({
    required String conversationId,
    int limit = 30,
  }) {
    return guardAuthStream(() {
      return _conversations
          .doc(conversationId)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => ChatMessage.fromJson(doc.id, doc.data()))
              .toList());
    });
  }

  Future<ChatQuotaStatus> fetchQuota({required String traderUid}) async {
    final callable = _functions.httpsCallable('getChatQuota');
    final result = await callable.call({'traderUid': traderUid});
    return _parseQuota(result.data);
  }

  Future<ChatQuotaStatus> sendMessage({
    required String traderUid,
    required String text,
    String? clientMessageId,
  }) async {
    final callable = _functions.httpsCallable('sendChatMessage');
    final result = await callable.call({
      'traderUid': traderUid,
      'text': text,
      'clientMessageId': clientMessageId,
    });
    return _parseQuota(result.data);
  }

  Future<void> sendTraderMessage({
    required String memberUid,
    required String text,
  }) async {
    final callable = _functions.httpsCallable('sendTraderMessage');
    await callable.call({
      'memberUid': memberUid,
      'text': text,
    });
  }

  ChatQuotaStatus _parseQuota(dynamic data) {
    if (data is! Map) {
      return const ChatQuotaStatus(
        windowEndsAt: null,
        remainingMessages: 0,
        remainingChars: 0,
        messagesUsed: 0,
        charsUsed: 0,
      );
    }
    final endsAtMillis = (data['windowEndsAt'] as num?)?.toInt();
    return ChatQuotaStatus(
      windowEndsAt:
          endsAtMillis != null ? DateTime.fromMillisecondsSinceEpoch(endsAtMillis) : null,
      remainingMessages: (data['remainingMessages'] as num?)?.toInt() ?? 0,
      remainingChars: (data['remainingChars'] as num?)?.toInt() ?? 0,
      messagesUsed: (data['messagesUsed'] as num?)?.toInt() ?? 0,
      charsUsed: (data['charsUsed'] as num?)?.toInt() ?? 0,
    );
  }
}
