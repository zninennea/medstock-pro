// lib/firebase_options.dart
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

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
        return macos;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA0iVxt9xEiHRZ1bbEBq3w1oI2VWjGAcks',
    appId: '1:342691394234:web:e65f1bc5816b08ea8a8883',
    messagingSenderId: '342691394234',
    projectId: 'medstock-fa87e',
    authDomain: 'medstock-fa87e.firebaseapp.com',
    storageBucket: 'medstock-fa87e.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA0iVxt9xEiHRZ1bbEBq3w1oI2VWjGAcks',
    appId: '1:342691394234:android:your_android_app_id',
    messagingSenderId: '342691394234',
    projectId: 'medstock-fa87e',
    storageBucket: 'medstock-fa87e.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA0iVxt9xEiHRZ1bbEBq3w1oI2VWjGAcks',
    appId: '1:342691394234:ios:your_ios_app_id',
    messagingSenderId: '342691394234',
    projectId: 'medstock-fa87e',
    storageBucket: 'medstock-fa87e.firebasestorage.app',
    iosClientId: 'YOUR_IOS_CLIENT_ID',
    iosBundleId: 'com.medstock.pro',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyA0iVxt9xEiHRZ1bbEBq3w1oI2VWjGAcks',
    appId: '1:342691394234:macos:your_macos_app_id',
    messagingSenderId: '342691394234',
    projectId: 'medstock-fa87e',
    storageBucket: 'medstock-fa87e.firebasestorage.app',
  );
}
