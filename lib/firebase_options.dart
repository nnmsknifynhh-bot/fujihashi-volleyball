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
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDu-9CrwWLRbxrNeVBOLlZqcplZc4Ap7YE',
    authDomain: 'fujihashi-volleyball.firebaseapp.com',
    projectId: 'fujihashi-volleyball',
    storageBucket: 'fujihashi-volleyball.firebasestorage.app',
    messagingSenderId: '661489687303',
    appId: '1:661489687303:web:b37993fc682f3533f243a2',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDu-9CrwWLRbxrNeVBOLlZqcplZc4Ap7YE',
    authDomain: 'fujihashi-volleyball.firebaseapp.com',
    projectId: 'fujihashi-volleyball',
    storageBucket: 'fujihashi-volleyball.firebasestorage.app',
    messagingSenderId: '661489687303',
    appId: '1:661489687303:web:b37993fc682f3533f243a2',
  );
}
