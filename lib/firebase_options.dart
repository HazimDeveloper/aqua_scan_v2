// File: firebase_options.dart

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
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
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // Web configuration - keeping as a placeholder, you may need to update this
  // as it's not provided in the google-services.json
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCZraFLMpogWPfcBim5gN8fkR2hCEP1fjY',
    appId: '1:362979220759:web:ca1924deab28b597502b52',
    messagingSenderId: '362979220759',
    projectId: 'waterwatch-43a4e',
    authDomain: 'waterwatch-43a4e.firebaseapp.com',
    storageBucket: 'waterwatch-43a4e.firebasestorage.app',
  );

  // Android configuration updated to match the google-services.json
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCZraFLMpogWPfcBim5gN8fkR2hCEP1fjY',
    appId: '1:362979220759:android:594c9f4500b9017e502b52',
    messagingSenderId: '362979220759',
    projectId: 'waterwatch-43a4e',
    storageBucket: 'waterwatch-43a4e.firebasestorage.app',
    // Updated package name to match google-services.json
  );

  // iOS configuration - keeping as a placeholder
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCZraFLMpogWPfcBim5gN8fkR2hCEP1fjY',
    appId: '1:362979220759:ios:ca1924deab28b597502b52',
    messagingSenderId: '362979220759',
    projectId: 'waterwatch-43a4e',
    storageBucket: 'waterwatch-43a4e.firebasestorage.app',
    iosClientId: 'TO_BE_GENERATED',
    iosBundleId: 'com.example.aquascan',
  );

  // macOS configuration - keeping as a placeholder
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCZraFLMpogWPfcBim5gN8fkR2hCEP1fjY',
    appId: '1:362979220759:macos:ca1924deab28b597502b52',
    messagingSenderId: '362979220759',
    projectId: 'waterwatch-43a4e',
    storageBucket: 'waterwatch-43a4e.firebasestorage.app',
    iosClientId: 'TO_BE_GENERATED',
    iosBundleId: 'com.example.aquascan',
  );
}