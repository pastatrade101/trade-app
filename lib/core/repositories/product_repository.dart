import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product.dart';
import '../utils/firestore_guard.dart';

class ProductRepository {
  ProductRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _productDoc(String id) {
    return _firestore.collection('products').doc(id);
  }

  Stream<Product?> watchProduct(String id) {
    return guardAuthStream(() {
      return _productDoc(id).snapshots().map((snapshot) {
        if (!snapshot.exists || snapshot.data() == null) {
          return null;
        }
        return Product.fromJson(snapshot.id, snapshot.data()!);
      });
    });
  }

  Stream<List<Product>> watchProductsByIds(List<String> ids) {
    if (ids.isEmpty) {
      return Stream.value(const []);
    }
    return guardAuthStream(() {
      return _firestore
          .collection('products')
          .where(FieldPath.documentId, whereIn: ids)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => Product.fromJson(doc.id, doc.data()))
              .toList());
    });
  }

  Future<Product?> fetchProduct(String id) async {
    final snapshot = await _productDoc(id).get();
    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }
    return Product.fromJson(snapshot.id, snapshot.data()!);
  }

  Future<void> upsertProduct(Product product) async {
    await _productDoc(product.id).set({
      ...product.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
