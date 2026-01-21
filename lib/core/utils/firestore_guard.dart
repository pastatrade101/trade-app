import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Stream<T> guardAuthStream<T>(Stream<T> Function() build) {
  final auth = FirebaseAuth.instance;
  return auth.authStateChanges().asyncExpand((user) {
    if (user == null) {
      return Stream<T>.empty();
    }
    return build();
  });
}

Stream<T> guardRoleStream<T>({
  required Stream<T> Function() build,
  required Set<String> allowedRoles,
}) {
  final auth = FirebaseAuth.instance;
  return auth.authStateChanges().asyncExpand((user) {
    if (user == null) {
      return Stream<T>.empty();
    }
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .asyncExpand((snapshot) {
      if (!snapshot.exists) {
        return Stream<T>.empty();
      }
      final role = (snapshot.data()?['role'] ?? '').toString().toLowerCase();
      if (role.isEmpty) {
        return Stream<T>.empty();
      }
      if (!allowedRoles.contains(role)) {
        return Stream<T>.error(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
            message: 'Not authorized for this data.',
          ),
        );
      }
      return build();
    });
  });
}
