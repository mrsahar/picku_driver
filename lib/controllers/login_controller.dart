import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pick_u_driver/core/global_variables.dart';
import 'package:pick_u_driver/core/sharePref.dart';
import 'package:pick_u_driver/providers/api_provider.dart';
import '../models/login_model.dart';
import '../routes/app_routes.dart';

class LoginController extends GetxController {

  late final TextEditingController emailController;
  late final TextEditingController passwordController;

  // Form key
  final formKey = GlobalKey<FormState>();

  // Loading state
  final isLoading = false.obs;

  // Password visibility
  final isPasswordVisible = false.obs;

  // API Provider
  late final ApiProvider _apiProvider;

  @override
  void onInit() {
    super.onInit();
    // Initialize controllers here
    emailController = TextEditingController();
    passwordController = TextEditingController();
    // Initialize API provider
    _apiProvider = Get.find<ApiProvider>();

    checkAuthenticationStatus();
  }

  @override
  void onClose() {
    // Dispose controllers when controller is destroyed
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }

  // Toggle password visibility
  void togglePasswordVisibility() {
    isPasswordVisible.value = !isPasswordVisible.value;
  }

  // Validation methods
  String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }
    if (!GetUtils.isEmail(value)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  // Get device token
  String getDeviceToken() {
    return "deviceToken_placeholder_${DateTime.now().millisecondsSinceEpoch}";
  }

  // Updated Login method with approval status handling
  Future<void> login(BuildContext context) async {
    // Use formKey.currentState!.validate() instead of manual validation
    if (!formKey.currentState!.validate()) {
      return; // Form validation will show error messages automatically
    }

    try {
      isLoading.value = true;

      final loginRequest = LoginRequest(
        email: emailController.text.trim(),
        password: passwordController.text,
        deviceToken:'',
      );

      print(' SAHAr 📤 Login: Sending request for email: ${emailController.text}');
      final response = await _apiProvider.login(loginRequest);

      if (response.success && response.data != null) {
        final message = response.data['message'] ?? response.message;
        final approvalStatus = response.data['approvalStatus'];

        print(' SAHAr 📊 Login: ApprovalStatus received: $approvalStatus');
        print(' SAHAr 📝 Login: Message received: $message');

        // Check for invalid credentials first
        if (message == "Invalid Credentials") {
          // Show error message and do nothing else
          Get.snackbar(
            'Invalid Credentials',
            'Please check your email and password and try again.',
            backgroundColor: Colors.red,
            colorText: Colors.white,
            snackPosition: SnackPosition.TOP,
            duration: const Duration(seconds: 3),
          );
          return; // Exit early, don't navigate anywhere
        }

        // Clear form only if not invalid credentials
        clearForm();

        // Check approval status and handle accordingly
        if (approvalStatus == "Rejected" || approvalStatus == "Pending") {
          // DO NOT save user data for rejected/pending users
          // Only set temporary global variables for UI purposes
          final globalVars = GlobalVariables.instance;
          globalVars.setUserEmail(response.data['email'] ?? emailController.text.trim());
          globalVars.setUserId(response.data['userId'] ?? ''); // Add userId for rejected/pending users

          // Show status-specific message
          Get.snackbar(
            approvalStatus == "Rejected" ? 'Account Rejected' : 'Account Pending',
            message,
            backgroundColor: approvalStatus == "Rejected" ? Colors.red : Colors.orange,
            colorText: Colors.white,
            snackPosition: SnackPosition.TOP,
            duration: const Duration(seconds: 3),
          );

          // Navigate to verification screen with arguments
          Get.offAllNamed(AppRoutes.VERIFY_MESSAGE, arguments: {
            'status': approvalStatus,
            'message': message,
          });

        } else {
          // ONLY save user data for approved users
          await SharedPrefsService.saveUserDataFromResponse(response.data);

          final globalVars = GlobalVariables.instance;
          globalVars.setUserEmail(response.data['email'] ?? emailController.text.trim());
          globalVars.setLoginStatus(true);
          globalVars.setUserToken(response.data['token']);
          globalVars.setUserId(response.data['userId'] ?? ''); // Add userId for approved users too

          // Approved user - normal login flow
          Get.snackbar(
            'Success',
            'Login successful',
            backgroundColor: Colors.green,
            colorText: Colors.white,
            snackPosition: SnackPosition.TOP,
            duration: const Duration(seconds: 2),
          );

          // Navigate to MainMap for approved users
          Get.offAllNamed(AppRoutes.MainMap);
        }
      } else {
        // Handle API error response
        Get.snackbar(
          'Error',
          response.message,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      print(' SAHAr 💥 Login: Error: $e');
      Get.snackbar(
        'Error',
        'Failed to login. Please try again.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 3),
      );
    } finally {
      isLoading.value = false;
    }
  }

  // Enhanced method to check authentication status with token validation
  Future<void> checkAuthenticationStatus() async {
    try {
      print(' SAHAr 🔍 Checking authentication status...');

      final userData = await SharedPrefsService.getUserData();
      final token = userData['token'];
      final expiresStr = userData['expires'];
      final isLoggedIn = userData['isLoggedIn'];
      final approvalStatus = userData['approvalStatus'];

      if (token != null && token.isNotEmpty && isLoggedIn == 'true') {
        print(' SAHAr ✅ User has login data, checking token expiry...');

        final isTokenExpired = await SharedPrefsService.isTokenExpired();
        final now = DateTime.now();

        if (expiresStr != null) {
          try {
            final expiryDate = DateTime.parse(expiresStr);

            if (!isTokenExpired && now.isBefore(expiryDate)) {
              // Token is valid, check approval status
              final globalVars = GlobalVariables.instance;
              globalVars.setUserToken(token);
              globalVars.setUserEmail(userData['email'] ?? '');
              globalVars.setLoginStatus(true);

              // Navigate based on approval status
              if (approvalStatus == "Rejected" || approvalStatus == "Pending") {
                Get.offAllNamed(AppRoutes.VERIFY_MESSAGE);
              } else {
                Get.offAllNamed(AppRoutes.MainMap);
              }
              return;
            }
          } catch (e) {
            print(' SAHAr 💥 Error parsing expiry date: $e');
          }
        }

        // Token expired
        print(' SAHAr ❌ Token expired, clearing data');
        await SharedPrefsService.clearUserData();

        final globalVars = GlobalVariables.instance;
        globalVars.setLoginStatus(false);
        globalVars.setUserToken('');
        globalVars.setUserEmail('');

        Get.snackbar(
          'Session Expired',
          'Your session has expired. Please login again.',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      print(' SAHAr 💥 Error checking authentication status: $e');
      await SharedPrefsService.clearUserData();
    }
  }

  // Method to manually check login status (for backward compatibility)
  Future<void> checkLoginStatus() async {
    await checkAuthenticationStatus();
  }

  // Method to logout user
  Future<void> logout() async {
    try {
      isLoading.value = true;

      // Clear SharedPreferences
      await SharedPrefsService.clearUserData();

      // Clear GlobalVariables
      final globalVars = GlobalVariables.instance;
      globalVars.setLoginStatus(false);
      globalVars.setUserToken('');
      globalVars.setUserEmail('');

      // Clear form
      clearForm();

      // Navigate to login screen
      Get.offAllNamed(AppRoutes.LOGIN_SCREEN);

      Get.snackbar(
        'Success',
        'Logged out successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
    } catch (e) {
      print(' SAHAr 💥 Logout error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // Clear form
  void clearForm() {
    emailController.clear();
    passwordController.clear();
    isPasswordVisible.value = false;
  }
}
class LoginBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<LoginController>(() => LoginController());
  }
}