import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/tip.dart';
import '../utils/firestore_helpers.dart';

class TipPage {
  const TipPage({
    required this.tips,
    required this.lastDoc,
    required this.hasMore,
  });

  final List<TraderTip> tips;
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;
  final bool hasMore;
}

class TipEngagementSummary {
  const TipEngagementSummary({
    required this.totalTips,
    required this.totalLikes,
    required this.totalSaves,
  });

  final int totalTips;
  final int totalLikes;
  final int totalSaves;
}

class TipRepository {
  TipRepository({FirebaseFirestore? firestore, FirebaseStorage? storage})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _tips =>
      _firestore.collection('trader_tips');

  String newTipId() => _tips.doc().id;

  Stream<TraderTip?> watchTip(String tipId) {
    return _tips.doc(tipId).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        return null;
      }
      return TraderTip.fromJson(snapshot.id, data);
    });
  }

  Future<TraderTip?> fetchTip(String tipId) async {
    final snapshot = await _tips.doc(tipId).get();
    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }
    return TraderTip.fromJson(snapshot.id, snapshot.data()!);
  }

  Future<void> createTip(TraderTip tip) async {
    final data = tip.toJson();
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _tips.doc(tip.id).set(data, SetOptions(merge: true));
  }

  Stream<TipEngagementSummary> watchTipEngagementSummary({
    required String uid,
  }) {
    return _tips.where('createdBy', isEqualTo: uid).snapshots().map((snapshot) {
      var totalLikes = 0;
      var totalSaves = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        totalLikes += (data['likesCount'] as num?)?.toInt() ?? 0;
        totalSaves += (data['savesCount'] as num?)?.toInt() ?? 0;
      }
      return TipEngagementSummary(
        totalTips: snapshot.docs.length,
        totalLikes: totalLikes,
        totalSaves: totalSaves,
      );
    });
  }

  Future<void> updateTip(String tipId, Map<String, dynamic> data) {
    return _tips.doc(tipId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<DateTime?> fetchLatestTipCreatedAt({required String uid}) async {
    final snapshot = await _tips
        .where('createdBy', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) {
      return null;
    }
    return timestampToDate(snapshot.docs.first.data()['createdAt']);
  }

  Future<void> deleteTip(TraderTip tip) async {
    final docRef = _tips.doc(tip.id);
    await _deleteSubcollection(docRef.collection('likes'));
    await _deleteSubcollection(docRef.collection('saves'));
    await docRef.delete();
    if (tip.imagePath != null && tip.imagePath!.isNotEmpty) {
      await _storage.ref(tip.imagePath).delete();
    }
  }

  Future<TipPage> fetchPublishedTips({
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 12,
  }) {
    final query = _tips
        .where('status', isEqualTo: 'published')
        .orderBy('createdAt', descending: true);
    return _fetchPage(query, startAfter: startAfter, limit: limit);
  }

  Future<TipPage> fetchFeaturedTips({
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 12,
  }) {
    final query = _tips
        .where('status', isEqualTo: 'published')
        .where('isFeatured', isEqualTo: true)
        .orderBy('createdAt', descending: true);
    return _fetchPage(query, startAfter: startAfter, limit: limit);
  }

  Future<TipPage> fetchTypeTips({
    required String type,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 12,
  }) {
    final query = _tips
        .where('status', isEqualTo: 'published')
        .where('type', isEqualTo: type)
        .orderBy('createdAt', descending: true);
    return _fetchPage(query, startAfter: startAfter, limit: limit);
  }

  Future<TipPage> fetchTipsByStatus({
    required String status,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 12,
  }) {
    final query = _tips
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true);
    return _fetchPage(query, startAfter: startAfter, limit: limit);
  }

  Future<TipPage> fetchTipsByStatusForAuthor({
    required String status,
    required String uid,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 12,
  }) {
    final query = _tips
        .where('createdBy', isEqualTo: uid)
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true);
    return _fetchPage(query, startAfter: startAfter, limit: limit);
  }

  Future<List<TraderTip>> fetchLatestTips({
    String? status,
    int limit = 50,
  }) async {
    Query<Map<String, dynamic>> query = _tips.orderBy('createdAt', descending: true);
    if (status != null && status.isNotEmpty) {
      query = query.where('status', isEqualTo: status);
    }
    final snapshot = await query.limit(limit).get();
    return snapshot.docs
        .map((doc) => TraderTip.fromJson(doc.id, doc.data()))
        .toList();
  }

  Stream<bool> watchLikeStatus({
    required String tipId,
    required String uid,
  }) {
    return _tips
        .doc(tipId)
        .collection('likes')
        .doc(uid)
        .snapshots()
        .map((snapshot) => snapshot.exists);
  }

  Stream<bool> watchSaveStatus({
    required String tipId,
    required String uid,
  }) {
    return _tips
        .doc(tipId)
        .collection('saves')
        .doc(uid)
        .snapshots()
        .map((snapshot) => snapshot.exists);
  }

  Future<bool> toggleLike({
    required String tipId,
    required String uid,
  }) {
    return _toggleInteraction(
      tipId: tipId,
      uid: uid,
      subcollection: 'likes',
      counterField: 'likesCount',
    );
  }

  Future<bool> toggleSave({
    required String tipId,
    required String uid,
  }) {
    return _toggleInteraction(
      tipId: tipId,
      uid: uid,
      subcollection: 'saves',
      counterField: 'savesCount',
    );
  }

  Future<bool> _toggleInteraction({
    required String tipId,
    required String uid,
    required String subcollection,
    required String counterField,
  }) async {
    final tipRef = _tips.doc(tipId);
    final interactionRef = tipRef.collection(subcollection).doc(uid);

    return _firestore.runTransaction((tx) async {
      final snapshot = await tx.get(interactionRef);
      if (snapshot.exists) {
        tx.delete(interactionRef);
        tx.update(tipRef, {counterField: FieldValue.increment(-1)});
        return false;
      } else {
        tx.set(interactionRef, {
          'createdAt': FieldValue.serverTimestamp(),
        });
        tx.update(tipRef, {counterField: FieldValue.increment(1)});
        return true;
      }
    });
  }

  Future<TipPage> _fetchPage(
    Query<Map<String, dynamic>> query, {
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 12,
  }) async {
    Query<Map<String, dynamic>> paged = query.limit(limit);
    if (startAfter != null) {
      paged = paged.startAfterDocument(startAfter);
    }
    final snapshot = await paged.get();
    final docs = snapshot.docs;
    return TipPage(
      tips: docs.map((doc) => TraderTip.fromJson(doc.id, doc.data())).toList(),
      lastDoc: docs.isNotEmpty ? docs.last : null,
      hasMore: docs.length == limit,
    );
  }

  Future<void> _deleteSubcollection(
      CollectionReference<Map<String, dynamic>> ref) async {
    final snapshot = await ref.get();
    if (snapshot.docs.isEmpty) {
      return;
    }
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
