import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/testimonial.dart';

class TestimonialRepository {
  TestimonialRepository({FirebaseFirestore? firestore, FirebaseStorage? storage})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _testimonials =>
      _firestore.collection('testimonials');

  String newTestimonialId() => _testimonials.doc().id;

  Stream<List<Testimonial>> watchPublished() {
    return _testimonials
        .where('status', isEqualTo: 'published')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Testimonial.fromJson(doc.id, doc.data()))
            .toList());
  }

  Stream<List<Testimonial>> watchByStatus(String status) {
    return _testimonials
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Testimonial.fromJson(doc.id, doc.data()))
            .toList());
  }

  Stream<List<Testimonial>> watchByAuthor(String uid) {
    return _testimonials
        .where('authorUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Testimonial.fromJson(doc.id, doc.data()))
            .toList());
  }

  Future<void> create(Testimonial testimonial) async {
    final data = testimonial.toJson();
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();
    if (testimonial.status == 'published') {
      data['publishedAt'] = FieldValue.serverTimestamp();
    }
    await _testimonials.doc(testimonial.id).set(data, SetOptions(merge: true));
  }

  Future<void> update(String testimonialId, Map<String, dynamic> data) {
    return _testimonials.doc(testimonialId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateStatus({
    required String testimonialId,
    required String status,
    String? approvedBy,
  }) {
    final data = <String, dynamic>{
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (status == 'published') {
      data['publishedAt'] = FieldValue.serverTimestamp();
      if (approvedBy != null) {
        data['approvedBy'] = approvedBy;
      }
    }
    return _testimonials.doc(testimonialId).update(data);
  }

  Future<void> delete(Testimonial testimonial) async {
    await _testimonials.doc(testimonial.id).delete();
    final path = testimonial.proofImagePath;
    if (path != null && path.isNotEmpty) {
      await _storage.ref(path).delete();
    }
  }
}
