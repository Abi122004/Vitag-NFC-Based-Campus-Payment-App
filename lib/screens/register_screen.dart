import 'package:flutter/material.dart';
import 'package:vitag_app/screens/home_screen.dart';
import 'package:vitag_app/services/auth_service.dart';
import 'package:vitag_app/services/wallet_service.dart';
import 'package:vitag_app/services/user_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();
  final _walletService = WalletService();
  final _userService = UserService();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    // Validate inputs
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'All fields are required';
      });
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Passwords do not match';
      });
      return;
    }

    if (_passwordController.text.length < 6) {
      setState(() {
        _errorMessage = 'Password must be at least 6 characters';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Keep track if registration was successful
    bool registrationSucceeded = false;
    String userId = '';
    String userEmail = '';

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final name = _nameController.text.trim();

      print("DEBUG: Attempting to register user: $email");

      // Use our custom AuthService for registration
      final user = await _authService.registerWithEmailPassword(
        email,
        password,
      );

      // Remember that we succeeded with registration, even if later steps fail
      registrationSucceeded = true;
      userId = user.uid;
      userEmail = email;

      print(
        "DEBUG: Registration completed - updating profile with name: $name",
      );
      print("DEBUG: User object: ${user.uid}, valid: ${user.isValid}");

      // Update display name
      if (user.isValid) {
        try {
          print("DEBUG: Updating user profile with displayName: $name");
          await _authService.updateProfile(displayName: name);
          print("DEBUG: Created user with name: $name and email: $email");

          // Check if user details were created correctly
          try {
            final userDetails = await _userService.getCurrentUserDetails();
            print("DEBUG: User details after creation: $userDetails");
          } catch (detailsError) {
            print("DEBUG: Error getting user details: $detailsError");
          }

          // Wait briefly to ensure Firebase auth state propagates
          print("DEBUG: Waiting for auth state to propagate");
          await Future.delayed(const Duration(milliseconds: 500));

          // Navigate to home screen - wallet creation will happen there
          if (mounted) {
            print("DEBUG: Navigating to home screen after registration");
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
          }
        } catch (profileError) {
          print("DEBUG: Error updating profile: $profileError");

          if (registrationSucceeded) {
            // If we got here, registration worked but profile update failed
            // We can still continue to home screen since the user is created
            print(
              "DEBUG: Registration succeeded, continuing despite profile error",
            );

            if (mounted) {
              // Show a temporary message about the profile issue
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Account created but profile update failed. You can update your profile later.',
                  ),
                  duration: Duration(seconds: 3),
                ),
              );

              // Navigate to home screen anyway
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              );
            }
          } else {
            setState(() {
              _errorMessage = 'Failed to update user profile: $profileError';
              _isLoading = false;
            });
          }
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to create account';
          _isLoading = false;
          print("DEBUG: Registration failed - user is not valid");
        });
      }
    } catch (e) {
      print("DEBUG: Registration error: $e");
      print("DEBUG: Error type: ${e.runtimeType}");

      // Check if we already registered the user in Firebase despite the error
      if (registrationSucceeded && userId.isNotEmpty) {
        print(
          "DEBUG: Registration succeeded despite error, continuing to home",
        );

        if (mounted) {
          // Let the user know about the issue but continue
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Account created but some features may be limited. Please sign out and back in if you encounter issues.',
              ),
              duration: Duration(seconds: 4),
            ),
          );

          // Navigate to home screen anyway
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
          return;
        }
      }

      String message;
      if (e.toString().contains('weak-password')) {
        message = 'The password is too weak';
      } else if (e.toString().contains('email-already-in-use')) {
        message = 'An account already exists for this email';
      } else if (e.toString().contains('invalid-email')) {
        message = 'Invalid email format';
      } else if (e.toString().contains('PigeonUserDetails') ||
          e.toString().contains('List<Object?>') ||
          e.toString().contains('type cast')) {
        // This is the Pigeon error - the user is likely created in Firebase already
        message =
            'Account created, but there was an issue with user data. Please try logging in.';
        print("DEBUG: Found Pigeon/type cast error, handling specially");
      } else {
        message = 'Registration failed: ${e.toString()}';
      }

      setState(() {
        _errorMessage = message;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'VITAG',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Create a new account to get started',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 40),

              // Name field
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Email field
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Password field
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Confirm Password field
              TextField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                  border: OutlineInputBorder(),
                ),
              ),

              // Error message
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                ),
              ],

              const SizedBox(height: 32),

              // Register button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    disabledBackgroundColor: Colors.grey,
                  ),
                  child:
                      _isLoading
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : const Text(
                            'Create Account',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                ),
              ),

              const SizedBox(height: 16),

              // Already have an account
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Already have an account? Sign in',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
