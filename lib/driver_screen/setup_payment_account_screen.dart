import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pick_u_driver/controllers/driver_onboarding_controller.dart';
import 'package:pick_u_driver/utils/theme/mcolors.dart';
import 'package:pick_u_driver/core/sharePref.dart';

class SetupPaymentAccountScreen extends StatelessWidget {
  const SetupPaymentAccountScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(DriverOnboardingController());
    var isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [Colors.grey[900]!, Colors.grey[800]!]
                : [Colors.blue[50]!, Colors.white],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20), // Add some top spacing
                  // Icon
                  Center(
                    child: Container(
                      height: 120,
                      width: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: MColor.primaryNavy,
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Title
                  Text(
                    'Setup Payment Account',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.grey[800],
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 12),

                  // Description
                  Text(
                    'Connect your payment account to start receiving earnings from rides.',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.grey[300] : Colors.grey[600],
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 24),

                // Info Cards
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.grey[800]?.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'What you\'ll need:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildInfoItem(
                        Icons.account_balance,
                        'Bank account details',
                        isDark,
                      ),
                      _buildInfoItem(
                        Icons.person_outline,
                        'Personal identification',
                        isDark,
                      ),
                      _buildInfoItem(
                        Icons.verified_user_outlined,
                        'Complete verification steps',
                        isDark,
                      ),
                    ],
                  ),
                ),

                  const SizedBox(height: 32),

                  // Setup Button
                  Obx(() => Container(
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        color: MColor.primaryNavy,
                      ),
                      child: ElevatedButton(
                        onPressed: controller.isLoading.value
                            ? null
                            : () async {
                                print('SAHAr: ========================================');
                                print('SAHAr: 🚀 Setup Payment Account Button Clicked');
                                print('SAHAr: ========================================');

                                try {
                                  await controller.startStripeOnboarding();
                                } catch (e) {
                                  print('SAHAr: ❌ Error during onboarding: $e');
                                  Get.snackbar(
                                    'Error',
                                    'Failed to start payment setup. Please check your internet connection and try again.',
                                    backgroundColor: Colors.red,
                                    colorText: Colors.white,
                                    duration: const Duration(seconds: 5),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          disabledBackgroundColor:
                              Colors.grey[400]?.withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        child: controller.isLoading.value
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Setup Payment Account',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    )),

                const SizedBox(height: 12),

                // Skip for now (optional)
                TextButton(
                  onPressed: () {
                    Get.dialog(
                      AlertDialog(
                        title: const Text('Skip Setup?'),
                        content: const Text(
                          'You won\'t be able to receive payments until you complete the setup.\n\nAre you sure you want to skip?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Get.back(),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              Get.back();
                              // Note: This won't actually skip - they need to setup
                              Get.snackbar(
                                'Setup Required',
                                'Payment setup is required to start accepting rides.',
                                backgroundColor: MColor.primaryNavy,
                                colorText: Colors.white,
                                snackPosition: SnackPosition.BOTTOM,
                              );
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: MColor.primaryNavy,
                            ),
                            child: const Text('Skip for Now'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Text(
                    'I\'ll do this later',
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ),

                // Reset button for testing (helps clear old account)
                TextButton(
                  onPressed: () async {
                    Get.dialog(
                      AlertDialog(
                        title: const Text('Reset Stripe Account?'),
                        content: const Text(
                          'This will clear your current Stripe account setup and let you start fresh.\n\nUse this if you\'re having issues with the onboarding process.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Get.back(),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () async {
                              Get.back();
                              // Clear the old Stripe account ID
                              await SharedPrefsService.clearDriverStripeAccountId();
                              Get.snackbar(
                                'Account Reset',
                                'Stripe account cleared. You can now start fresh!\n\nTap "Setup Payment Account" to begin.',
                                backgroundColor: Colors.green,
                                colorText: Colors.white,
                                duration: const Duration(seconds: 5),
                                snackPosition: SnackPosition.BOTTOM,
                              );
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.orange,
                            ),
                            child: const Text('Reset & Start Fresh'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Text(
                    'Having issues? Reset account',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Security note
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 16,
                      color: isDark ? Colors.grey[500] : Colors.grey[500],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Secured by Stripe',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[500] : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20), // Add some bottom spacing
              ],
            ),
          ),
        ),
      ),
      )
    );
  }

  Widget _buildInfoItem(IconData icon, String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 22,
            color: MColor.primaryNavy,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

