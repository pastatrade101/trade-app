import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/ios_paywall_offer.dart';

class IosPaywallOfferRepository {
  IosPaywallOfferRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<IosPaywallOffer?> watchOffer() {
    return _firestore
        .collection('app_config')
        .doc('ios_paywall_offer')
        .snapshots()
        .map((snapshot) {
      final data = snapshot.data();
      if (data == null) {
        return null;
      }
      try {
        return IosPaywallOffer.fromMap(data);
      } catch (_) {
        return null;
      }
    });
  }
}
