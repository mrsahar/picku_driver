import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pick_u_driver/core/background_tracking_service.dart';
import 'package:pick_u_driver/core/sharePref.dart';
import 'package:pick_u_driver/providers/api_provider.dart';
import 'package:pick_u_driver/utils/theme/mcolors.dart';


class DriverStatusController extends GetxController {
  final BackgroundTrackingService _backgroundService = BackgroundTrackingService.to;
  final ApiProvider _apiProvider = Get.find<ApiProvider>();

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
    // Listen to background service running state changes
    // Only sync when service stops unexpectedly (not during our controlled stop)
    ever(_backgroundService.isRunning, (running) {
      // If service stopped but we think we're online, sync the state
      if (!running && isOnline.value) {
        print('⚠️ SAHAr Background service stopped unexpectedly - syncing status');
        isOnline.value = false;
      }
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
      final hasStripe = await _ensureStripeConnected();
      if (!hasStripe) {
        return;
      }

      print('🔄 SAHAr Attempting to go online...');
      print('🔄 SAHAr Driver ID: $_driverId');
      print('🔄 SAHAr Driver Name: $_driverName');

      // ✅ Set online immediately for smooth UI transition
      isOnline.value = true;

      // ✅ STEP 1: Call setDriverAvailable API first
      print('📡 SAHAr Calling setDriverAvailable API...');
      final apiResponse = await _apiProvider.setDriverAvailable(_driverId!);

      if (!apiResponse.isOk) {
        print('❌ SAHAr setDriverAvailable API failed: ${apiResponse.statusCode}');
        String errorMessage = 'Failed to set driver available';

        if (apiResponse.body != null) {
          if (apiResponse.body is Map<String, dynamic>) {
            errorMessage = apiResponse.body['message'] ?? errorMessage;
          } else if (apiResponse.body is String) {
            errorMessage = apiResponse.body;
          }
        }

        throw Exception(errorMessage);
      }

      print('✅ SAHAr setDriverAvailable API successful');

      // ✅ STEP 2: Start background service in background (non-blocking)
      // UI is already showing "ONLINE", now we connect in background
      print('🔄 SAHAr Starting background service in background...');

      // Show immediate success feedback to user
      Get.snackbar(
        'You\'re Online!',
        'Connecting to server...',
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        snackPosition: SnackPosition.TOP,
      );

      // Start background service without blocking UI
      _backgroundService.startBackgroundService().then((success) {
        if (success) {
          print('✅ SAHAr Background service started successfully');

        } else {
          print('❌ SAHAr Background service failed to start');
          // Revert online status if background service fails
          isOnline.value = false;
          Get.snackbar(
            'Connection Failed',
            'Failed to connect to server',
            duration: const Duration(seconds: 3),
            margin: const EdgeInsets.all(16),
            borderRadius: 12,
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.red.shade100,
          );
        }
      }).catchError((e) {
        print('❌ SAHAr Background service error: $e');
        isOnline.value = false;
        Get.snackbar(
          'Error',
          'Failed to start background service',
          duration: const Duration(seconds: 3),
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red.shade100,
        );
      });

      print('✅ SAHAr Driver status set to online (background service connecting...)');
    } catch (e) {
      print('❌ SAHAr Error going online: $e');
      print('❌ SAHAr Stack trace: ${StackTrace.current}');

      // ✅ Revert online status on error
      isOnline.value = false;

      // Provide more specific error messages
      String errorMessage = 'Failed to go online';
      if (e.toString().contains('JWT token')) {
        errorMessage = 'Please login again to continue';
      } else if (e.toString().contains('connect')) {
        errorMessage = 'Cannot connect to server. Check your internet connection';
      } else if (e.toString().contains('permission')) {
        errorMessage = 'Location permission is required';
      } else if (e.toString().contains('set driver available')) {
        errorMessage = 'Failed to set driver status on server';
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

  /// Ensure Stripe account is connected before going online
  Future<bool> _ensureStripeConnected() async {
    try {
      final stripeAccountId = await SharedPrefsService.getDriverStripeAccountId();
      final hasStripe = stripeAccountId != null && stripeAccountId.isNotEmpty;
      if (!hasStripe) {
        _showStripeRequiredSheet();
      }
      return hasStripe;
    } catch (e) {
      print('❌ SAHAr Error checking Stripe account: $e');
      _showStripeRequiredSheet();
      return false;
    }
  }

  void _showStripeRequiredSheet() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                SizedBox(width: 12),
                Text(
                  'Stripe account required',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Your Stripe account is not connected. Please add and connect your Stripe account, otherwise you cannot go live.',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Get.back(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MColor.primaryNavy,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'OK',
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
      isScrollControlled: true,
    );
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
        statusColor = Colors.purple;
        statusText = 'CONNECTING';
        subText = connectionStatus;
      } else if (isConnected && isSubscribed) {
        // Fully online and connected
        statusColor = MColor.primaryNavy;
        statusText = 'ONLINE';
        subText = 'Long press for details';
      } else if (isConnected && !isSubscribed) {
        // Connected but not subscribed
        statusColor = Colors.blue;
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

