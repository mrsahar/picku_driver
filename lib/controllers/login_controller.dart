import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pick_u_driver/core/global_variables.dart';
import 'package:pick_u_driver/core/sharePref.dart';
import 'package:pick_u_driver/core/unified_signalr_service.dart';
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

      // Debug logging
      print(' SAHAr 🔍 Login Controller: Response received');
      print(' SAHAr 🔍 Login Controller: response.success = ${response.success}');
      print(' SAHAr 🔍 Login Controller: response.message = ${response.message}');
      print(' SAHAr 🔍 Login Controller: response.data = ${response.data}');
      print(' SAHAr 🔍 Login Controller: response.data type = ${response.data.runtimeType}');

      if (response.success && response.data != null) {
        // Ensure response.data is a Map before accessing it
        Map<String, dynamic>? dataMap;
        if (response.data is Map<String, dynamic>) {
          dataMap = response.data as Map<String, dynamic>;
        } else {
          print(' SAHAr ⚠️ Login Controller: response.data is not a Map, it is: ${response.data.runtimeType}');
          Get.snackbar(
            'Error',
            'Invalid response format from server',
            backgroundColor: Colors.red,
            colorText: Colors.white,
            snackPosition: SnackPosition.TOP,
            duration: const Duration(seconds: 3),
          );
          return;
        }

        final message = dataMap['message'] ?? response.message;
        final approvalStatus = dataMap['approvalStatus'];

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
          final dataMap = response.data as Map<String, dynamic>;
          globalVars.setUserEmail(dataMap['email'] ?? emailController.text.trim());
          globalVars.setUserId(dataMap['userId'] ?? ''); // Add userId for rejected/pending users

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
          final dataMap = response.data as Map<String, dynamic>;
          await SharedPrefsService.saveUserDataFromResponse(dataMap);

          final globalVars = GlobalVariables.instance;
          globalVars.setUserEmail(dataMap['email'] ?? emailController.text.trim());
          globalVars.setLoginStatus(true);
          globalVars.setUserToken(dataMap['token'] ?? '');
          globalVars.setUserId(dataMap['userId'] ?? ''); // Add userId for approved users too

          // Approved user - normal login flow
          Get.snackbar(
            'Success',
            'Login successful',
            backgroundColor: Colors.green,
            colorText: Colors.white,
            snackPosition: SnackPosition.TOP,
            duration: const Duration(seconds: 2),
          );

          // Start background service (SignalR + Location) now that token is saved
          try {
            if (Get.isRegistered<UnifiedSignalRService>()) {
              await UnifiedSignalRService.to.startBackgroundServiceIfNeeded();
              print(' SAHAr ✅ Background SignalR service started after login');
            }
          } catch (e) {
            print(' SAHAr ⚠️ Error starting background service after login: $e');
          }

          // Navigate to MainMap for approved users
          Get.offAllNamed(AppRoutes.MainMap);
        }
      } else {
        // Handle API error response
        print(' SAHAr ❌ Login Controller: Login failed');
        print(' SAHAr ❌ Login Controller: success = ${response.success}');
        print(' SAHAr ❌ Login Controller: data = ${response.data}');
        print(' SAHAr ❌ Login Controller: message = ${response.message}');
        
        Get.snackbar(
          'Error',
          response.message.isNotEmpty ? response.message : 'Login failed. Please try again.',
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
                // Start background service (SignalR + Location) for auto-login
                try {
                  if (Get.isRegistered<UnifiedSignalRService>()) {
                    await UnifiedSignalRService.to.startBackgroundServiceIfNeeded();
                    print(' SAHAr ✅ Background SignalR service started after auto-login');
                  }
                } catch (e) {
                  print(' SAHAr ⚠️ Error starting background service after auto-login: $e');
                }
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