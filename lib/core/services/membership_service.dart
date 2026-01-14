import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_membership.dart';

class MembershipService {
  MembershipService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<UserMembership?> watchMembership(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      final data = snapshot.data()!;
      return UserMembership.fromJson(data['membership']);
    });
  }

  Future<UserMembership?> fetchMembership(String uid) async {
    final snapshot = await _firestore.collection('users').doc(uid).get();
    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }
    final data = snapshot.data()!;
    return UserMembership.fromJson(data['membership']);
  }

  bool isPremiumActive(UserMembership? membership, {DateTime? now}) {
    return membership?.isPremiumActive(now: now) ?? false;
  }
}
