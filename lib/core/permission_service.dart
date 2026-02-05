import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService extends GetxService {
  static PermissionService get to => Get.find();

  // Observable state variables
  final hasLocationPermission = false.obs;
  final isGpsEnabled = false.obs;
  final isCheckingPermissions = false.obs;
  final permissionError = ''.obs;

  // Status getters
  bool get isReady => hasLocationPermission.value && isGpsEnabled.value;
  bool get hasAnyIssue => !hasLocationPermission.value || !isGpsEnabled.value;

  @override
  void onInit() {
    super.onInit();
    // Auto-check permissions when service initializes
    _initializePermissions();
  }

  /// Initialize permissions and GPS check
  Future<void> _initializePermissions() async {
    await checkAllPermissions();
  }

  /// Complete permission and GPS check
  Future<bool> checkAllPermissions() async {
    isCheckingPermissions.value = true;
    permissionError.value = '';

    try {
      // Check location permissions first
      await checkLocationPermission();

      if (hasLocationPermission.value) {
        // Check GPS status if permissions are granted
        await checkGpsStatus();
      }

      return isReady;
    } catch (e) {
      print(' SAHAr PermissionService: Error checking permissions: $e');
      permissionError.value = 'Error checking permissions: $e';
      return false;
    } finally {
      isCheckingPermissions.value = false;
    }
  }

  /// Check and request location permissions
  Future<bool> checkLocationPermission() async {
    // Use two-step flow for iOS, standard flow for Android
    if (Platform.isIOS) {
      return await requestLocationPermissionTwoStep();
    }

    try {
      // Check using Geolocator
      LocationPermission geoPermission = await Geolocator.checkPermission();

      // Check using permission_handler for more control
      var permissionStatus = await Permission.location.status;

      // If denied, request permission
      if (geoPermission == LocationPermission.denied || !permissionStatus.isGranted) {
        // Request using both methods
        geoPermission = await Geolocator.requestPermission();
        permissionStatus = await Permission.location.request();
      }

      // Check for permanent denial
      if (geoPermission == LocationPermission.deniedForever) {
        permissionError.value = 'Location permission permanently denied. Please enable it in app settings.';
        hasLocationPermission.value = false;
        return false;
      }

      // Check if still denied
      if (geoPermission == LocationPermission.denied || !permissionStatus.isGranted) {
        permissionError.value = 'Location permission is required for this app to work.';
        hasLocationPermission.value = false;
        return false;
      }

      // Permission granted
      bool isGranted = (geoPermission == LocationPermission.whileInUse ||
          geoPermission == LocationPermission.always) &&
          permissionStatus.isGranted;

      hasLocationPermission.value = isGranted;

      if (isGranted) {
        print(' SAHAr PermissionService: Location permissions granted');
      } else {
        permissionError.value = 'Location permission is required for driver tracking.';
      }

      return isGranted;
    } catch (e) {
      print(' SAHAr PermissionService: Error checking location permission: $e');
      permissionError.value = 'Error checking permissions: $e';
      hasLocationPermission.value = false;
      return false;
    }
  }

  /// Two-step location permission request for iOS
  /// Step 1: Request "When In Use" permission first
  /// Step 2: Request "Always" permission after user grants "When In Use"
  Future<bool> requestLocationPermissionTwoStep() async {
    if (!Platform.isIOS) {
      // Android: Use existing flow
      return await checkLocationPermission();
    }

    try {
      // Step 1: Request "When In Use" permission first
      LocationPermission geoPermission = await Geolocator.checkPermission();
      
      if (geoPermission == LocationPermission.denied) {
        // Show custom dialog explaining why we need location
        bool? shouldProceed = await Get.dialog<bool>(
          AlertDialog(
            title: const Text('Location Access Needed'),
            content: const Text('Your location is used to show your vehicle on the map to customers and find pickup points.'),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Get.back(result: true),
                child: const Text('Allow'),
              ),
            ],
          ),
        );

        if (shouldProceed != true) return false;

        geoPermission = await Geolocator.requestPermission();
        if (geoPermission != LocationPermission.whileInUse && 
            geoPermission != LocationPermission.always) {
          return false;
        }
      }

      // Step 2: Request "Always" permission if we only have "When In Use"
      if (geoPermission == LocationPermission.whileInUse) {
        // Show second dialog explaining why "Always" is needed
        bool? shouldProceed = await Get.dialog<bool>(
          AlertDialog(
            title: const Text('Background Location Access'),
            content: const Text('To receive rides while using navigation apps, please switch location to "Always Allow". This allows PickU to assign you nearby rides and track your trip progress accurately.'),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: const Text('Not Now'),
              ),
              ElevatedButton(
                onPressed: () => Get.back(result: true),
                child: const Text('Allow Always'),
              ),
            ],
          ),
        );

        if (shouldProceed == true) {
          // Request "Always" permission
          var permissionStatus = await Permission.locationAlways.request();
          if (permissionStatus.isGranted) {
            geoPermission = await Geolocator.checkPermission();
          }
        }
      }

      // Check final status
      geoPermission = await Geolocator.checkPermission();
      hasLocationPermission.value = 
          geoPermission == LocationPermission.always ||
          geoPermission == LocationPermission.whileInUse;
      
      if (hasLocationPermission.value) {
        print(' SAHAr PermissionService: iOS location permissions granted: $geoPermission');
      } else {
        permissionError.value = 'Location permission is required for driver tracking.';
      }
      
      return hasLocationPermission.value;
    } catch (e) {
      print('❌ SAHAr PermissionService: Error in two-step permission: $e');
      permissionError.value = 'Error requesting location permission: $e';
      hasLocationPermission.value = false;
      return false;
    }
  }

  /// Check GPS/Location services status
  Future<bool> checkGpsStatus() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      isGpsEnabled.value = serviceEnabled;

      if (!serviceEnabled) {
        permissionError.value = 'GPS/Location services are disabled. Please enable them.';
        print(' SAHAr PermissionService: GPS is disabled');
      } else {
        print(' SAHAr PermissionService: GPS is enabled');
      }

      return serviceEnabled;
    } catch (e) {
      print(' SAHAr PermissionService: Error checking GPS status: $e');
      isGpsEnabled.value = false;
      return false;
    }
  }

  /// Open app settings for permission management
  Future<void> openAppSettings() async {
    try {
      // Use openAppSettings from permission_handler - it's more reliable
      await openAppSettings();
    } catch (e) {
      print(' SAHAr PermissionService: Error opening app settings: $e');
      // Fallback to Geolocator if permission_handler fails
      try {
        await Geolocator.openAppSettings();
      } catch (e2) {
        print(' SAHAr PermissionService: Fallback also failed: $e2');
      }
    }
  }

  /// Open location settings to enable GPS
  Future<void> openLocationSettings() async {
    try {
      await Geolocator.openLocationSettings();
      // Wait a moment then recheck GPS status
      await Future.delayed(const Duration(seconds: 1));
      await checkGpsStatus();
    } catch (e) {
      print(' SAHAr PermissionService: Error opening location settings: $e');
    }
  }

  /// Show GPS dialog and handle user action
  Future<bool> showGpsDialog() async {
    bool? result = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('GPS Required'),
        content: const Text('Please enable GPS/Location services to use location features.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Get.back(result: true);
              await openLocationSettings();
            },
            child: const Text('Enable GPS'),
          ),
        ],
      ),
      barrierDismissible: false,
    );

    return result ?? false;
  }

  /// Show permission dialog and handle user action
  Future<bool> showPermissionDialog() async {
    bool? result = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Location Permission Required'),
        content: Text(permissionError.value.isNotEmpty
            ? permissionError.value
            : 'This app needs location permission to function properly.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Get.back(result: true);
              await checkLocationPermission();
            },
            child: const Text('Grant Permission'),
          ),
          if (await Permission.location.isPermanentlyDenied)
            TextButton(
              onPressed: () async {
                Get.back(result: true);
                await openAppSettings();
                // Recheck after user returns from settings
                await Future.delayed(const Duration(seconds: 1));
                await checkAllPermissions();
              },
              child: const Text('Open Settings'),
            ),
        ],
      ),
      barrierDismissible: false,
    );

    return result ?? false;
  }

  /// Auto-handle permission issues with dialogs
  Future<bool> ensurePermissionsWithDialog() async {
    await checkAllPermissions();

    if (!hasLocationPermission.value) {
      bool granted = await showPermissionDialog();
      if (!granted) return false;
    }

    if (hasLocationPermission.value && !isGpsEnabled.value) {
      bool enabled = await showGpsDialog();
      if (!enabled) return false;
    }

    return isReady;
  }

  /// Request specific permission type
  Future<bool> requestPermission(Permission permission) async {
    try {
      var status = await permission.request();
      return status.isGranted;
    } catch (e) {
      print(' SAHAr PermissionService: Error requesting permission: $e');
      return false;
    }
  }

  /// Check if permission is permanently denied
  Future<bool> isPermissionPermanentlyDenied(Permission permission) async {
    try {
      return await permission.isPermanentlyDenied;
    } catch (e) {
      print(' SAHAr PermissionService: Error checking permanent denial: $e');
      return false;
    }
  }

  /// Get detailed permission status info
  Map<String, dynamic> getPermissionStatus() {
    return {
      'hasLocationPermission': hasLocationPermission.value,
      'isGpsEnabled': isGpsEnabled.value,
      'isReady': isReady,
      'isChecking': isCheckingPermissions.value,
      'error': permissionError.value,
    };
  }

  /// Reset all states
  void reset() {
    hasLocationPermission.value = false;
    isGpsEnabled.value = false;
    isCheckingPermissions.value = false;
    permissionError.value = '';
  }

  /// Refresh permissions (useful for onResume)
  Future<void> refresh() async {
    await checkAllPermissions();
  }
}