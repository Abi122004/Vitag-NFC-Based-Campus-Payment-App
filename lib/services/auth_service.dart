import 'package:vitag_app/services/firebase_auth_service.dart';
import 'package:vitag_app/models/firebase_user_wrapper.dart';

class AuthService {
  final _authService = FirebaseAuthService();

  // Get current user
  FirebaseUserWrapper get currentUser => _authService.currentUser;

  // Auth state changes stream
  Stream<FirebaseUserWrapper> get authStateChanges =>
      _authService.onAuthStateChanged;

  // Sign in with email and password
  Future<FirebaseUserWrapper> signInWithEmailPassword(
    String email,
    String password,
  ) async {
    try {
      final user = await _authService.signInWithEmailAndPassword(
        email,
        password,
      );
      print('Login successful for user: ${user.uid}');
      return user;
    } catch (e) {
      print('Login error in AuthService: $e');
      // Rethrow to let UI handle the error
      rethrow;
    }
  }

  // Register with email and password
  Future<FirebaseUserWrapper> registerWithEmailPassword(
    String email,
    String password,
  ) async {
    try {
      final user = await _authService.createUserWithEmailAndPassword(
        email,
        password,
      );
      print('Registration successful for user: ${user.uid}');
      return user;
    } catch (e) {
      print('Registration error in AuthService: $e');
      // Rethrow to let UI handle the error
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _authService.signOut();
      print('User signed out successfully');
    } catch (e) {
      print('Sign out error in AuthService: $e');
      rethrow;
    }
  }

  // Password reset
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _authService.sendPasswordResetEmail(email);
      print('Password reset email sent to: $email');
    } catch (e) {
      print('Password reset error in AuthService: $e');
      rethrow;
    }
  }

  // Update profile
  Future<void> updateProfile({String? displayName, String? photoURL}) async {
    try {
      await _authService.updateProfile(
        displayName: displayName,
        photoURL: photoURL,
      );
      print('Profile updated successfully');
    } catch (e) {
      print('Profile update error in AuthService: $e');
      rethrow;
    }
  }
}
