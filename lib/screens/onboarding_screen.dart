import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vitag_app/screens/login_screen.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Set system UI overlay style to match background color
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0xFFFFF9F0), // Match scaffold background
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFFFF9F0), // Light creamy background color
      // Remove SafeArea to allow content to extend to the top
      body: Column(
        children: [
          // Stack for overlapping images
          Stack(
            alignment: Alignment.topCenter,
            children: [
              // Main illustration image (behind)
              Container(
                height: screenHeight * 0.65,
                width: screenWidth,
                padding: EdgeInsets.zero,
                child: Transform.scale(
                  scale: 1.15, // Scale up by 15%
                  child: Image.asset(
                    'assets/images/1_st_page.png',
                    fit: BoxFit.fitWidth, // Changed from contain to fitWidth
                  ),
                ),
              ),

              // VIT Logo on top
              Positioned(
                top: -30, // Changed from -15 to -30 to move it higher
                child: Container(
                  height: 200,
                  width: screenWidth,
                  padding: const EdgeInsets.symmetric(
                    vertical: 5,
                    horizontal: 10,
                  ),
                  child: Image.asset(
                    'assets/images/VIT_LOGO.png',
                    fit: BoxFit.fitHeight,
                    errorBuilder: (context, error, stackTrace) {
                      print('Error loading image: $error');
                      return const Center(
                        child: Text(
                          'VIT Logo',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),

          // Content area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Add spacer to push content down less
                  const SizedBox(height: 10),

                  // VITAG text - remove Expanded to move it up
                  const Text(
                    'VITAG',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),

                  // Add flexible spacer that takes less space
                  const Spacer(flex: 1),

                  // Login button closer to the VITAG text
                  Padding(
                    padding: const EdgeInsets.only(bottom: 40.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          // Navigate to login screen
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Login',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
