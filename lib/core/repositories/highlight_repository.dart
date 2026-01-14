import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/highlight.dart';

class HighlightRepository {
  HighlightRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _highlights =>
      _firestore.collection('highlights');

  Stream<DailyHighlight?> watchHighlightByDate(String dateKey) {
    return _highlights.doc(dateKey).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        return null;
      }
      return DailyHighlight.fromJson(snapshot.id, data);
    });
  }

  Future<DailyHighlight?> fetchHighlightByDate(String dateKey) async {
    final snapshot = await _highlights.doc(dateKey).get();
    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }
    return DailyHighlight.fromJson(snapshot.id, snapshot.data()!);
  }

  Future<void> saveHighlight(DailyHighlight highlight) async {
    final docRef = _highlights.doc(highlight.id);
    final data = highlight.toJson();
    if (highlight.createdAt == null) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }
    data['updatedAt'] = FieldValue.serverTimestamp();
    await docRef.set(data, SetOptions(merge: true));
  }
}
