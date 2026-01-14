import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class StorageService {
  StorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  Future<String> uploadSignalImage({
    required String uid,
    required File file,
  }) async {
    final ref = _storage
        .ref()
        .child('signals')
        .child(uid)
        .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
    final uploadTask = await ref.putFile(file);
    return uploadTask.ref.getDownloadURL();
  }

  Future<(String url, String path)> uploadTipImage({
    required String uid,
    required String tipId,
    required File file,
  }) async {
    final extension = file.path.split('.').last.toLowerCase();
    final safeExtension = extension.isNotEmpty ? extension : 'jpg';
    final path = 'tips/$uid/$tipId.$safeExtension';
    final ref = _storage.ref().child(path);
    final uploadTask = await ref.putFile(file);
    final url = await uploadTask.ref.getDownloadURL();
    return (url, path);
  }

  Future<(String url, String path)> uploadTestimonialProof({
    required String uid,
    required String testimonialId,
    required File file,
  }) async {
    final extension = file.path.split('.').last.toLowerCase();
    final safeExtension = extension.isNotEmpty ? extension : 'jpg';
    final path = 'testimonials/$uid/$testimonialId.$safeExtension';
    final ref = _storage.ref().child(path);
    final uploadTask = await ref.putFile(file);
    final url = await uploadTask.ref.getDownloadURL();
    return (url, path);
  }

  Future<String> uploadAffiliateLogo(String affiliateId, File file) async {
    final ref = _storage
        .ref()
        .child('affiliates')
        .child(affiliateId)
        .child('logo.jpg');
    final uploadTask = await ref.putFile(file);
    return uploadTask.ref.getDownloadURL();
  }

  Future<String> uploadBrokerLogo(String brokerId, File file) async {
    final ref = _storage
        .ref()
        .child('brokers')
        .child(brokerId)
        .child('logo.jpg');
    final uploadTask = await ref.putFile(file);
    return uploadTask.ref.getDownloadURL();
  }

  Future<String> uploadUserAvatar({
    required String uid,
    required File file,
  }) async {
    final ref = _storage
        .ref()
        .child('avatars')
        .child(uid)
        .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
    final uploadTask = await ref.putFile(file);
    return uploadTask.ref.getDownloadURL();
  }

  Future<(String url, String path)> uploadBanner({
    required String uid,
    required File file,
  }) async {
    final path = 'profile_banners/$uid/banner.jpg';
    final ref = _storage.ref().child(path);
    Uint8List? data;
    try {
      data = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        format: CompressFormat.jpeg,
        quality: 82,
        minWidth: 1600,
        minHeight: 600,
      );
    } catch (_) {
      data = null;
    }
    if (data != null) {
      await ref.putData(
        data,
        SettableMetadata(contentType: 'image/jpeg'),
      );
    } else {
      await ref.putFile(file);
    }
    final url = await ref.getDownloadURL();
    return (url, path);
  }

  Future<void> deletePath(String path) async {
    if (path.isEmpty) {
      return;
    }
    await _storage.ref().child(path).delete();
  }
}
