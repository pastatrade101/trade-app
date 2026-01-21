import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/firestore_guard.dart';

final supportChatRepositoryProvider = Provider<SupportChatRepository>((ref) {
  return SupportChatRepository();
});

class SupportChatRepository {
  SupportChatRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _supportSettingsRef =>
      _firestore.collection('settings').doc('support');

  CollectionReference<Map<String, dynamic>> get _threads =>
      _firestore.collection('support_threads');

  Stream<SupportSettings> watchSupportSettings() {
    return guardAuthStream(() {
      return _supportSettingsRef.snapshots().map((snapshot) {
        return SupportSettings.fromJson(snapshot.data());
      });
    });
  }

  Stream<SupportThread?> watchThread(String uid) {
    return guardAuthStream(() {
      return _threads.doc(uid).snapshots().map((snapshot) {
        if (!snapshot.exists || snapshot.data() == null) {
          return null;
        }
        return SupportThread.fromJson(snapshot.id, snapshot.data()!);
      });
    });
  }

  Stream<List<SupportThread>> watchThreads({int limit = 200}) {
    return guardAuthStream(() {
      return _threads
          .orderBy('lastMessageAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => SupportThread.fromJson(doc.id, doc.data()))
              .toList());
    });
  }

  Stream<SupportMessagePage> watchLatestMessages(
    String uid, {
    int limit = 30,
  }) {
    return guardAuthStream(() {
      return _threads
          .doc(uid)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
        return SupportMessagePage(
          messages: snapshot.docs
              .map((doc) => SupportMessage.fromJson(doc.id, doc.data()))
              .toList(),
          lastDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
        );
      });
    });
  }

  Future<SupportMessagePage> fetchOlderMessages({
    required String uid,
    required QueryDocumentSnapshot<Map<String, dynamic>> startAfter,
    int limit = 30,
  }) async {
    final snapshot = await _threads
        .doc(uid)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .startAfterDocument(startAfter)
        .limit(limit)
        .get();
    return SupportMessagePage(
      messages: snapshot.docs
          .map((doc) => SupportMessage.fromJson(doc.id, doc.data()))
          .toList(),
      lastDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
    );
  }

  Future<void> sendMemberMessage({
    required String uid,
    required String text,
  }) async {
    final threadRef = _threads.doc(uid);
    final messageRef = threadRef.collection('messages').doc();
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }

    await _firestore.runTransaction((transaction) async {
      final threadSnap = await transaction.get(threadRef);
      if (!threadSnap.exists) {
        transaction.set(threadRef, {
          'uid': uid,
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessage': trimmed,
          'lastMessageAt': FieldValue.serverTimestamp(),
          'lastSender': 'member',
          'unreadForTrader': 1,
          'unreadForMember': 0,
          'isBlocked': false,
        });
      } else {
        transaction.update(threadRef, {
          'lastMessage': trimmed,
          'lastMessageAt': FieldValue.serverTimestamp(),
          'lastSender': 'member',
          'unreadForTrader': FieldValue.increment(1),
        });
      }

      transaction.set(messageRef, {
        'senderRole': 'member',
        'senderUid': uid,
        'text': trimmed,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> sendTraderMessage({
    required String threadUid,
    required String senderUid,
    required String text,
  }) async {
    final threadRef = _threads.doc(threadUid);
    final messageRef = threadRef.collection('messages').doc();
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }

    await _firestore.runTransaction((transaction) async {
      final threadSnap = await transaction.get(threadRef);
      if (!threadSnap.exists) {
        transaction.set(threadRef, {
          'uid': threadUid,
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessage': trimmed,
          'lastMessageAt': FieldValue.serverTimestamp(),
          'lastSender': 'trader',
          'unreadForTrader': 0,
          'unreadForMember': 1,
          'isBlocked': false,
        });
      } else {
        transaction.update(threadRef, {
          'lastMessage': trimmed,
          'lastMessageAt': FieldValue.serverTimestamp(),
          'lastSender': 'trader',
          'unreadForMember': FieldValue.increment(1),
        });
      }

      transaction.set(messageRef, {
        'senderRole': 'trader',
        'senderUid': senderUid,
        'text': trimmed,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> markMemberRead(String uid) async {
    await _threads.doc(uid).set({
      'unreadForMember': 0,
    }, SetOptions(merge: true));
  }

  Future<void> markTraderRead(String uid) async {
    await _threads.doc(uid).set({
      'unreadForTrader': 0,
    }, SetOptions(merge: true));
  }

  Future<void> setBlocked(String uid, bool blocked) async {
    await _threads.doc(uid).set({
      'isBlocked': blocked,
    }, SetOptions(merge: true));
  }
}

class SupportSettings {
  final bool isOpen;
  final int openHour;
  final int closeHour;
  final String timezone;
  final String offlineAutoReply;
  final bool premiumOnly;

  const SupportSettings({
    required this.isOpen,
    required this.openHour,
    required this.closeHour,
    required this.timezone,
    required this.offlineAutoReply,
    required this.premiumOnly,
  });

  factory SupportSettings.fromJson(Map<String, dynamic>? json) {
    return SupportSettings(
      isOpen: json?['isOpen'] ?? true,
      openHour: (json?['openHour'] as num?)?.toInt() ?? 9,
      closeHour: (json?['closeHour'] as num?)?.toInt() ?? 18,
      timezone: json?['timezone'] ?? 'Africa/Dar_es_Salaam',
      offlineAutoReply: json?['offlineAutoReply'] ??
          'Support is currently offline. We will reply during office hours.',
      premiumOnly: json?['premiumOnly'] ?? false,
    );
  }

  bool isWithinOfficeHours(DateTime now) {
    final hour = now.hour;
    if (!isOpen) {
      return false;
    }
    if (openHour == closeHour) {
      return true;
    }
    if (openHour < closeHour) {
      return hour >= openHour && hour < closeHour;
    }
    return hour >= openHour || hour < closeHour;
  }
}

class SupportThread {
  final String id;
  final String uid;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final String lastSender;
  final int unreadForTrader;
  final int unreadForMember;
  final bool isBlocked;

  const SupportThread({
    required this.id,
    required this.uid,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.lastSender,
    required this.unreadForTrader,
    required this.unreadForMember,
    required this.isBlocked,
  });

  factory SupportThread.fromJson(String id, Map<String, dynamic> json) {
    return SupportThread(
      id: id,
      uid: json['uid'] ?? id,
      lastMessage: json['lastMessage'] ?? '',
      lastMessageAt: _timestampToDate(json['lastMessageAt']),
      lastSender: json['lastSender'] ?? 'member',
      unreadForTrader: (json['unreadForTrader'] as num?)?.toInt() ?? 0,
      unreadForMember: (json['unreadForMember'] as num?)?.toInt() ?? 0,
      isBlocked: json['isBlocked'] ?? false,
    );
  }
}

class SupportMessage {
  final String id;
  final String senderRole;
  final String senderUid;
  final String text;
  final DateTime? createdAt;

  const SupportMessage({
    required this.id,
    required this.senderRole,
    required this.senderUid,
    required this.text,
    required this.createdAt,
  });

  factory SupportMessage.fromJson(String id, Map<String, dynamic> json) {
    return SupportMessage(
      id: id,
      senderRole: json['senderRole'] ?? 'member',
      senderUid: json['senderUid'] ?? '',
      text: json['text'] ?? '',
      createdAt: _timestampToDate(json['createdAt']),
    );
  }
}

class SupportMessagePage {
  final List<SupportMessage> messages;
  final QueryDocumentSnapshot<Map<String, dynamic>>? lastDoc;

  const SupportMessagePage({
    required this.messages,
    required this.lastDoc,
  });
}

DateTime? _timestampToDate(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  return null;
}
