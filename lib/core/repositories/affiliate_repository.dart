import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/affiliate.dart';
import '../services/storage_service.dart';

class AffiliateRepository {
  AffiliateRepository({
    FirebaseFirestore? firestore,
    StorageService? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storageService = storage ?? StorageService();

  final FirebaseFirestore _firestore;
  final StorageService _storageService;

  CollectionReference<Map<String, dynamic>> get _affiliates =>
      _firestore.collection('affiliates');

  Stream<List<Affiliate>> watchActive() {
    final query = _affiliates
        .where('isActive', isEqualTo: true)
        .orderBy('isFeatured', descending: true)
        .orderBy('sortOrder');
    return query.snapshots().map(_mapSnapshots);
  }

  Stream<List<Affiliate>> watchAll() {
    final query = _affiliates.orderBy('isActive', descending: true).orderBy('sortOrder');
    return query.snapshots().map(_mapSnapshots);
  }

  Future<String> createAffiliate({
    required Affiliate affiliate,
    File? logoFile,
  }) async {
    final docRef = _affiliates.doc();
    final id = docRef.id;
    final logoUrl = logoFile == null
        ? affiliate.logoUrl
        : await _storageService.uploadAffiliateLogo(id, logoFile);
    final data = affiliate.copyWith(
      id: id,
      logoUrl: logoUrl,
    ).toJson();
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();
    await docRef.set(data);
    return id;
  }

  Future<void> updateAffiliate({
    required Affiliate affiliate,
    File? logoFile,
  }) async {
    final docRef = _affiliates.doc(affiliate.id);
    final logoUrl = logoFile == null
        ? affiliate.logoUrl
        : await _storageService.uploadAffiliateLogo(affiliate.id, logoFile);
    final data = affiliate.copyWith(
      logoUrl: logoUrl,
    ).toJson();
    data['updatedAt'] = FieldValue.serverTimestamp();
    await docRef.update(data);
  }

  Future<void> deleteAffiliate(String id) async {
    await _affiliates.doc(id).delete();
  }

  Future<void> toggleActive(String id, bool value) async {
    await _affiliates.doc(id).update({
      'isActive': value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> toggleFeatured(String id, bool value) async {
    await _affiliates.doc(id).update({
      'isFeatured': value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  List<Affiliate> _mapSnapshots(QuerySnapshot<Map<String, dynamic>> snapshot) {
    return snapshot.docs
        .map((doc) => Affiliate.fromJson(doc.id, doc.data()))
        .toList();
  }
}
