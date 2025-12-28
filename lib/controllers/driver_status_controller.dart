import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pick_u_driver/core/background_tracking_service.dart';
import 'package:pick_u_driver/core/sharePref.dart';
import 'package:pick_u_driver/utils/theme/mcolors.dart';


class DriverStatusController extends GetxController {
  final BackgroundTrackingService _backgroundService = BackgroundTrackingService.to;

  // Observable status
  var isOnline = false.obs;
  var isLoading = false.obs;

  // Driver information
  String? _driverId;
  String? _driverName;

  @override
  void onInit() {
    super.onInit();
    _initializeDriverInfo();
    _syncWithBackgroundService();
  }

  /// Initialize driver information from SharedPrefs
  Future<void> _initializeDriverInfo() async {
    try {
      final userData = await SharedPrefsService.getUserData();
      _driverId = userData['userId'];
      _driverName = userData['fullName'];

      if (_driverId == null || _driverName == null) {
        _showError('Driver info not found - Please login again');
        return;
      }

      print('✅ SAHAr Driver initialized: $_driverName ($_driverId)');
    } catch (e) {
      print('❌ SAHAr Error initializing driver info: $e');
      _showError('Failed to load driver information');
    }
  }

  /// Sync online status with background service
  void _syncWithBackgroundService() {
    // Listen to background service running state
    ever(_backgroundService.isRunning, (running) {
      isOnline.value = running;
    });
  }

  /// Toggle driver status between online and offline
  Future<void> toggleDriverStatus() async {
    if (_driverId == null || _driverName == null) {
      await _initializeDriverInfo();
      if (_driverId == null || _driverName == null) {
        _showError('Driver information not available. Please login again.');
        return;
      }
    }

    if (isLoading.value) return;

    isLoading.value = true;

    try {
      if (isOnline.value) {
        await _goOffline();
      } else {
        await _goOnline();
      }
    } catch (e) {
      print('❌ SAHAr Error toggling driver status: $e');
      _showError('Failed to update status: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Set driver online - Start background service
  Future<void> _goOnline() async {
    try {
      print('🔄 SAHAr Attempting to go online...');
      print('🔄 SAHAr Driver ID: $_driverId');
      print('🔄 SAHAr Driver Name: $_driverName');

      bool success = await _backgroundService.startBackgroundService();

      if (!success) {
        print('❌ SAHAr Background service returned false');
        throw Exception('Failed to start background service');
      }

      isOnline.value = true;

      Get.snackbar(
        'You\'re Online!',
        'Ready to receive ride requests',
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        snackPosition: SnackPosition.TOP,
      );
      print('✅ SAHAr Driver is now online');
    } catch (e) {
      print('❌ SAHAr Error going online: $e');
      print('❌ SAHAr Stack trace: ${StackTrace.current}');

      // Provide more specific error messages
      String errorMessage = 'Failed to go online';
      if (e.toString().contains('JWT token')) {
        errorMessage = 'Please login again to continue';
      } else if (e.toString().contains('connect')) {
        errorMessage = 'Cannot connect to server. Check your internet connection';
      } else if (e.toString().contains('permission')) {
        errorMessage = 'Location permission is required';
      }

      throw Exception('$errorMessage: $e');
    }
  }

  /// Set driver offline - Stop background service
  Future<void> _goOffline() async {
    try {
      await _backgroundService.stopBackgroundService();
      isOnline.value = false;

      Get.snackbar(
        'You\'re Offline',
        'No longer receiving ride requests',
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        snackPosition: SnackPosition.TOP,
      );

      print('✅ SAHAr Driver is now offline');
    } catch (e) {
      print('❌ SAHAr Error going offline: $e');

      // Force local status update to prevent data sending
      isOnline.value = false;

      Get.snackbar(
        'Offline (Local)',
        'Service stopped locally',
        backgroundColor: Colors.orange.shade100,
        colorText: Colors.orange.shade900,
        icon: Icon(Icons.warning, color: Colors.orange.shade700),
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        snackPosition: SnackPosition.TOP,
      );

      throw Exception('Failed to go offline: $e');
    }
  }

  /// Show error message
  void _showError(String message) {
    Get.snackbar(
      'Error',
      message,
      backgroundColor: Colors.red.shade50,
      colorText: Colors.red.shade900,
      icon: Icon(Icons.error_outline, color: Colors.red.shade700),
      duration: const Duration(seconds: 4),
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      snackPosition: SnackPosition.TOP,
    );
  }

  /// Get current driver info
  Map<String, String?> get driverInfo => {
    'driverId': _driverId,
    'driverName': _driverName,
  };

  @override
  void onClose() {
    if (isOnline.value) {
      _backgroundService.stopBackgroundService();
    }
    super.onClose();
  }
}

/// Enhanced driver status toggle button with detailed status display
class DriverStatusToggle extends StatelessWidget {
  final DriverStatusController controller = Get.find<DriverStatusController>();
  final BackgroundTrackingService backgroundService = Get.find<BackgroundTrackingService>();

  DriverStatusToggle({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isOnline = controller.isOnline.value;
      final isLoading = controller.isLoading.value;
      final isConnected = backgroundService.isConnected.value;
      final isSubscribed = backgroundService.isSubscribed.value;
      final connectionStatus = backgroundService.connectionStatus.value;

      // Determine status for display
      Color statusColor;
      String statusText;
      String subText;

      if (!isOnline) {
        // Offline
        statusColor = Colors.grey.shade600;
        statusText = 'OFFLINE';
        subText = 'Tap to go online';
      } else if (isLoading) {
        // Loading
        statusColor = Colors.orange;
        statusText = 'UPDATING...';
        subText = 'Please wait';
      } else if (connectionStatus == 'Connecting...' || connectionStatus == 'Reconnecting...') {
        // Connecting
        statusColor = Colors.orange;
        statusText = 'CONNECTING';
        subText = connectionStatus;
      } else if (isConnected && isSubscribed) {
        // Fully online and connected
        statusColor = MColor.primaryNavy;
        statusText = 'ONLINE';
        subText = 'Long press for details';
      } else if (isConnected && !isSubscribed) {
        // Connected but not subscribed
        statusColor = Colors.orange;
        statusText = 'ONLINE';
        subText = 'Not subscribed';
      } else {
        // Online but disconnected
        statusColor = Colors.red;
        statusText = 'ONLINE';
        subText = 'Disconnected';
      }

      return GestureDetector(
        onLongPress: isOnline ? _showDetailedServiceStatus : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.only(right: 16),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha:0.95),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: statusColor.withValues(alpha:0.3),
                blurRadius: 12,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated status indicator
              if (isLoading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                )
              else if (isOnline && isConnected && isSubscribed)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: 4),
                    _buildPulsingIndicator(statusColor),
                  ],
                )
              else
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),


              const SizedBox(width: 12),

              // Status text column
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (subText.isNotEmpty)
                    Text(
                      subText,
                      style: TextStyle(
                        color: statusColor.withValues(alpha:0.7),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),

              const SizedBox(width: 12),

              // Toggle indicator - Only this handles tap for online/offline
              GestureDetector(
                onTap: isLoading ? null : controller.toggleDriverStatus,
                child: Container(
                  padding: const EdgeInsets.all(4), // Add some padding for better tap area
                  child: Icon(
                    isOnline ? Icons.toggle_on : Icons.toggle_off,
                    color: statusColor,
                    size: 28,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  /// Build pulsing indicator animation for online status
  Widget _buildPulsingIndicator(Color color) {

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1500),
      builder: (context, value, child) {
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha:0.6 * value),
                blurRadius: 8 * value,
                spreadRadius: 4 * value,
              ),
            ],
          ),
        );
      },
      onEnd: () {
        // Animation will automatically repeat due to rebuild
      },
    );
  }

  /// Show detailed service status
  void _showDetailedServiceStatus() {
    final serviceInfo = backgroundService.getServiceInfo();

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: MColor.primaryNavy,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Service Status Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: MColor.primaryNavy,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              Divider(color: MColor.primaryNavy.withValues(alpha:0.3), height: 20),

              // Core service info
              _buildDetailRow(
                'Background Service',
                serviceInfo['isRunning'] ? 'Running' : 'Stopped',
                color: serviceInfo['isRunning']
                    ? MColor.primaryNavy
                    : Colors.redAccent,
              ),
              _buildDetailRow(
                'Connection Status',
                serviceInfo['connectionStatus'],
                color: serviceInfo['isConnected']
                    ? MColor.primaryNavy
                    : Colors.redAccent,
              ),
              _buildDetailRow(
                'Ride Subscription',
                serviceInfo['isSubscribed'] ? 'Active' : 'Inactive',
                color: serviceInfo['isSubscribed']
                    ? MColor.primaryNavy
                    : Colors.grey,
              ),
              _buildDetailRow(
                'Location Updates',
                serviceInfo['isLocationSending'] ? 'Sending' : 'Stopped',
                color: serviceInfo['isLocationSending']
                    ? MColor.primaryNavy
                    : Colors.grey,
              ),
              _buildDetailRow(
                'Updates Sent',
                '${serviceInfo['locationUpdateCount']}',
                color: MColor.primaryNavy,
              ),

              const SizedBox(height: 24),
              _buildSectionTitle('Driver Information'),

              _buildDetailRow('Driver ID', serviceInfo['driverId']),
              _buildDetailRow('Driver Name', serviceInfo['driverName']),

              if (serviceInfo['currentRideId'] != null &&
                  serviceInfo['currentRideId'].toString().isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildSectionTitle('Active Ride'),
                _buildDetailRow(
                  'Ride ID',
                  serviceInfo['currentRideId'].toString().substring(0, 8) + '...',
                  color: MColor.primaryNavy,
                ),
                _buildDetailRow('Status', serviceInfo['rideStatus']),
              ],

              if (serviceInfo['lastLocation'] != null) ...[
                const SizedBox(height: 24),
                _buildSectionTitle('Last Location'),
                _buildDetailRow(
                  'Latitude',
                  '${serviceInfo['lastLocation']['lat']}',
                ),
                _buildDetailRow(
                  'Longitude',
                  '${serviceInfo['lastLocation']['lng']}',
                ),
                _buildDetailRow(
                  'Timestamp',
                  '${serviceInfo['lastLocation']['timestamp']}',
                ),
              ],

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Get.back(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MColor.primaryNavy,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

// Helper for section titles
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: MColor.primaryNavy,
        ),
      ),
    );
  }


  Widget _buildDetailRow(String label, String? value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value ?? 'N/A',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: color ?? Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}