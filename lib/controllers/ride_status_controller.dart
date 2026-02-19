import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pick_u_driver/core/driver_service.dart';
import 'package:pick_u_driver/core/sharePref.dart';
import 'package:pick_u_driver/providers/api_provider.dart';

class RideStatusController extends GetxController {
  final ApiProvider _apiProvider = Get.find<ApiProvider>();
  final DriverService _driverService = Get.find<DriverService>();

  // Observable variables
  var rideStatus = RxnString();
  var isLoading = false.obs;
  late final Rx<bool> shouldShowGoLiveButton;

  @override
  void onInit() {
    super.onInit();
    // Create a computed observable that updates when rideStatus changes
    shouldShowGoLiveButton = Rx<bool>(_computeShouldShowGoLiveButton());

    // Listen to rideStatus changes and update the computed value
    ever(rideStatus, (_) {
      shouldShowGoLiveButton.value = _computeShouldShowGoLiveButton();
      print('🔄 SAHAr shouldShowGoLiveButton updated: ${shouldShowGoLiveButton.value}');
    });

    _loadRideStatus();
  }

  /// Load ride status from SharedPreferences
  Future<void> _loadRideStatus() async {
    try {
      final status = await SharedPrefsService.getRideStatus();
      rideStatus.value = status;
      print('✅ SAHAr Ride status loaded: $status');
    } catch (e) {
      print('❌ SAHAr Error loading ride status: $e');
    }
  }

  /// Compute if driver should see "Go Live" button
  bool _computeShouldShowGoLiveButton() {
    final status = rideStatus.value?.toLowerCase();
    final shouldShow = status != 'available';
    print('🔍 SAHAr _computeShouldShowGoLiveButton - Status: $status, ShouldShow: $shouldShow');
    // Show "Go Live" button only when driver is NOT available
    return shouldShow;
  }

  /// Set driver as available
  Future<void> goLive() async {
    if (isLoading.value) return;

    try {
      isLoading.value = true;

      // Get driver ID
      final driverId = _driverService.driverId.value ?? await SharedPrefsService.getUserId();

      if (driverId == null || driverId.isEmpty) {
        _showError('Driver ID not found. Please login again.');
        return;
      }

      print('🚀 SAHAr Setting driver available: $driverId');

      // Call API to set driver as available
      final response = await _apiProvider.setDriverAvailable(driverId);

      if (response.statusCode == 200 || response.isOk) {
        // Update ride status locally
        rideStatus.value = 'Available';
        await SharedPrefsService.updateRideStatus('Available');
        await _driverService.updateRideStatus('Available');

        _showSuccess('You are now available for rides!');
        print('✅ SAHAr Driver is now available');
      } else {
        final errorMessage = response.body?['message'] ??
                           response.statusText ??
                           'Failed to set driver as available';
        _showError(errorMessage);
        print('❌ SAHAr Failed to set driver available: $errorMessage');
      }
    } catch (e) {
      print('❌ SAHAr Error setting driver available: $e');
      _showError('Failed to set driver as available. Please try again.');
    } finally {
      isLoading.value = false;
    }
  }

  /// Show success message
  void _showSuccess(String message) {
    Get.snackbar(
      'Success',
      message,
      backgroundColor: Colors.green.shade100,
      colorText: Colors.green.shade900,
      icon: Icon(Icons.check_circle, color: Colors.green.shade700),
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      snackPosition: SnackPosition.TOP,
    );
  }

  /// Show error message
  void _showError(String message) {
    Get.snackbar(
      'Error',
      message,
      backgroundColor: Colors.red.shade100,
      colorText: Colors.red.shade900,
      icon: Icon(Icons.error_outline, color: Colors.red.shade700),
      duration: const Duration(seconds: 4),
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      snackPosition: SnackPosition.TOP,
    );
  }

  /// Refresh ride status (call this when needed)
  Future<void> refreshRideStatus() async {
    await _loadRideStatus();
  }
}

