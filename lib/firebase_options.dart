import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

/// Default Firebase options for the app
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    // For Android
    return const FirebaseOptions(
      apiKey: 'AIzaSyCYRm9aN4w-i0yKWRA4Y9FWNqLVYqD0Xw8',
      appId: '1:150043589956:android:10aeef0dc5958f02c0eb11',
      messagingSenderId: '150043589956',
      projectId: 'vitag-c63dd',
    );
  }
} 