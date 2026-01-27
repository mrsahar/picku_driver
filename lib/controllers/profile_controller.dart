import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pick_u_driver/core/sharePref.dart';
import 'package:pick_u_driver/providers/api_provider.dart';
import 'package:pick_u_driver/core/background_tracking_service.dart';
import 'package:pick_u_driver/core/global_variables.dart';

import '../models/user_profile_model.dart';

class ProfileController extends GetxController {
  final ApiProvider _apiProvider = Get.find<ApiProvider>();

  // Observable variables
  var isLoading = true.obs;
  var userProfile = Rxn<UserProfileModel>();
  var profileImage = Rxn<Uint8List>();
  var isImageLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchUserProfile();
  }

  Future<void> fetchUserProfile() async {
    try {
      isLoading.value = true;

      // Get user ID from SharedPreferences
      String? userId = await SharedPrefsService.getUserId();

      if (userId == null) {
        Get.snackbar('Error', 'User ID not found');
        return;
      }

      // API call to get user profile using ApiProvider
      final response = await _apiProvider.postData('/api/Drivers/$userId', {});

      print(' SAHAr Response Status Code: ${response.statusCode}');
      print(' SAHAr Response Body: ${response.body}');

      if (response.statusCode == 200 && response.body != null) {
        userProfile.value = UserProfileModel.fromJson(response.body);

        // Extract and set profile image if available
        if (userProfile.value != null && userProfile.value!.hasProfilePicture) {
          profileImage.value = userProfile.value!.getImageBytes();
          print(' SAHAr Profile image loaded successfully');
        } else {
          profileImage.value = null;
          print(' SAHAr No profile image available');
        }
      } else {
        Get.snackbar('Error', 'Failed to load profile: ${response.statusText ?? 'Unknown error'}');
      }
    } catch (e) {
      print(' SAHAr Exception in fetchUserProfile: ${e.toString()}');
      Get.snackbar('Error', 'Failed to load profile: ${e.toString()}');
    } finally {
      isLoading.value = false;
    }
  }

  // Method to update profile image separately if needed
  void updateProfileImage() {
    if (userProfile.value != null && userProfile.value!.hasProfilePicture) {
      profileImage.value = userProfile.value!.getImageBytes();
    } else {
      profileImage.value = null;
    }
  }

  // Method to check if profile image is available
  bool get hasProfileImage => profileImage.value != null;

  Future<void> logout() async {
    try {
      bool? confirmed = await Get.dialog<bool>(
        AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Get.back(result: true),
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        // Show loading indicator
        Get.dialog(
          const Center(
            child: CircularProgressIndicator(),
          ),
          barrierDismissible: false,
        );

        print(' SAHAr 🚪 Starting logout process...');

        // Step 1: Call logout API with JWT token
        try {
          final response = await _apiProvider.logout();
          print(' SAHAr 📡 Logout API response: ${response.statusCode}');
          
          // Continue logout even if API call fails
          if (response.statusCode != 200 && response.statusCode != 201) {
            print(' SAHAr ⚠️ Logout API warning: ${response.statusText}');
          }
        } catch (e) {
          print(' SAHAr ⚠️ Logout API error (continuing logout): $e');
        }

        // Step 2: Stop background tracking service
        // This will: unsubscribe from rides, stop location updates, disconnect SignalR hub
        try {
          if (Get.isRegistered<BackgroundTrackingService>()) {
            final backgroundService = BackgroundTrackingService.to;
            print(' SAHAr 🛑 Stopping background service...');
            await backgroundService.stopBackgroundService();
            print(' SAHAr ✅ Background service stopped');
          } else {
            print(' SAHAr ⚠️ Background service not registered');
          }
        } catch (e) {
          print(' SAHAr ⚠️ Error stopping background service: $e');
        }

        // Step 3: Clear GlobalVariables token and user data
        try {
          final globalVars = GlobalVariables.instance;
          globalVars.clearUserData();
          print(' SAHAr 🗑️ Global user data cleared');
        } catch (e) {
          print(' SAHAr ⚠️ Error clearing global data: $e');
        }

        // Step 4: Clear user data from SharedPreferences
        await SharedPrefsService.clearUserData();
        print(' SAHAr 🗑️ SharedPreferences cleared');

        // Close loading dialog
        Get.back();

        // Step 5: Navigate to login screen and remove all previous routes
        Get.offAllNamed('/login');

        print(' SAHAr ✅ Logout completed successfully');
        Get.snackbar(
          'Success',
          'Logged out successfully',
          backgroundColor: Colors.green.shade100,
          colorText: Colors.green.shade900,
        );
      }
    } catch (e) {
      // Close loading dialog if it's open
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      
      print(' SAHAr ❌ Logout error: ${e.toString()}');
      Get.snackbar(
        'Error',
        'Failed to logout: ${e.toString()}',
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
      );
    }
  }

  void refreshProfile() {
    fetchUserProfile();
  }
}