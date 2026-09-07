// Firebase project `testu-learn` (GenAI Labs). Values copied from
// android/app/google-services.json and ios/Runner/GoogleService-Info.plist;
// keep the three in sync when re-downloading from the Firebase console.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Firebase is not configured for web');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return ios;
      default:
        throw UnsupportedError(
          'Firebase is not configured for $defaultTargetPlatform',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDnNWERmfHTryjsjFLvmCutlfcNlgVD8WU',
    appId: '1:207657765804:android:aae12986f0d08c8efbc809',
    messagingSenderId: '207657765804',
    projectId: 'testu-learn',
    storageBucket: 'testu-learn.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD2FcTWaDZ-G2kSUg0gbUfEfGH9wuRonNU',
    appId: '1:207657765804:ios:8a914b2e3a7204c2fbc809',
    messagingSenderId: '207657765804',
    projectId: 'testu-learn',
    storageBucket: 'testu-learn.firebasestorage.app',
    iosBundleId: 'world.eme.genailabs',
  );
}
