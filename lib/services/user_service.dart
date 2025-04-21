import 'package:vitag_app/services/auth_service.dart';
import 'package:vitag_app/models/user_details.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class UserService {
  final _authService = AuthService();
  
  // Get current user details
  Future<UserDetails?> getCurrentUserDetails() async {
    try {
      final currentUser = _authService.currentUser;
      if (!currentUser.isValid) {
        return null;
      }
      
      return UserDetails(
        id: currentUser.uid,
        displayName: currentUser.displayName,
        email: currentUser.email,
        photoUrl: currentUser.photoURL,
      );
    } catch (e) {
      print('Error getting user details: $e');
      // Fall back to cached user if available
      return _getCachedUserDetails();
    }
  }
  
  // Cache user details
  Future<void> cacheUserDetails(UserDetails userDetails) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_details', jsonEncode(userDetails.toMap()));
      print('User details cached successfully: ${userDetails.id}');
    } catch (e) {
      print('Error caching user details: $e');
    }
  }
  
  // Get cached user details
  Future<UserDetails?> _getCachedUserDetails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userString = prefs.getString('user_details');
      
      if (userString != null) {
        try {
          final userMap = jsonDecode(userString) as Map<String, dynamic>;
          return UserDetails.fromMap(userMap);
        } catch (e) {
          print('Error parsing cached user details: $e');
          return null;
        }
      }
    } catch (e) {
      print('Error getting cached user details: $e');
    }
    
    return null;
  }
  
  // Handle user result safely
  Future<UserDetails?> handleUserResult(dynamic result) {
    try {
      if (result is Map<String, dynamic>) {
        return Future.value(UserDetails.fromMap(result));
      } else if (result != null) {
        // Create a user details object from basic data
        return Future.value(UserDetails(
          id: result.toString(),
          displayName: 'User',
          email: null,
          photoUrl: null,
        ));
      }
      
      return Future.value(null);
    } catch (e) {
      print('Error handling user result: $e');
      return Future.value(null);
    }
  }
  
  // Clear user data (for logout)
  Future<void> clearUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_details');
      print('User details cleared from cache');
    } catch (e) {
      print('Error clearing user data: $e');
    }
  }
} 