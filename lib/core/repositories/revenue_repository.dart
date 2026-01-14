import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/revenue_stats.dart';
import '../models/success_payment.dart';

class RevenueRepository {
  RevenueRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _statsDoc =>
      _firestore.collection('revenue_stats').doc('global');

  CollectionReference<Map<String, dynamic>> get _successPayments =>
      _firestore.collection('success_payment');

  Stream<RevenueStats?> watchStats() {
    return _statsDoc.snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return RevenueStats.empty();
      }
      return RevenueStats.fromJson(snapshot.data());
    });
  }

  Stream<List<SuccessPayment>> watchRecentPayments({int limit = 40}) {
    return _successPayments
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SuccessPayment.fromJson(doc.id, doc.data()))
            .toList());
  }
}
