import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/signal.dart';
import '../models/signal_premium_details.dart';
import '../models/vote.dart';
import '../models/vote_aggregate.dart';
import '../utils/firestore_guard.dart';

class SignalRepository {
  SignalRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _signals =>
      _firestore.collection('signals');

  CollectionReference<Map<String, dynamic>> _savedSignals(String uid) =>
      _firestore.collection('users').doc(uid).collection('saved_signals');

  CollectionReference<Map<String, dynamic>> _signalLikes(String signalId) =>
      _signals.doc(signalId).collection('likes');

  CollectionReference<Map<String, dynamic>> _signalDislikes(String signalId) =>
      _signals.doc(signalId).collection('dislikes');

  DocumentReference<Map<String, dynamic>> _premiumDetailsDoc(String signalId) =>
      _signals.doc(signalId).collection('premium_details').doc('private');

  Future<String> createSignal(Signal signal) async {
    final doc = _signals.doc();
    final data = signal.toJson();
    data['preview'] = {
      'pair': signal.pair,
      'direction': signal.direction,
      'session': signal.session,
      'createdAt': FieldValue.serverTimestamp(),
      'validUntil': data['validUntil'],
    };
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();
    data.remove('validUntil');
    data.remove('votingOpensAt');
    data.remove('votingClosesAt');
    data['openedAt'] ??= FieldValue.serverTimestamp();
    data['lockVotes'] ??= false;
    if (signal.premiumOnly) {
      final premiumDetails = SignalPremiumDetails(
        entryType: signal.entryType,
        entryPrice: signal.entryPrice,
        entryRange: signal.entryRange,
        stopLoss: signal.stopLoss,
        tp1: signal.tp1,
        tp2: signal.tp2,
        reason: signal.reasoning,
        updatedAt: DateTime.now(),
      );
      data.remove('entryType');
      data.remove('entryPrice');
      data.remove('entryRange');
      data.remove('stopLoss');
      data.remove('tp1');
      data.remove('tp2');
      data.remove('reasoning');
      await doc.set(data);
      final premiumData = premiumDetails.toJson();
      premiumData['createdAt'] = FieldValue.serverTimestamp();
      premiumData['updatedAt'] = FieldValue.serverTimestamp();
      await _premiumDetailsDoc(doc.id).set(premiumData);
    } else {
      await doc.set(data);
    }
    return doc.id;
  }

  Future<void> updateSignal(String id, Map<String, dynamic> data) {
    return _signals.doc(id).update(data);
  }

  Future<Signal?> fetchSignal(String id) async {
    final doc = await _signals.doc(id).get();
    if (!doc.exists || doc.data() == null) {
      return null;
    }
    return Signal.fromJson(doc.id, doc.data()!);
  }

  Stream<Signal?> watchSignal(String id) {
    return guardAuthStream(() {
      return _signals.doc(id).snapshots().map((snapshot) {
        if (!snapshot.exists || snapshot.data() == null) {
          return null;
        }
        return Signal.fromJson(snapshot.id, snapshot.data()!);
      });
    });
  }

  Future<SignalPage> fetchSignalsPage({
    required int limit,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    String? session,
    String? pair,
    String? direction,
    List<String>? followingIds,
  }) async {
    if (followingIds != null) {
      if (followingIds.isEmpty) {
        return const SignalPage(signals: [], lastDoc: null, hasMore: false);
      }
      if (followingIds.length > 10) {
        return _fetchSignalsForManyTraders(
          followingIds: followingIds,
          limit: limit,
          session: session,
          pair: pair,
          direction: direction,
        );
      }
    }

    var query = _buildFilterQuery(session: session, pair: pair, direction: direction)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (followingIds != null) {
      query = query.where('uid', whereIn: followingIds.take(10).toList());
    }

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    final signals = snapshot.docs
        .map((doc) => Signal.fromJson(doc.id, doc.data()))
        .toList();
    final lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
    final hasMore = snapshot.docs.length == limit;
    return SignalPage(signals: signals, lastDoc: lastDoc, hasMore: hasMore);
  }

  Future<List<Signal>> fetchLatestSignals({
    int limit = 50,
    List<String>? statuses,
  }) async {
    Query<Map<String, dynamic>> query =
        _signals.orderBy('createdAt', descending: true);
    if (statuses != null && statuses.isNotEmpty) {
      query = query.where('status', whereIn: statuses);
    }
    final snapshot = await query.limit(limit).get();
    return snapshot.docs
        .map((doc) => Signal.fromJson(doc.id, doc.data()))
        .toList();
  }

  Query<Map<String, dynamic>> _buildFilterQuery({
    String? session,
    String? pair,
    String? direction,
  }) {
    var query = _signals.where('status', whereIn: const [
      'open',
      'voting',
      'resolved',
      'expired',
      'expired_unverified',
    ]);
    if (session != null && session.isNotEmpty) {
      query = query.where('session', isEqualTo: session);
    }
    if (pair != null && pair.isNotEmpty) {
      query = query.where('pair', isEqualTo: pair);
    }
    if (direction != null && direction.isNotEmpty) {
      query = query.where('direction', isEqualTo: direction);
    }
    return query;
  }

  Future<SignalPage> _fetchSignalsForManyTraders({
    required List<String> followingIds,
    required int limit,
    String? session,
    String? pair,
    String? direction,
  }) async {
    final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    final baseQuery = _buildFilterQuery(session: session, pair: pair, direction: direction);

    for (final traderUid in followingIds) {
      final snapshot = await baseQuery
          .where('uid', isEqualTo: traderUid)
          .orderBy('createdAt', descending: true)
          .limit(3)
          .get();
      docs.addAll(snapshot.docs);
    }

    docs.sort((a, b) {
      final aTimestamp = a.data()['createdAt'];
      final bTimestamp = b.data()['createdAt'];
      final aMillis = _timestampToMillis(aTimestamp);
      final bMillis = _timestampToMillis(bTimestamp);
      return bMillis.compareTo(aMillis);
    });

    final limited = docs.take(limit).toList();
    final signals = limited.map((doc) => Signal.fromJson(doc.id, doc.data())).toList();
    return SignalPage(signals: signals, lastDoc: null, hasMore: false);
  }

  int _timestampToMillis(Object? value) {
    if (value is Timestamp) {
      return value.millisecondsSinceEpoch;
    }
    if (value is DateTime) {
      return value.millisecondsSinceEpoch;
    }
    return 0;
  }

  Stream<List<Signal>> watchUserSignals(String uid, {int limit = 10}) {
    return guardAuthStream(() {
      return _signals
          .where('uid', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => Signal.fromJson(doc.id, doc.data()))
              .toList());
    });
  }

  Stream<List<Signal>> watchSignalsByStatus(String status, {int limit = 20}) {
    return guardAuthStream(() {
      return _signals
          .where('status', isEqualTo: status)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => Signal.fromJson(doc.id, doc.data()))
              .toList());
    });
  }

  Stream<bool> watchSignalLikeStatus(String signalId, String uid) {
    return guardAuthStream(() {
      return _signalLikes(signalId)
          .doc(uid)
          .snapshots()
          .map((snapshot) => snapshot.exists);
    });
  }

  Stream<bool> watchSignalDislikeStatus(String signalId, String uid) {
    return guardAuthStream(() {
      return _signalDislikes(signalId)
          .doc(uid)
          .snapshots()
          .map((snapshot) => snapshot.exists);
    });
  }

  Stream<SignalPremiumDetails?> watchPremiumDetails(String signalId) {
    return guardAuthStream(() {
      return _premiumDetailsDoc(signalId).snapshots().map((snapshot) {
        if (!snapshot.exists || snapshot.data() == null) {
          return null;
        }
        return SignalPremiumDetails.fromJson(snapshot.data()!);
      });
    });
  }

  Future<SignalPremiumDetails?> fetchPremiumDetails(String signalId) async {
    final snapshot = await _premiumDetailsDoc(signalId).get();
    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }
    return SignalPremiumDetails.fromJson(snapshot.data()!);
  }

  Future<bool> toggleSignalLike({
    required String signalId,
    required String uid,
  }) {
    return _toggleSignalReaction(
      signalId: signalId,
      uid: uid,
      isLike: true,
    );
  }

  Future<bool> toggleSignalDislike({
    required String signalId,
    required String uid,
  }) {
    return _toggleSignalReaction(
      signalId: signalId,
      uid: uid,
      isLike: false,
    );
  }

  Stream<bool> watchSavedSignal(String uid, String signalId) {
    return guardAuthStream(() {
      return _savedSignals(uid)
          .doc(signalId)
          .snapshots()
          .map((snapshot) => snapshot.exists);
    });
  }

  Stream<List<SavedSignalRef>> watchSavedSignals(
    String uid, {
    int limit = 100,
  }) {
    return guardAuthStream(() {
      return _savedSignals(uid)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => SavedSignalRef.fromJson(doc.id, doc.data()))
                .toList(),
          );
    });
  }

  Future<void> saveSignal({
    required String uid,
    required String signalId,
  }) async {
    await _savedSignals(uid).doc(signalId).set({
      'signalId': signalId,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> removeSavedSignal({
    required String uid,
    required String signalId,
  }) async {
    await _savedSignals(uid).doc(signalId).delete();
  }

  Future<List<Signal>> fetchSignalsByIds(List<String> ids) async {
    if (ids.isEmpty) {
      return const <Signal>[];
    }
    final signals = <Signal>[];
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.skip(i).take(10).toList();
      final snapshot = await _signals
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      signals.addAll(
        snapshot.docs.map((doc) => Signal.fromJson(doc.id, doc.data())),
      );
    }
    return signals;
  }

  Future<VotingSignalsPage> fetchVotingSignals({
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 20,
  }) {
    return fetchVotingSignalsPage(startAfter: startAfter, limit: limit);
  }

  Future<VotingSignalsPage> fetchVotingSignalsPage({
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 20,
  }) async {
    Query<Map<String, dynamic>> query = _signals
        .where('status', isEqualTo: 'voting')
        .orderBy('votingClosesAt')
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    final signals = snapshot.docs
        .map((doc) => Signal.fromJson(doc.id, doc.data()))
        .toList();
    final lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
    final hasMore = snapshot.docs.length == limit;
    return VotingSignalsPage(
      signals: signals,
      lastDoc: lastDoc,
      hasMore: hasMore,
      isFromCache: snapshot.metadata.isFromCache,
    );
  }

  Stream<List<Signal>> watchSignalsByStatuses(
    List<String> statuses, {
    int limit = 20,
  }) {
    return guardAuthStream(() {
      return _signals
          .where('status', whereIn: statuses)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => Signal.fromJson(doc.id, doc.data()))
              .toList());
    });
  }

  Future<void> submitVote({
    required String signalId,
    required SignalVote vote,
  }) async {
    final voteDoc = _signals
        .doc(signalId)
        .collection('votes')
        .doc(vote.uid);
    final data = vote.toJson();
    data['createdAt'] = FieldValue.serverTimestamp();
    await voteDoc.set(data);
  }

  Future<void> submitVoteWithValidation({
    required Signal signal,
    required SignalVote vote,
    required String role,
  }) async {
    _assertVotingAllowed(signal: signal, role: role, voterUid: vote.uid);
    final voteDoc =
        _signals.doc(signal.id).collection('votes').doc(vote.uid);
    final existing = await voteDoc.get();
    if (existing.exists) {
      throw StateError('You already voted on this signal.');
    }
    final data = vote.toJson();
    data['createdAt'] = FieldValue.serverTimestamp();
    await voteDoc.set(data);
  }

  void _assertVotingAllowed({
    required Signal signal,
    required String role,
    required String voterUid,
  }) {
    final normalizedRole = role.toLowerCase();
    if (normalizedRole == 'admin') {
      throw StateError('Admins cannot vote on outcomes.');
    }
    if (normalizedRole != 'member') {
      throw StateError('Only members can vote on outcomes.');
    }
    if (signal.uid == voterUid) {
      throw StateError('You cannot vote on your own signal.');
    }
    if (signal.lockVotes == true) {
      throw StateError('Voting is locked for this signal.');
    }
    if (signal.status == 'resolved') {
      throw StateError('Voting has closed for this signal.');
    }
    if (signal.status == 'expired_unverified') {
      throw StateError('Voting window expired for this signal.');
    }
    if (signal.status != 'voting') {
      throw StateError('Voting is not open for this signal yet.');
    }
    final opensAt = signal.votingOpensAt ?? signal.validUntil;
    final closesAt =
        signal.votingClosesAt ?? opensAt.add(const Duration(hours: 24));
    final now = DateTime.now();
    if (now.isBefore(opensAt)) {
      throw StateError('Voting has not opened yet.');
    }
    if (now.isAfter(closesAt)) {
      throw StateError('Voting has closed for this signal.');
    }
  }

  Stream<VoteAggregate> watchVoteAggregate(String signalId) {
    return guardAuthStream(() {
      return _signals.doc(signalId).snapshots().map((snapshot) {
        if (!snapshot.exists || snapshot.data() == null) {
          return VoteAggregate.empty();
        }
        final data = snapshot.data()!;
        return VoteAggregate.fromJson(data['voteAgg']);
      });
    });
  }

  Stream<SignalVote?> watchUserVote(String signalId, String uid) {
    return guardAuthStream(() {
      return _signals
          .doc(signalId)
          .collection('votes')
          .doc(uid)
          .snapshots()
          .map((snapshot) {
        if (!snapshot.exists || snapshot.data() == null) {
          return null;
        }
        return SignalVote.fromJson(snapshot.id, snapshot.data()!);
      });
    });
  }

  Stream<List<SignalVote>> watchVotes(String signalId, {int limit = 20}) {
    return guardAuthStream(() {
      return _signals
          .doc(signalId)
          .collection('votes')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => SignalVote.fromJson(doc.id, doc.data()))
              .toList());
    });
  }

  Future<bool> _toggleSignalReaction({
    required String signalId,
    required String uid,
    required bool isLike,
  }) async {
    final signalRef = _signals.doc(signalId);
    final likeRef = _signalLikes(signalId).doc(uid);
    final dislikeRef = _signalDislikes(signalId).doc(uid);

    return _firestore.runTransaction((tx) async {
      final signalSnap = await tx.get(signalRef);
      final likeSnap = await tx.get(likeRef);
      final dislikeSnap = await tx.get(dislikeRef);
      final data = signalSnap.data() ?? {};
      var likes = (data['likesCount'] ?? 0).toInt();
      var dislikes = (data['dislikesCount'] ?? 0).toInt();

      if (isLike) {
        if (likeSnap.exists) {
          tx.delete(likeRef);
          likes = (likes - 1).clamp(0, 1 << 31).toInt();
        } else {
          tx.set(likeRef, {'createdAt': FieldValue.serverTimestamp()});
          likes += 1;
          if (dislikeSnap.exists) {
            tx.delete(dislikeRef);
            dislikes = (dislikes - 1).clamp(0, 1 << 31).toInt();
          }
        }
      } else {
        if (dislikeSnap.exists) {
          tx.delete(dislikeRef);
          dislikes = (dislikes - 1).clamp(0, 1 << 31).toInt();
        } else {
          tx.set(dislikeRef, {'createdAt': FieldValue.serverTimestamp()});
          dislikes += 1;
          if (likeSnap.exists) {
            tx.delete(likeRef);
            likes = (likes - 1).clamp(0, 1 << 31).toInt();
          }
        }
      }

      tx.update(signalRef, {
        'likesCount': likes,
        'dislikesCount': dislikes,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return isLike ? !likeSnap.exists : !dislikeSnap.exists;
    });
  }
}

class SignalPage {
  final List<Signal> signals;
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;
  final bool hasMore;

  const SignalPage({
    required this.signals,
    required this.lastDoc,
    required this.hasMore,
  });
}

class VotingSignalsPage {
  final List<Signal> signals;
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;
  final bool hasMore;
  final bool isFromCache;

  const VotingSignalsPage({
    required this.signals,
    required this.lastDoc,
    required this.hasMore,
    required this.isFromCache,
  });
}

class SavedSignalRef {
  const SavedSignalRef({
    required this.signalId,
    required this.createdAt,
  });

  final String signalId;
  final DateTime? createdAt;

  factory SavedSignalRef.fromJson(String id, Map<String, dynamic> data) {
    return SavedSignalRef(
      signalId: data['signalId'] ?? id,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
