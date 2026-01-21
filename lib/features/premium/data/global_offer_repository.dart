import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/global_offer.dart';

class GlobalOfferRepository {
  GlobalOfferRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<GlobalOffer?> watchActiveOffer() {
    return _firestore
        .collection('app_config')
        .doc('global_offer')
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data();
          if (data == null) {
            return null;
          }
          try {
            final offer = GlobalOffer.fromMap(data);
            return offer.isCurrentlyActive ? offer : null;
          } catch (_) {
            return null;
          }
        });
  }

  Stream<GlobalOffer?> watchOfferConfig() {
    return _firestore
        .collection('app_config')
        .doc('global_offer')
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data();
          if (data == null) {
            return null;
          }
          try {
            return GlobalOffer.fromMap(data);
          } catch (_) {
            return null;
          }
        });
  }

  Future<void> setOffer(Map<String, dynamic> data) {
    final sanitized = Map<String, dynamic>.from(data);
    sanitized['updatedAt'] = FieldValue.serverTimestamp();
    return _firestore.collection('app_config').doc('global_offer').set(sanitized);
  }
}
