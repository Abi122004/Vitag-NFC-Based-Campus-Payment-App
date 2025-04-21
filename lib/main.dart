import 'package:flutter/material.dart';
import 'package:vitag_app/screens/onboarding_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:vitag_app/screens/home_screen.dart';
import 'package:vitag_app/services/auth_service.dart';
import 'package:vitag_app/models/firebase_user_wrapper.dart';
import 'package:vitag_app/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Initialize Firebase with our platform-specific options
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("Firebase initialized successfully");
  } catch (e) {
    print("Failed to initialize Firebase: $e");
    // Proceed with app without Firebase
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VITAG',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _checkInitialAuthState();
  }

  Future<void> _checkInitialAuthState() async {
    // Small delay to ensure Firebase auth is properly initialized
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return StreamBuilder<FirebaseUserWrapper>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        print("Auth state changed: ${snapshot.hasData ? (snapshot.data!.isValid ? 'Valid user' : 'Invalid user') : 'No user'}");
        
        // If we have a connection error, show loading indicator
        if (snapshot.hasError) {
          print("Auth stream error: ${snapshot.error}");
          return const Scaffold(
            body: Center(
              child: Text("Authentication error. Please restart the app."),
            ),
          );
        }
        
        // If the snapshot has user data, then the user is logged in
        if (snapshot.hasData && snapshot.data!.isValid) {
          print("User is authenticated: ${snapshot.data!.uid}");
          return const HomeScreen();
        }
        
        // Otherwise, they're not logged in
        print("User is not authenticated, showing onboarding");
        return const OnboardingScreen();
      },
    );
  }
}
