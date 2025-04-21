import 'package:flutter/material.dart';
import 'package:vitag_app/screens/home_screen.dart';
import 'package:vitag_app/services/auth_service.dart';
import 'package:vitag_app/screens/register_screen.dart';
import 'package:vitag_app/services/wallet_service.dart';
import 'package:vitag_app/services/user_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  final _walletService = WalletService();
  final _userService = UserService();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    // Validate inputs
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Email and password cannot be empty';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Keep track if login was successful
    bool loginSucceeded = false;
    String userId = '';

    try {
      // Authentication using our custom service
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      
      print("DEBUG: Attempting to log in user: $email");
      
      // Use our custom AuthService
      final user = await _authService.signInWithEmailPassword(email, password);
      
      // Remember that login succeeded even if later steps fail
      loginSucceeded = true;
      userId = user.uid;
      
      print("DEBUG: Login completed - User valid: ${user.isValid}");
      
      if (user.isValid) {
        print("DEBUG: Login successful for user: ${user.uid}");
        
        // Wait briefly to ensure Firebase auth state propagates
        await Future.delayed(const Duration(milliseconds: 300));
        
        // Got a valid user credential, now navigate to home screen
        if (mounted) {
          print("DEBUG: Navigating to home screen after login");
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to authenticate user';
          _isLoading = false;
          print("DEBUG: Login failed - user is not valid");
        });
      }
    } catch (e) {
      print("DEBUG: Login error: $e");
      print("DEBUG: Error type: ${e.runtimeType}");
      
      // Check if we already logged in the user in Firebase despite the error
      if (loginSucceeded && userId.isNotEmpty) {
        print("DEBUG: Login succeeded despite error, continuing to home");
        
        if (mounted) {
          // Let the user know about the issue but continue
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Login succeeded but some features may be limited.'),
              duration: Duration(seconds: 3),
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
      if (e.toString().contains('user-not-found')) {
        message = 'No user found with this email';
      } else if (e.toString().contains('wrong-password')) {
        message = 'Incorrect password';
      } else if (e.toString().contains('invalid-email')) {
        message = 'Invalid email format';
      } else if (e.toString().contains('user-disabled')) {
        message = 'This account has been disabled';
      } else if (e.toString().contains('PigeonUserDetails') || 
                e.toString().contains('List<Object?>') ||
                e.toString().contains('type cast')) {
        // This is the Pigeon error - but the user might still be logged in
        message = 'Login succeeded but there was an issue with user data. Some features may be limited.';
        print("DEBUG: Found Pigeon/type cast error, handling specially");
        
        // Try to navigate to home screen anyway
        if (mounted) {
          Future.delayed(const Duration(milliseconds: 500), () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
          });
        }
      } else {
        message = 'Authentication failed: ${e.toString()}';
      }
      
      setState(() {
        _errorMessage = message;
        _isLoading = false;
      });
    }
  }

  void _navigateToRegister() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const RegisterScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Login'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
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
              'Enter your email and password to access your account',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 40),

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

            // Error message
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 14),
              ),
            ],

            const SizedBox(height: 32),

            // Login button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _login,
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
                          'Login',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
              ),
            ),

            const SizedBox(height: 16),

            // Register and forgot password row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _navigateToRegister,
                  child: const Text(
                    'Create Account',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Password reset logic
                    showDialog(
                      context: context,
                      builder: (context) => _buildPasswordResetDialog(),
                    );
                  },
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordResetDialog() {
    final emailController = TextEditingController();
    
    return AlertDialog(
      title: const Text('Reset Password'),
      content: TextField(
        controller: emailController,
        decoration: const InputDecoration(
          labelText: 'Email',
          hintText: 'Enter your email address',
        ),
        keyboardType: TextInputType.emailAddress,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            if (emailController.text.isNotEmpty) {
              try {
                await _authService.sendPasswordResetEmail(emailController.text.trim());
                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password reset email sent'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            }
          },
          child: const Text('Send'),
        ),
      ],
    );
  }
}
