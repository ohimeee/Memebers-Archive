import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web is not configured for this mobile MVP.');
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('This platform is not supported.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB_tCUqkKe6EtWnEbeMcuDBzdTgnASpxxw',
    appId: '1:558884624969:android:3ed44edcef159a88bf3d98',
    messagingSenderId: '558884624969',
    projectId: 'memebers-87d7b',
    storageBucket: 'memebers-87d7b.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAH-A-1EQTq4mm9cDWxKsTo9yw0fmelsXY',
    appId: '1:558884624969:ios:0ffb8468334559e2bf3d98',
    messagingSenderId: '558884624969',
    projectId: 'memebers-87d7b',
    storageBucket: 'memebers-87d7b.firebasestorage.app',
    iosClientId:
        '558884624969-l7445lmgtlbh1q2dg1jd9t91aj3stknc.apps.googleusercontent.com',
    iosBundleId: 'com.barkada.memories.barkadaGallery',
  );
}
