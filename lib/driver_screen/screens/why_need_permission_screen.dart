import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/permission_service.dart';
import '../../core/location_service.dart';
import '../../core/map_service.dart';
import '../../routes/app_routes.dart';
import '../../utils/theme/mcolors.dart';

class WhyNeedPermissionScreen extends StatefulWidget {
  const WhyNeedPermissionScreen({super.key});

  @override
  State<WhyNeedPermissionScreen> createState() => _WhyNeedPermissionScreenState();
}

class _WhyNeedPermissionScreenState extends State<WhyNeedPermissionScreen> {
  bool _isRequesting = false;
  String _errorMessage = '';

  @override
  Widget build(BuildContext context) {
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
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated icon container
                  Container(
                    height: 120,
                    width: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: MColor.primaryNavy,
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Title
                  Text(
                    'Location Access Required',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.grey[800],
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 16),

                  // Description
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      _errorMessage.isNotEmpty
                          ? _errorMessage
                          : 'We need access to your location to provide accurate driver tracking and navigation services.',
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark ? Colors.grey[300] : Colors.grey[600],
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 50),

                  // Main action button
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      color: MColor.primaryNavy,
                    ),
                    child: ElevatedButton(
                      onPressed: _isRequesting ? null : _requestPermission,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        disabledBackgroundColor: Colors.grey,
                      ),
                      child: _isRequesting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Grant Location Access',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Secondary action button (only for permission issues)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: _isRequesting
                          ? null
                          : () async {
                              await openAppSettings();
                              // Recheck after returning from settings
                              await Future.delayed(const Duration(seconds: 1));
                              _checkPermissionStatus();
                            },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.white : MColor.primaryNavy,
                        side: BorderSide(
                          color: isDark ? Colors.grey[600]! : MColor.primaryNavy,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text(
                        'Open App Settings',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Features list
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
                          'Why we need this:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildFeatureItem(
                          Icons.navigation_rounded,
                          'Real-time navigation',
                          isDark,
                        ),
                        _buildFeatureItem(
                          Icons.my_location_rounded,
                          'Driver location tracking',
                          isDark,
                        ),
                        _buildFeatureItem(
                          Icons.route_rounded,
                          'Optimal route suggestions',
                          isDark,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: MColor.primaryNavy,
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[300] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  /// Request location permission and initialize PermissionService
  Future<void> _requestPermission() async {
    setState(() {
      _isRequesting = true;
      _errorMessage = '';
    });

    try {
      // Request permission using Geolocator
      LocationPermission geoPermission = await Geolocator.requestPermission();
      var permissionStatus = await Permission.location.request();

      // Check for permanent denial
      if (geoPermission == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage =
              'Location permission permanently denied. Please enable it in app settings.';
          _isRequesting = false;
        });
        return;
      }

      // Check if still denied
      if (geoPermission == LocationPermission.denied || !permissionStatus.isGranted) {
        setState(() {
          _errorMessage = 'Location permission is required for this app to work.';
          _isRequesting = false;
        });
        return;
      }

      // Permission granted - now initialize PermissionService
      bool isGranted = (geoPermission == LocationPermission.whileInUse ||
              geoPermission == LocationPermission.always) &&
          permissionStatus.isGranted;

      if (isGranted) {
        // Initialize PermissionService now that permission is granted
        await _initializePermissionService();

        // Check GPS status
        bool gpsEnabled = await Geolocator.isLocationServiceEnabled();
        if (!gpsEnabled) {
          // GPS is not enabled, show dialog to enable it
          await _showGpsDialog();
        }

        // Navigate to main map
        if (mounted) {
          Get.offAllNamed(AppRoutes.MainMap);
        }
      } else {
        setState(() {
          _errorMessage = 'Location permission is required for driver tracking.';
          _isRequesting = false;
        });
      }
    } catch (e) {
      print('Error requesting permission: $e');
      setState(() {
        _errorMessage = 'Error requesting permissions: $e';
        _isRequesting = false;
      });
    }
  }

  /// Initialize PermissionService, LocationService, and MapService after permission is granted
  Future<void> _initializePermissionService() async {
    try {
      // Initialize PermissionService
      if (!Get.isRegistered<PermissionService>()) {
        Get.put(PermissionService(), permanent: true);
      }

      // Update permission status
      final permissionService = PermissionService.to;
      permissionService.hasLocationPermission.value = true;

      // Check GPS status
      bool gpsEnabled = await Geolocator.isLocationServiceEnabled();
      permissionService.isGpsEnabled.value = gpsEnabled;

      // Initialize LocationService
      if (!Get.isRegistered<LocationService>()) {
        Get.put(LocationService(), permanent: true);
        print('✅ LocationService initialized after permission granted');
      }

      // Initialize MapService
      if (!Get.isRegistered<MapService>()) {
        Get.put(MapService(), permanent: true);
        print('✅ MapService initialized after permission granted');
      }

      print('✅ PermissionService initialized after permission granted');
    } catch (e) {
      print('❌ Error initializing services: $e');
    }
  }

  /// Show GPS dialog
  Future<void> _showGpsDialog() async {
    bool? result = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('GPS Required'),
        content: const Text(
            'Please enable GPS/Location services to use location features.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Get.back(result: true);
              await Geolocator.openLocationSettings();
            },
            child: const Text('Enable GPS'),
          ),
        ],
      ),
      barrierDismissible: false,
    );

    if (result == true) {
      // Wait a moment then recheck GPS status
      await Future.delayed(const Duration(seconds: 1));
      bool gpsEnabled = await Geolocator.isLocationServiceEnabled();
      if (Get.isRegistered<PermissionService>()) {
        PermissionService.to.isGpsEnabled.value = gpsEnabled;
      }
    }
  }

  /// Check permission status after returning from settings
  Future<void> _checkPermissionStatus() async {
    try {
      LocationPermission geoPermission = await Geolocator.checkPermission();
      var permissionStatus = await Permission.location.status;

      if (geoPermission == LocationPermission.whileInUse ||
          geoPermission == LocationPermission.always && permissionStatus.isGranted) {
        // Permission granted, initialize service and navigate
        await _initializePermissionService();
        if (mounted) {
          Get.offAllNamed(AppRoutes.MainMap);
        }
      }
    } catch (e) {
      print('Error checking permission status: $e');
    }
  }
}
