import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return ios;
      case TargetPlatform.windows:
        return android;
      case TargetPlatform.linux:
        return android;
      default:
        return android;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC-ZKVDsLtNFxFuEM1hQA8i3P-2wOrrWtw',
    appId: '1:370164253057:web:99f5b28f4f8ce408f76880',
    messagingSenderId: '370164253057',
    projectId: 'asset-vista',
    authDomain: 'asset-vista.firebaseapp.com',
    storageBucket: 'asset-vista.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDJpa-zIh7-cZvLWHFVRE4DPWJK3uoxAm0',
    appId: '1:370164253057:android:4c105a87c005467ff76880',
    messagingSenderId: '370164253057',
    projectId: 'asset-vista',
    storageBucket: 'asset-vista.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyANQIhMa4ANwHLQNTUnVHHWFtClvHl_zSo',
    appId: '1:370164253057:ios:bfc5e3ee678acb75f76880',
    messagingSenderId: '370164253057',
    projectId: 'asset-vista',
    storageBucket: 'asset-vista.firebasestorage.app',
    androidClientId: '370164253057-j7fauhb2co050hsmmsgcbfjel6t2b2gs.apps.googleusercontent.com',
    iosClientId: '370164253057-epcn797s5fur942g3o3vfeqbornjonvr.apps.googleusercontent.com',
    iosBundleId: 'com.iqonic.stockinvestment.stockInvestmentFlutter',
  );

}
