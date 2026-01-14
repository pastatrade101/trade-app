import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/trading_session_config.dart';

class TradingSessionRepository {
  TradingSessionRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _configDoc {
    return _firestore.collection('config').doc('tradingSessions');
  }

  Stream<TradingSessionConfig> watchConfig() {
    return _configDoc.snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return TradingSessionConfig.fallback();
      }
      return TradingSessionConfig.fromJson(snapshot.data());
    });
  }

  Future<TradingSessionConfig> fetchConfig() async {
    final snapshot = await _configDoc.get();
    if (!snapshot.exists) {
      return TradingSessionConfig.fallback();
    }
    return TradingSessionConfig.fromJson(snapshot.data());
  }

  Future<void> updateConfig(TradingSessionConfig config) {
    return _configDoc.set(
      {
        ...config.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
