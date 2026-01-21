import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/revenue_stats.dart';
import '../models/payment_intent.dart';
import '../models/success_payment.dart';
import '../utils/firestore_guard.dart';

class RevenueRepository {
  RevenueRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _statsDoc =>
      _firestore.collection('revenue_stats').doc('global');

  CollectionReference<Map<String, dynamic>> get _successPayments =>
      _firestore.collection('success_payment');

  Stream<RevenueStats?> watchStats() {
    return guardRoleStream(
      allowedRoles: {'admin', 'trader_admin'},
      build: () {
        return _statsDoc.snapshots().map((snapshot) {
          if (!snapshot.exists || snapshot.data() == null) {
            return RevenueStats.empty();
          }
          return RevenueStats.fromJson(snapshot.data());
        });
      },
    );
  }

  Stream<List<SuccessPayment>> watchRecentPayments({int limit = 40}) {
    return guardRoleStream(
      allowedRoles: {'admin', 'trader_admin'},
      build: () {
        return _successPayments
            .orderBy('createdAt', descending: true)
            .limit(limit)
            .snapshots()
            .map((snapshot) => snapshot.docs
                .map((doc) => SuccessPayment.fromJson(doc.id, doc.data()))
                .toList());
      },
    );
  }

  Stream<List<PaymentIntent>> watchFailedPaymentIntents({int limit = 200}) {
    return guardRoleStream(
      allowedRoles: {'admin', 'trader_admin'},
      build: () {
        return _firestore
            .collection('payment_intents')
            .where('rawResponse', isNull: true)
            .limit(limit)
            .snapshots()
            .map((snapshot) {
              final items = snapshot.docs
                  .map((doc) => PaymentIntent.fromJson(doc.id, doc.data()))
                  .toList();
              items.sort((a, b) {
                final aTime = a.updatedAt ?? a.createdAt ?? DateTime(1970);
                final bTime = b.updatedAt ?? b.createdAt ?? DateTime(1970);
                return bTime.compareTo(aTime);
              });
              return items;
            });
      },
    );
  }
}
