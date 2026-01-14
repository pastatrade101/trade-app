import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  if (kDebugMode) {
    debugPrint('FCM background message: ${message.messageId}');
  }
}

class FirebaseBootstrap {
  static Future<void> initialize() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode
          ? AndroidProvider.debug
          : AndroidProvider.playIntegrity,
      appleProvider:
          kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
      webProvider: kIsWeb
          ? ReCaptchaV3Provider('RECAPTCHA_SITE_KEY')
          : null,
    );

    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    if (!kIsWeb) {
      await FirebaseMessaging.instance.requestPermission();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    }
  }
}
