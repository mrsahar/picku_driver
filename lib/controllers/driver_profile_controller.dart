import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pick_u_driver/core/sharePref.dart';
import 'package:pick_u_driver/models/driver_profile_model.dart';
import 'package:pick_u_driver/providers/api_provider.dart';

class DriverProfileController extends GetxController {
  final ApiProvider _apiProvider = Get.find<ApiProvider>();

  // Form key and controllers
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();
  final licenseController = TextEditingController();
  final carPlateController = TextEditingController();
  final carVinController = TextEditingController();
  final carRegistrationController = TextEditingController();
  final carInsuranceController = TextEditingController();
  final sinController = TextEditingController();

  // Observable variables
  var driverProfile = Rx<DriverProfileModel?>(null);
  var isLoading = false.obs;
  var isSubmitting = false.obs;
  var isFetchingProfile = false.obs;

  @override
  void onInit() {
    super.onInit();
    initializeProfile();
  }

  // Initialize profile with driver ID
  Future<void> initializeProfile() async {
    try {
      final driverId = await SharedPrefsService.getUserId();
      if (driverId != null && driverId.isNotEmpty) {
        // Create empty profile with driver ID
        driverProfile.value = DriverProfileModel.empty(driverId);

        // Try to fetch existing profile data
        await fetchDriverProfile();
      } else {
        _showErrorSnackbar('Driver ID not found. Please login again.');
      }
    } catch (e) {
      print(' SAHAr 💥 Error initializing profile: $e');
      _showErrorSnackbar('Error initializing profile');
    }
  }

  // Fetch existing driver profile data
  Future<void> fetchDriverProfile() async {
    try {
      isFetchingProfile.value = true;
      print(' SAHAr 📤 Fetching driver profile...');

      final driverId = await SharedPrefsService.getUserId();
      if (driverId == null) {
        print(' SAHAr 💥 Driver ID not found');
        return;
      }

      // Make API call to get existing profile (adjust endpoint as needed)
      final response = await _apiProvider.getData('/api/Drivers/profile/$driverId');

      print(' SAHAr 🔍 Profile Response Status: ${response.statusCode}');
      print(' SAHAr 🔍 Profile Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final profileData = response.body;

        if (profileData != null) {
          driverProfile.value = DriverProfileModel.fromJson(profileData);
          _populateFormFields();
          print(' SAHAr ✅ Successfully fetched driver profile');
        }
      } else if (response.statusCode == 404) {
        print(' SAHAr ℹ️ No existing profile found, will create new one');
      } else {
        print(' SAHAr 💥 Error fetching profile: ${response.statusCode}');
      }
    } catch (e) {
      print(' SAHAr 💥 Exception while fetching profile: $e');
      // Don't show error for fetching, as profile might not exist yet
    } finally {
      isFetchingProfile.value = false;
    }
  }

  // Populate form fields with existing data
  void _populateFormFields() {
    if (driverProfile.value != null) {
      final profile = driverProfile.value!;
      nameController.text = profile.name;
      phoneController.text = profile.phoneNumber;
      addressController.text = profile.address;
      licenseController.text = profile.licenseNumber;
      carPlateController.text = profile.carLicensePlate;
      carVinController.text = profile.carVin;
      carRegistrationController.text = profile.carRegistration;
      carInsuranceController.text = profile.carInsurance;
      sinController.text = profile.sin;
    }
  }

  // Submit/Update driver profile
  Future<void> updateDriverProfile() async {
    if (!formKey.currentState!.validate()) {
      _showErrorSnackbar('Please fill in all required fields correctly');
      return;
    }

    try {
      isSubmitting.value = true;
      print(' SAHAr 📤 Updating driver profile...');

      final driverId = await SharedPrefsService.getUserId();
      if (driverId == null) {
        _showErrorSnackbar('Driver ID not found. Please login again.');
        return;
      }

      // Prepare request data - ALL VALUES AS STRINGS
      final requestData = <String, String>{
        'id': driverId,
        'name': nameController.text.trim(),                    // Added name field
        'phoneNumber': phoneController.text.trim(),
        'address': addressController.text.trim(),
        'licenseNumber': licenseController.text.trim(),
        'carLicensePlate': carPlateController.text.trim(),
        'carVin': carVinController.text.trim(),
        'carRegistration': carRegistrationController.text.trim(),
        'carInsurance': carInsuranceController.text.trim(),
        'sin': sinController.text.trim(),
      };

      print(' SAHAr 📤 Request data (Map<String, String>): $requestData');

      // Convert to JSON string for verification
      final jsonString = json.encode(requestData);
      print(' SAHAr 📤 JSON string: $jsonString');

      // Make API call to update profile
      final response = await _apiProvider.postData('/api/Drivers/update-profile', requestData);

      print(' SAHAr 🔍 Update Response Status: ${response.statusCode}');
      print(' SAHAr 🔍 Update Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print(' SAHAr ✅ Driver profile updated successfully');
        _showSuccessSnackbar('Profile updated successfully!');
        // // Update local profile data
        // driverProfile.value = DriverProfileModel(
        //   id: driverId,
        //   name: nameController.text.trim(),
        //   phoneNumber: phoneController.text.trim(),
        //   address: addressController.text.trim(),
        //   licenseNumber: licenseController.text.trim(),
        //   carLicensePlate: carPlateController.text.trim(),
        //   carVin: carVinController.text.trim(),
        //   carRegistration: carRegistrationController.text.trim(),
        //   carInsurance: carInsuranceController.text.trim(),
        //   sin: sinController.text.trim(),
        // );
        // // Navigate back or to next screen
        // Get.back(result: {'success': true, 'message': 'Profile updated successfully'});

      } else if (response.statusCode == 400) {
        final errorMessage = response.body?['message'] ?? 'Invalid profile data';
        _showErrorSnackbar(errorMessage);
      } else if (response.statusCode == 401) {
        _showErrorSnackbar('Session expired. Please login again.');
      } else {
        final errorMessage = response.body?['message'] ?? 'Failed to update profile';
        _showErrorSnackbar(errorMessage);
      }

    } catch (e) {
      print(' SAHAr 💥 Exception while updating profile: $e');
      _showErrorSnackbar('Failed to update profile. Please try again.');
    } finally {
      isSubmitting.value = false;
    }
  }

  // Clear all form fields
  void clearForm() {
    nameController.clear();
    phoneController.clear();
    addressController.clear();
    licenseController.clear();
    carPlateController.clear();
    carVinController.clear();
    carRegistrationController.clear();
    carInsuranceController.clear();
    sinController.clear();
  }

  // Validate phone number
  String? validatePhoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    if (value.trim().length < 10) {
      return 'Phone number must be at least 10 digits';
    }
    return null;
  }

  // Validate required field
  String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  // Validate VIN number
  String? validateVin(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'VIN number is required';
    }
    if (value.trim().length != 17) {
      return 'VIN number must be exactly 17 characters';
    }
    return null;
  }

  // Get completion percentage
  double get completionPercentage {
    return driverProfile.value?.completionPercentage ?? 0.0;
  }

  // Check if profile is complete
  bool get isProfileComplete {
    return driverProfile.value?.isComplete ?? false;
  }

  // Helper method to show success snackbar
  void _showSuccessSnackbar(String message) {
    Get.snackbar(
      'Success',
      message,
      backgroundColor: Colors.green,
      colorText: Colors.white,
      snackPosition: SnackPosition.TOP,
      duration: Duration(seconds: 3),
      icon: Icon(Icons.check_circle, color: Colors.white),
    );
  }

  // Helper method to show error snackbar
  void _showErrorSnackbar(String message) {
    Get.snackbar(
      'Error',
      message,
      backgroundColor: Colors.red,
      colorText: Colors.white,
      snackPosition: SnackPosition.TOP,
      duration: Duration(seconds: 3),
      icon: Icon(Icons.error, color: Colors.white),
    );
  }

  @override
  void onClose() {
    // Dispose controllers
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    licenseController.dispose();
    carPlateController.dispose();
    carVinController.dispose();
    carRegistrationController.dispose();
    carInsuranceController.dispose();
    sinController.dispose();
    super.onClose();
  }
}