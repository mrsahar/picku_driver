import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pick_u_driver/core/sharePref.dart';
import 'package:pick_u_driver/models/shift_model.dart';
import 'package:pick_u_driver/providers/api_provider.dart';

import '../models/shift_application_model.dart';

class ShiftApplicationController extends GetxController {
  final ApiProvider _apiProvider = Get.find<ApiProvider>();

  // Observable variables
  var availableShifts = <ShiftModel>[].obs;
  var appliedShifts = <ShiftApplicationModel>[].obs;
  var selectedShift = ''.obs;
  var isLoading = false.obs;
  var isSubmitting = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchShiftsData();
  }

  // Fetch both available shifts and applied shifts
  Future<void> fetchShiftsData() async {
    await Future.wait([
      fetchAvailableShifts(),
      fetchAppliedShifts(),
    ]);
  }

  // Fetch available shifts from API (using POST as required by your API)
  Future<void> fetchAvailableShifts() async {
    try {
      isLoading.value = true;
      print(' SAHAr 📤 Fetching available shifts...');

      // Your API requires POST request, not GET
      final response = await _apiProvider.postData('/api/Shift/get-active-shifts', {});

      print(' SAHAr 🔍 Response Status Code: ${response.statusCode}');
      print(' SAHAr 🔍 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseBody = response.body;

        // Handle different response formats
        List<dynamic> shiftsData;
        if (responseBody is List) {
          shiftsData = responseBody;
        } else if (responseBody is Map && responseBody['data'] != null) {
          shiftsData = responseBody['data'];
        } else if (responseBody is Map && responseBody.containsKey('shifts')) {
          shiftsData = responseBody['shifts'];
        } else {
          print(' SAHAr 💥 Unexpected response format: ${responseBody.runtimeType}');
          _showErrorSnackbar('Unexpected response format from server');
          return;
        }

        // Convert JSON to ShiftModel objects
        availableShifts.value = shiftsData
            .map((json) => ShiftModel.fromJson(json))
            .toList();

        print(' SAHAr ✅ Successfully fetched ${availableShifts.length} shifts');
      } else {
        print(' SAHAr 💥 Error fetching shifts: ${response.statusCode}');
        print(' SAHAr 💥 Error body: ${response.body}');
        _showErrorSnackbar('Failed to fetch available shifts. Status: ${response.statusCode}');
      }
    } catch (e) {
      print(' SAHAr 💥 Exception while fetching shifts: $e');
      _showErrorSnackbar('Failed to load shifts. Please try again.');
    } finally {
      isLoading.value = false;
    }
  }

  // Fetch applied shifts from API
  Future<void> fetchAppliedShifts() async {
    try {
      print(' SAHAr 📤 Fetching applied shifts...');

      // Get driver ID (user ID) for the URL parameter
      final driverId = await SharedPrefsService.getUserId();

      if (driverId == null || driverId.isEmpty) {
        print(' SAHAr 💥 Driver ID not found, cannot fetch applied shifts');
        return;
      }

      print(' SAHAr 🔍 Driver ID for applied shifts: $driverId');

      // Make POST request with driver ID as URL parameter
      final endpoint = '/api/Shift/get-driver-applied-shifts?Id=$driverId';
      final response = await _apiProvider.postData(endpoint, {});

      print(' SAHAr 🔍 Applied Shifts Response Status: ${response.statusCode}');
      print(' SAHAr 🔍 Applied Shifts Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseBody = response.body;

        // Handle different response formats
        List<dynamic> appliedShiftsData;
        if (responseBody is List) {
          appliedShiftsData = responseBody;
        } else if (responseBody is Map && responseBody['data'] != null) {
          appliedShiftsData = responseBody['data'];
        } else {
          print(' SAHAr 💥 Unexpected applied shifts response format: ${responseBody.runtimeType}');
          return;
        }

        // Convert to ShiftApplicationModel objects
        appliedShifts.value = appliedShiftsData
            .map((json) => ShiftApplicationModel.fromJson(json))
            .toList();

        print(' SAHAr ✅ Successfully fetched ${appliedShifts.length} applied shifts');

        // Debug: Print applied shift IDs and statuses
        for (var app in appliedShifts) {
          print(' SAHAr 🔍 Applied Shift: ${app.shiftId} - Status: ${app.status}');
        }

      } else {
        print(' SAHAr 💥 Error fetching applied shifts: ${response.statusCode}');
      }
    } catch (e) {
      print(' SAHAr 💥 Exception while fetching applied shifts: $e');
    }
  }

  // Select a shift
  void selectShift(String shiftId) {
    selectedShift.value = shiftId;
    print(' SAHAr 🎯 Selected shift: $shiftId');
  }

  // Submit shift application
  Future<void> submitApplication() async {
    if (selectedShift.value.isEmpty) {
      _showErrorSnackbar('Please select a shift first');
      return;
    }

    try {
      isSubmitting.value = true;
      print(' SAHAr 📤 Submitting shift application for: ${selectedShift.value}');

      // Get user ID from SharedPreferences (userId = driverId)
      final driverId = await SharedPrefsService.getUserId();

      if (driverId == null || driverId.isEmpty) {
        print(' SAHAr 💥 User ID (Driver ID) not found in SharedPreferences');
        _showErrorSnackbar('User ID not found. Please login again.');
        return;
      }

      print(' SAHAr 🔍 Driver ID (User ID): $driverId');
      print(' SAHAr 🔍 Shift ID: ${selectedShift.value}');

      // Prepare request data as required by your API
      final requestData = {
        'shiftId': selectedShift.value,
        'driverId': driverId,
      };

      print(' SAHAr 📤 Request body: $requestData');

      // Make API call to /api/Shift/apply
      final response = await _apiProvider.postData('/api/Shift/apply', requestData);

      print(' SAHAr 🔍 Application Response Status: ${response.statusCode}');
      print(' SAHAr 🔍 Application Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print(' SAHAr ✅ Shift application submitted successfully');

        // Get selected shift details for success message
        final selectedShiftDetails = availableShifts.firstWhere(
              (shift) => shift.shiftId == selectedShift.value,
          orElse: () => availableShifts.first,
        );

        _showSuccessSnackbar(
            'Application submitted for ${selectedShiftDetails.title} (${selectedShiftDetails.formattedTime})'
        );

        // Navigate back to previous page and refresh applied shifts
        Get.back(result: {
          'success': true,
          'shiftId': selectedShift.value,
          'message': 'Shift application submitted successfully'
        });

        // Refresh applied shifts to show the new application
        await fetchAppliedShifts();

      } else if (response.statusCode == 400) {
        // Handle validation errors
        final errorMessage = response.body?['message'] ??
            response.body?['error'] ??
            'Invalid request data';
        print(' SAHAr 💥 Validation error: $errorMessage');
        _showErrorSnackbar(errorMessage);

      } else if (response.statusCode == 409) {
        // Handle conflict (e.g., already applied for this shift)
        final errorMessage = response.body?['message'] ??
            'You have already applied for this shift';
        print(' SAHAr 💥 Conflict error: $errorMessage');
        _showErrorSnackbar(errorMessage);

      } else if (response.statusCode == 401) {
        print(' SAHAr 🔐 Authentication error');
        _showErrorSnackbar('Session expired. Please login again.');
        // Navigate to login
        // Get.offAllNamed(AppRoutes.login);

      } else {
        print(' SAHAr 💥 Error submitting application: ${response.statusCode}');
        final errorMessage = response.body?['message'] ??
            'Failed to submit application';
        _showErrorSnackbar(errorMessage);
      }

    } catch (e) {
      print(' SAHAr 💥 Exception while submitting application: $e');
      _showErrorSnackbar('Failed to submit application. Please try again.');
    } finally {
      isSubmitting.value = false;
    }
  }

  // Refresh shifts
  Future<void> refreshShifts() async {
    await fetchShiftsData();
  }

  // Check if a shift has been applied for
  ShiftApplicationModel? getApplicationForShift(String shiftId) {
    try {
      return appliedShifts.firstWhere(
            (application) => application.shiftId == shiftId,
      );
    } catch (e) {
      return null;
    }
  }

  // Check if a shift can be applied for (not already applied)
  bool canApplyForShift(String shiftId) {
    final application = getApplicationForShift(shiftId);
    return application == null;
  }

  // Get status text for a shift
  String? getShiftStatus(String shiftId) {
    final application = getApplicationForShift(shiftId);
    return application?.statusDisplay;
  }

  // Get status color for a shift
  Color? getShiftStatusColor(String shiftId) {
    final application = getApplicationForShift(shiftId);
    return application?.statusColor;
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

  // Get selected shift details
  ShiftModel? get selectedShiftDetails {
    if (selectedShift.value.isEmpty) return null;

    try {
      return availableShifts.firstWhere(
            (shift) => shift.shiftId == selectedShift.value,
      );
    } catch (e) {
      return null;
    }
  }

  // Debug method to check applied shifts
  Future<void> debugAppliedShifts() async {
    print(' SAHAr 🐛 --- Debug Applied Shifts ---');
    print(' SAHAr 🐛 Available shifts count: ${availableShifts.length}');
    print(' SAHAr 🐛 Applied shifts count: ${appliedShifts.length}');

    for (var availableShift in availableShifts) {
      final application = getApplicationForShift(availableShift.shiftId);
      final canApply = canApplyForShift(availableShift.shiftId);

      print(' SAHAr 🐛 Shift: ${availableShift.title} (${availableShift.shiftId})');
      print(' SAHAr   - Can Apply: $canApply');
      print(' SAHAr   - Application: ${application?.status ?? 'None'}');
    }
    print(' SAHAr 🐛 --- End Debug ---');
  }

  @override
  void onClose() {
    // Clean up if needed
    super.onClose();
  }
}