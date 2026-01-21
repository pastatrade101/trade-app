import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/broker.dart';
import '../services/storage_service.dart';
import '../utils/firestore_guard.dart';

class BrokerRepository {
  BrokerRepository({
    FirebaseFirestore? firestore,
    StorageService? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storageService = storage ?? StorageService();

  final FirebaseFirestore _firestore;
  final StorageService _storageService;

  CollectionReference<Map<String, dynamic>> get _brokers =>
      _firestore.collection('brokers');

  Stream<List<Broker>> watchActive() {
    final query =
        _brokers.where('isActive', isEqualTo: true).orderBy('sortOrder');
    return guardAuthStream(() => query.snapshots().map(_mapSnapshots));
  }

  Stream<List<Broker>> watchAll() {
    final query =
        _brokers.orderBy('isActive', descending: true).orderBy('sortOrder');
    return guardAuthStream(() => query.snapshots().map(_mapSnapshots));
  }

  Future<String> createBroker({
    required Broker broker,
    File? logoFile,
  }) async {
    final docRef = _brokers.doc();
    final id = docRef.id;
    final logoUrl = logoFile == null
        ? broker.logoUrl
        : await _storageService.uploadBrokerLogo(id, logoFile);
    final data = broker.copyWith(id: id, logoUrl: logoUrl).toJson();
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();
    await docRef.set(data);
    return id;
  }

  Future<void> updateBroker({
    required Broker broker,
    File? logoFile,
  }) async {
    final docRef = _brokers.doc(broker.id);
    final logoUrl = logoFile == null
        ? broker.logoUrl
        : await _storageService.uploadBrokerLogo(broker.id, logoFile);
    final data = broker.copyWith(logoUrl: logoUrl).toJson();
    data['updatedAt'] = FieldValue.serverTimestamp();
    await docRef.update(data);
  }

  Future<void> deleteBroker(String id) async {
    await _brokers.doc(id).delete();
  }

  Future<void> toggleActive(String id, bool value) async {
    await _brokers.doc(id).update({
      'isActive': value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  List<Broker> _mapSnapshots(QuerySnapshot<Map<String, dynamic>> snapshot) {
    return snapshot.docs.map((doc) => Broker.fromJson(doc.id, doc.data())).toList();
  }
}
