import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

/// Custom wrapper for Firebase User to avoid Pigeon-related issues
class FirebaseUserWrapper {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoURL;
  final bool isEmailVerified;

  FirebaseUserWrapper({
    required this.uid,
    this.email,
    this.displayName,
    this.photoURL,
    this.isEmailVerified = false,
  });

  /// Create from Firebase User
  factory FirebaseUserWrapper.fromFirebaseUser(firebase_auth.User? user) {
    if (user == null) {
      return FirebaseUserWrapper(
        uid: '',
        email: null,
        displayName: null,
        photoURL: null,
        isEmailVerified: false,
      );
    }
    
    return FirebaseUserWrapper(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoURL: user.photoURL,
      isEmailVerified: user.emailVerified,
    );
  }

  /// Check if this wrapper represents a valid user
  bool get isValid => uid.isNotEmpty;
} 