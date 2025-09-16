import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pick_u_driver/core/sharePref.dart';
import 'package:pick_u_driver/core/signalr_service.dart';
import 'package:pick_u_driver/providers/api_provider.dart';

/// Controller for managing driver online/offline status
class DriverStatusController extends GetxController {
  final SignalRService _signalRService = SignalRService.to;
  final ApiProvider _apiProvider = Get.find<ApiProvider>();

  // Observable status
  var isOnline = false.obs;
  var isLoading = false.obs;
  var statusMessage = 'Initializing...'.obs;
  var lastLocationUpdate = ''.obs;

  String? _driverId;
  String? _driverName;
  String? _driverEmail;

  @override
  void onInit() {
    super.onInit();
    _initializeDriverInfo();
  }

  /// Initialize driver information from SharedPrefs
  Future<void> _initializeDriverInfo() async {
    try {
      isLoading.value = true;
      statusMessage.value = 'Loading driver info...';

      // Load all driver data from SharedPrefs
      final userData = await SharedPrefsService.getUserData();
      _driverId = userData['userId'];
      _driverName = userData['fullName'];
      _driverEmail = userData['email'];

      if (_driverId == null || _driverName == null) {
        statusMessage.value = 'Driver info not found - Please login again';
        Get.snackbar(
          'Error',
          'Driver information not found. Please logout and login again.',
          backgroundColor: Colors.red.shade100,
          colorText: Colors.red.shade800,
        );
        return;
      }

      print('SAHAr Driver initialized: $_driverName ($_driverId)');
      statusMessage.value = 'Ready to go online';

      // Set driver info in SignalR service
      _signalRService.setDriverInfo(_driverId!, _driverName!);

    } catch (e) {
      print('SAHAr Error initializing driver info: $e');
      statusMessage.value = 'Error loading driver info';
      Get.snackbar('Initialization Error', 'Failed to load driver information: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Toggle driver status between online and offline
  Future<void> toggleDriverStatus() async {
    if (_driverId == null || _driverName == null) {
      await _initializeDriverInfo(); // Try to reload driver info
      if (_driverId == null || _driverName == null) {
        Get.snackbar('Error', 'Driver information not available. Please login again.');
        return;
      }
    }

    if (isLoading.value) return; // Prevent multiple simultaneous calls

    isLoading.value = true;
    statusMessage.value = isOnline.value ? 'Going offline...' : 'Going online...';

    try {
      if (isOnline.value) {
        // Going offline
        await _goOffline();
      } else {
        // Going online
        await _goOnline();
      }
    } catch (e) {
      print('SAHArSAHAr Error toggling driver status: $e');
      statusMessage.value = 'Error: ${e.toString()}';

      Get.snackbar(
        'Status Error',
        'Failed to update driver status: $e',
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade800,
        duration: const Duration(seconds: 5),
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Set driver online
  Future<void> _goOnline() async {
    try {
      statusMessage.value = 'Connecting to server...';

      // First ensure SignalR connection
      bool connected = await _signalRService.connect();

      if (!connected) {
        throw Exception('Failed to connect to SignalR server');
      }

      statusMessage.value = 'Starting location updates...';

      await _signalRService.startLocationUpdates(
          interval: const Duration(seconds: 5) // Send location every 5 seconds
      );

      if (!_signalRService.isLocationSending.value) {
        throw Exception('Failed to start location tracking');
      }

      // Update status
      isOnline.value = true;
      statusMessage.value = 'Online - Tracking location';
      lastLocationUpdate.value = DateTime.now().toString();

      Get.snackbar(
        'Status Updated',
        'You are now ONLINE and ready to receive rides!',
        backgroundColor: Colors.green.shade100,
        colorText: Colors.green.shade800,
        icon: const Icon(Icons.check_circle, color: Colors.green),
        duration: const Duration(seconds: 4),
      );

      print('SAHArSAHAr Driver is now online with location tracking');

    } catch (e) {
      print('SAHArSAHAr Error going online: $e');

      // Clean up on failure
      try {
        _signalRService.stopLocationUpdates();
        await _signalRService.disconnect();
      } catch (cleanupError) {
        print('SAHAr Error during cleanup: $cleanupError');
      }

      throw Exception('Failed to go online: $e');
    }
  }

  /// Set driver offline
  Future<void> _goOffline() async {
    try {
      statusMessage.value = 'Stopping location tracking...';

      // Stop location updates first
      _signalRService.stopLocationUpdates();

      statusMessage.value = 'Calling API to set offline...';

      // and including driverId in the body instead of URL parameter
      final response = await _apiProvider.postData('/api/Drivers/set-offline/$_driverId', {});

      if (response.statusCode == 200 || response.statusCode == 201) {
        statusMessage.value = 'Disconnecting from server...';

        // Disconnect from SignalR
        await _signalRService.disconnect();

        // Update status
        isOnline.value = false;
        statusMessage.value = 'Offline';
        lastLocationUpdate.value = '';
        final responseData = response.body;
        String successMessage = 'You are now OFFLINE';

        if (responseData != null && responseData is Map && responseData['message'] != null) {
          successMessage = responseData['message'];
        }

        Get.snackbar(
          successMessage,
          'You are offline - Thank you for your service',
          icon: const Icon(Icons.offline_bolt),
          duration: const Duration(seconds: 3),
        );

        print('SAHArSAHAr Driver is now offline');

      } else {
        // API call failed - but still disconnect locally to prevent data sending
        print('SAHAr API Error Response: ${response.statusCode} - ${response.body}');

        // Force disconnect from SignalR to stop sending location data
        await _signalRService.disconnect();

        // Update local status even if API call failed
        isOnline.value = false;
        statusMessage.value = 'Offline (API call failed but locally disconnected)';
        lastLocationUpdate.value = '';

        String errorMessage = 'API call failed (${response.statusCode}) but location tracking stopped';

        final responseData = response.body;
        if (responseData != null && responseData is Map) {
          if (responseData['message'] != null) {
            errorMessage = 'API Error: ${responseData['message']} - Location tracking stopped';
          } else if (responseData['error'] != null) {
            errorMessage = 'API Error: ${responseData['error']} - Location tracking stopped';
          }
        } else if (response.statusText != null) {
          errorMessage = '${response.statusText} (${response.statusCode}) - Location tracking stopped';
        }

        Get.snackbar(
          'Offline Status',
          errorMessage,
          backgroundColor: Colors.orange.shade100,
          colorText: Colors.orange.shade800,
          icon: const Icon(Icons.warning, color: Colors.orange),
          duration: const Duration(seconds: 4),
        );

        print('SAHArSAHAr Driver offline locally (API failed): $errorMessage');
      }

    } catch (e) {
      print('SAHArSAHAr Error going offline: $e');

      // Force cleanup even if everything fails - MOST IMPORTANT: stop location tracking
      try {
        _signalRService.stopLocationUpdates();
        await _signalRService.disconnect();

        // Always update local status to prevent location data sending
        isOnline.value = false;
        statusMessage.value = 'Offline (forced due to error)';
        lastLocationUpdate.value = '';

        Get.snackbar(
          'Offline Status',
          'Location tracking stopped (error occurred but locally disconnected)',
          backgroundColor: Colors.orange.shade100,
          colorText: Colors.orange.shade800,
          icon: const Icon(Icons.offline_bolt, color: Colors.orange),
          duration: const Duration(seconds: 4),
        );

        print('SAHArSAHAr Driver forced offline due to error - location tracking stopped');
      } catch (cleanupError) {
        print('SAHAr Error during offline cleanup: $cleanupError');
      }

      throw Exception('Failed to go offline: $e');
    }
  }

  /// Force refresh driver status (for troubleshooting)
  Future<void> refreshStatus() async {
    isLoading.value = true;
    try {
      await _initializeDriverInfo();
    } finally {
      isLoading.value = false;
    }
  }

  /// Get current driver info
  Map<String, String?> get driverInfo => {
    'driverId': _driverId,
    'driverName': _driverName,
    'driverEmail': _driverEmail,
  };

  /// Get detailed status for debugging
  Map<String, dynamic> getDetailedStatus() {
    return {
      'isOnline': isOnline.value,
      'isLoading': isLoading.value,
      'statusMessage': statusMessage.value,
      'lastLocationUpdate': lastLocationUpdate.value,
      'driverInfo': driverInfo,
      'signalRInfo': _signalRService.getConnectionInfo(),
    };
  }

  @override
  void onClose() {
    // Clean shutdown when controller is disposed
    if (isOnline.value) {
      _signalRService.stopLocationUpdates();
      _signalRService.disconnect();
    }
    super.onClose();
  }
}

/// Beautiful driver status toggle widget
/// Compact driver status toggle widget
class DriverStatusToggle extends StatelessWidget {
  final DriverStatusController controller = Get.put(DriverStatusController());

  DriverStatusToggle({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Obx(() => Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: controller.isOnline.value
                  ? [Colors.green.shade400, Colors.green.shade500]
                  : [Colors.grey.shade400, Colors.grey.shade500],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: controller.isLoading.value ? null : controller.toggleDriverStatus,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Small status icon
                  controller.isLoading.value
                      ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : Icon(
                    controller.isOnline.value
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),

                  // Compact status text
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        controller.isOnline.value ? 'ONLINE' : 'OFFLINE',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        controller.statusMessage.value.length > 15
                            ? '${controller.statusMessage.value.substring(0, 15)}...'
                            : controller.statusMessage.value,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 9,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),

                  const SizedBox(width: 6),

                  // Small toggle icon
                  Icon(
                    controller.isOnline.value ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 14,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ));
  }
}

/// Compact status indicator for the top of the screen
class CompactDriverStatusIndicator extends StatelessWidget {
  final DriverStatusController controller = Get.find<DriverStatusController>();

  CompactDriverStatusIndicator({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Obx(() => GestureDetector(
      onLongPress: () {
        // Show detailed status on long press (for debugging)
        final status = controller.getDetailedStatus();
        Get.bottomSheet(
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Driver Status Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Text('Driver: ${status['driverInfo']['driverName']}'),
                Text('Status: ${controller.isOnline.value ? "ONLINE" : "OFFLINE"}'),
                Text('Message: ${status['statusMessage']}'),
                if (status['signalRInfo']['isConnected'] == true)
                  Text('SignalR: Connected (${status['signalRInfo']['locationUpdateCount']} updates sent)'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Get.back(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: controller.isOnline.value
              ? Colors.green.withOpacity(0.9)
              : Colors.grey.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: controller.isOnline.value
                    ? Colors.greenAccent
                    : Colors.grey.shade300,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              controller.isOnline.value ? 'ONLINE' : 'OFFLINE',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (controller.isLoading.value) ...[
              const SizedBox(width: 8),
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
    ));
  }
}