import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/auth_service.dart';
import '../../routes/app_routes.dart';
import '../../utils/theme/mcolors.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthenticationStatus();
  }

  /// Check if user is already logged in and redirect to main map
  Future<void> _checkAuthenticationStatus() async {
    final isAuthenticated = await AuthService.isAuthenticated();

    if (isAuthenticated && mounted) {
      // User is logged in, redirect to main map
      Get.offAllNamed(AppRoutes.MainMap);
    }
  }

  @override
  Widget build(BuildContext context) {
    var mediaQuery = MediaQuery.of(context);
    var height = mediaQuery.size.height;
    var width = mediaQuery.size.width;
    var brightness = mediaQuery.platformBrightness;
    final isDarkMode = brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Background with gradient accent
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDarkMode
                    ? [
                  MColor.primaryNavy.withValues(alpha:0.1),
                  Colors.black,
                ]
                    : [
                  MColor.primaryNavy.withValues(alpha:0.05),
                  Colors.white,
                ],
              ),
            ),
          ),

          // Main Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 60),

                  // Logo Section with decoration
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Decorative circle behind logo
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: width * 0.65,
                              height: width * 0.65,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: MColor.primaryNavy.withValues(alpha:0.08),
                              ),
                            ),
                            Container(
                              width: width * 0.5,
                              height: width * 0.5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: MColor.primaryNavy.withValues(alpha:0.12),
                              ),
                            ),
                            Image(
                              image: isDarkMode
                                  ? const AssetImage("assets/img/only_logo.png")
                                  : const AssetImage("assets/img/logo.png"),
                              height: height * 0.25,
                            ),
                          ],
                        ),

                        const SizedBox(height: 50),

                        // Welcome Text
                        Text(
                          "Welcome Aboard!",
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: MColor.primaryNavy,
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 16),

                        // Subtitle
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            "Start your journey as a professional driver and connect with riders",
                            style: TextStyle(
                              fontSize: 16,
                              color: isDarkMode
                                  ? Colors.grey[400]
                                  : Colors.grey[700],
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom Section with Buttons
                  Column(
                    children: [
                      // Sign Up Button (Primary Action)
                      Container(
                        width: double.infinity,
                        height: 58,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: MColor.primaryNavy.withValues(alpha:0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            Get.toNamed(AppRoutes.SIGNUP_SCREEN);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: MColor.primaryNavy,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            "Get Started",
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Login Button (Secondary Action)
                      SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: OutlinedButton(
                          onPressed: () {
                            //Get.to(() => const LoginScreen());
                            Get.toNamed(AppRoutes.LOGIN_SCREEN);
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: MColor.primaryNavy.withValues(alpha:0.3),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            foregroundColor: MColor.primaryNavy,
                          ),
                          child: const Text(
                            "I Already Have an Account",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Terms and Privacy
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode
                                  ? Colors.grey[600]
                                  : Colors.grey[500],
                              height: 1.4,
                            ),
                            children: [
                              const TextSpan(
                                text: "By continuing, you agree to our ",
                              ),
                              TextSpan(
                                text: "Terms of Service",
                                style: TextStyle(
                                  color: MColor.primaryNavy,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const TextSpan(text: " and "),
                              TextSpan(
                                text: "Privacy Policy",
                                style: TextStyle(
                                  color: MColor.primaryNavy,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),
                    ],
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