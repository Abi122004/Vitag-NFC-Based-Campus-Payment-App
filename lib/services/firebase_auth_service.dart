import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:vitag_app/models/firebase_user_wrapper.dart';
import 'dart:async';

/// Custom Firebase Auth Service to avoid Pigeon dependency issues
class FirebaseAuthService {
  final firebase_auth.FirebaseAuth _instance = firebase_auth.FirebaseAuth.instance;
  
  // Internal stream controller to transform Firebase auth state changes
  final StreamController<FirebaseUserWrapper> _userStreamController = 
      StreamController<FirebaseUserWrapper>.broadcast();
  
  FirebaseAuthService() {
    // Subscribe to Firebase auth state changes and transform them
    _instance.authStateChanges().listen((firebase_auth.User? user) {
      final wrapper = FirebaseUserWrapper.fromFirebaseUser(user);
      print("Auth state changed: User ${wrapper.isValid ? 'logged in' : 'logged out'}");
      _userStreamController.add(wrapper);
    });
  }
  
  /// Get current user as our custom wrapper
  FirebaseUserWrapper get currentUser {
    final user = _instance.currentUser;
    return FirebaseUserWrapper.fromFirebaseUser(user);
  }
  
  /// Stream of auth state changes using our custom wrapper
  Stream<FirebaseUserWrapper> get onAuthStateChanged {
    // First emit the current state, then listen for changes
    Future.microtask(() {
      final currentUserWrapper = FirebaseUserWrapper.fromFirebaseUser(_instance.currentUser);
      _userStreamController.add(currentUserWrapper);
    });
    return _userStreamController.stream;
  }
  
  /// Sign in with email and password
  Future<FirebaseUserWrapper> signInWithEmailAndPassword(String email, String password) async {
    try {
      final result = await _instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Force emit the auth state to the stream
      final wrapper = FirebaseUserWrapper.fromFirebaseUser(result.user);
      _userStreamController.add(wrapper);
      
      return wrapper;
    } catch (e) {
      print('SignIn error: $e');
      rethrow;
    }
  }
  
  /// Create new user with email and password
  Future<FirebaseUserWrapper> createUserWithEmailAndPassword(String email, String password) async {
    try {
      final result = await _instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Force emit the auth state to the stream
      final wrapper = FirebaseUserWrapper.fromFirebaseUser(result.user);
      _userStreamController.add(wrapper);
      
      return wrapper;
    } catch (e) {
      print('Create user error: $e');
      rethrow;
    }
  }
  
  /// Update user profile
  Future<void> updateProfile({String? displayName, String? photoURL}) async {
    try {
      final user = _instance.currentUser;
      if (user != null) {
        await user.updateDisplayName(displayName);
        if (photoURL != null) {
          await user.updatePhotoURL(photoURL);
        }
        
        // Emit updated user state
        _userStreamController.add(FirebaseUserWrapper.fromFirebaseUser(user));
      }
    } catch (e) {
      print('Update profile error: $e');
      rethrow;
    }
  }
  
  /// Sign out
  Future<void> signOut() async {
    try {
      await _instance.signOut();
      // The authStateChanges listener will handle emitting the logged out state
    } catch (e) {
      print('Sign out error: $e');
      rethrow;
    }
  }
  
  /// Reset password
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _instance.sendPasswordResetEmail(email: email);
    } catch (e) {
      print('Password reset error: $e');
      rethrow;
    }
  }
  
  /// Dispose resources
  void dispose() {
    _userStreamController.close();
  }
} 