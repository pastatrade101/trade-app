import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/stats_summary.dart';
import '../models/user_membership.dart';
import '../models/validator_stats.dart';

class UserRepository {
  UserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  Stream<AppUser?> watchUser(String uid) {
    return _users.doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      return AppUser.fromJson(snapshot.id, snapshot.data()!);
    });
  }

  Future<AppUser?> fetchUser(String uid) async {
    final snapshot = await _users.doc(uid).get();
    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }
    return AppUser.fromJson(snapshot.id, snapshot.data()!);
  }

  Stream<List<AppUser>> watchUsers({int limit = 200}) {
    return _users
        .orderBy('usernameLower', descending: false)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AppUser.fromJson(doc.id, doc.data()))
            .toList());
  }

  Future<bool> isUsernameAvailable(String username) async {
    final normalized = username.toLowerCase();
    final query = await _users
        .where('usernameLower', isEqualTo: normalized)
        .limit(1)
        .get();
    return query.docs.isEmpty;
  }

  Future<void> createUserProfile(AppUser user) {
    return _users.doc(user.uid).set(user.toJson());
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) {
    return _users.doc(uid).update(data);
  }

  Future<void> setUserFields(String uid, Map<String, dynamic> data) {
    return _users.doc(uid).set(data, SetOptions(merge: true));
  }

  Future<void> updateBanner({
    required String uid,
    required String bannerUrl,
    required String bannerPath,
  }) {
    return _users.doc(uid).set({
      'bannerUrl': bannerUrl,
      'bannerPath': bannerPath,
      'bannerUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> clearBanner(String uid) {
    return _users.doc(uid).set({
      'bannerUrl': null,
      'bannerPath': null,
      'bannerUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateSocialLinks({
    required String uid,
    required Map<String, String> socialLinks,
  }) {
    return _users.doc(uid).set({
      'socialLinks': socialLinks,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> saveUserProfile(AppUser user) {
    return _users.doc(user.uid).set(user.toJson(), SetOptions(merge: true));
  }

  Future<void> updatePhoneNumber({
    required String uid,
    required String phoneNumber,
  }) {
    return _users.doc(uid).set({
      'phoneNumber': phoneNumber,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> claimUsername(String usernameLower, String uid) async {
    final normalized = usernameLower.toLowerCase();
    final usernameRef = _firestore.collection('usernames').doc(normalized);
    await _firestore.runTransaction((tx) async {
      final snapshot = await tx.get(usernameRef);
      if (snapshot.exists) {
        final existingUid = snapshot.data()?['uid'];
        if (existingUid != uid) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'already-exists',
            message: 'Username already taken',
          );
        }
      }
      tx.set(usernameRef, {
        'uid': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> savePrivateProfile({
    required String uid,
    required String phoneNumber,
  }) async {
    final docRef = _users.doc(uid).collection('private').doc('profile');
    await docRef.set({
      'phoneNumber': phoneNumber,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> ensureUserDoc(String uid) async {
    final docRef = _users.doc(uid);
    final snapshot = await docRef.get();
    final exists = snapshot.exists;
    final data = snapshot.data();
    final updates = <String, dynamic>{};
    if (!exists || (data?['role'] == null)) {
      updates['role'] = 'member';
    }
    if (!exists || (data?['uid'] == null)) {
      updates['uid'] = uid;
    }
    if (!exists || (data?['createdAt'] == null)) {
      updates['createdAt'] = FieldValue.serverTimestamp();
    }
    if (!exists || (data?['followerCount'] == null)) {
      updates['followerCount'] = 0;
    }
    if (!exists || (data?['followingCount'] == null)) {
      updates['followingCount'] = 0;
    }
    if (!exists || (data?['isBanned'] == null)) {
      updates['isBanned'] = false;
    }
    if (!exists || (data?['traderStatus'] == null)) {
      updates['traderStatus'] = 'none';
    }
    if (!exists || (data?['isVerified'] == null)) {
      updates['isVerified'] = false;
    }
    if (!exists || (data?['updatedAt'] == null)) {
      updates['updatedAt'] = FieldValue.serverTimestamp();
    }
    if (!exists || (data?['socials'] == null)) {
      updates['socials'] = {};
    }
    if (!exists || (data?['socialLinks'] == null)) {
      updates['socialLinks'] = {};
    }
    if (!exists || (data?['statsSummary'] == null)) {
      updates['statsSummary'] = StatsSummary.empty().toJson();
    }
    if (!exists || (data?['validatorStats'] == null)) {
      updates['validatorStats'] = ValidatorStats.empty().toJson();
    }
    if (!exists || (data?['membership'] == null)) {
      updates['membership'] = UserMembership.free().toJson();
    }
    if (updates.isNotEmpty) {
      await docRef.set(updates, SetOptions(merge: true));
    }
  }

  Future<List<AppUser>> fetchLeaderboard({
    required String orderField,
    int limit = 20,
  }) async {
    final fetchLimit = limit < 50 ? 50 : limit;
    final snapshot = await _users
        .where('role', isEqualTo: 'trader')
        .where('traderStatus', isEqualTo: 'active')
        .orderBy(orderField, descending: true)
        .limit(fetchLimit)
        .get();
    final users = snapshot.docs
        .map((doc) => AppUser.fromJson(doc.id, doc.data()))
        .toList();
    users.sort((a, b) {
      final aMetric = _metricValue(orderField, a);
      final bMetric = _metricValue(orderField, b);
      if (aMetric != bMetric) {
        return bMetric.compareTo(aMetric);
      }
      if (a.statsSummary.total90 != b.statsSummary.total90) {
        return b.statsSummary.total90.compareTo(a.statsSummary.total90);
      }
      if (a.followerCount != b.followerCount) {
        return b.followerCount.compareTo(a.followerCount);
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    return users.take(limit).toList();
  }

  Future<List<AppUser>> fetchTraders({
    required String orderField,
    bool descending = true,
    int limit = 50,
  }) async {
    final snapshot = await _users
        .where('role', isEqualTo: 'trader')
        .where('traderStatus', isEqualTo: 'active')
        .orderBy(orderField, descending: descending)
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => AppUser.fromJson(doc.id, doc.data()))
        .toList();
  }

  Stream<List<AppUser>> watchTraderApplicants() {
    return _users
        .where('traderStatus', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AppUser.fromJson(doc.id, doc.data()))
            .toList());
  }

  Future<String?> fetchPrivatePhoneNumber(String uid) async {
    final doc =
        await _users.doc(uid).collection('private').doc('profile').get();
    return doc.data()?['phoneNumber'] as String?;
  }

  Future<void> updateTraderStatus({
    required String uid,
    required String status,
    String? rejectReason,
  }) async {
    final data = {
      'traderStatus': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (rejectReason != null) {
      data['rejectReason'] = rejectReason;
    } else {
      data['rejectReason'] = FieldValue.delete();
    }
    if (status == 'active') {
      data['role'] = 'trader';
    } else if (status == 'rejected') {
      data['role'] = 'member';
    }
    await _users.doc(uid).update(data);
  }
}

double _metricValue(String field, AppUser user) {
  switch (field) {
    case 'statsSummary.reliabilityScore':
      return user.statsSummary.reliabilityScore;
    case 'statsSummary.winRate90':
      return user.statsSummary.winRate90;
    case 'statsSummary.winRate30':
      return user.statsSummary.winRate30;
    default:
      return 0;
  }
}
