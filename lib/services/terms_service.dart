import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';

class TermsService {
  TermsService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  static const String termsVersion = '2026-01-16';

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<void> acceptTerms() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'Please sign in again to accept terms.',
      );
    }
    final appVersion = await _resolveAppVersion();
    await _firestore.collection('users').doc(user.uid).set({
      'termsAccepted': true,
      'termsAcceptedAt': FieldValue.serverTimestamp(),
      'termsVersion': termsVersion,
      'termsAcceptedAppVersion': appVersion,
    }, SetOptions(merge: true));
  }

  Future<String> _resolveAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.buildNumber.isNotEmpty) {
        return '${info.version}+${info.buildNumber}';
      }
      return info.version;
    } catch (_) {
      return 'unknown';
    }
  }
}
