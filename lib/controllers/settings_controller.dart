import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsController extends GetxController {
  // Observables
  var locationPermissionStatus = 'Unknown'.obs;
  var isLocationEnabled = false.obs;
  var isNotificationEnabled = false.obs;
  var gpsAccuracy = 'Unknown'.obs;
  var lastLocationUpdate = 'Never'.obs;
  var cacheSize = 'Calculating...'.obs;
  var isCalculatingCache = false.obs;
  var appVersion = '1.0.0'.obs;
  var appBuildNumber = '1'.obs;

  @override
  void onInit() {
    super.onInit();
    _initializeSettings();
  }

  Future<void> _initializeSettings() async {
    await Future.wait([
      _checkLocationPermission(),
      _checkNotificationPermission(),
      _getAppVersion(),
      _calculateCacheSize(),
    ]);
  }

  // Refresh all settings
  Future<void> refreshAll() async {
    Get.snackbar(
      'Refreshing',
      'Updating all settings...',
      duration: const Duration(seconds: 1),
    );
    await _initializeSettings();
  }

  // Location Permission
  Future<void> _checkLocationPermission() async {
    try {
      final permission = await Permission.location.status;
      locationPermissionStatus.value = _getPermissionStatusString(permission);
      
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      isLocationEnabled.value = serviceEnabled;

      if (permission.isGranted && serviceEnabled) {
        await refreshLocationAccuracy();
      }
    } catch (e) {
      locationPermissionStatus.value = 'Error';
      print('Error checking location permission: $e');
    }
  }

  String _getPermissionStatusString(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return 'Granted';
      case PermissionStatus.denied:
        return 'Denied';
      case PermissionStatus.permanentlyDenied:
        return 'Permanently Denied';
      case PermissionStatus.restricted:
        return 'Restricted';
      case PermissionStatus.limited:
        return 'Limited';
      default:
        return 'Unknown';
    }
  }

  Future<void> openLocationSettings() async {
    final result = await openAppSettings();
    if (result) {
      // Wait a bit for user to change settings
      await Future.delayed(const Duration(seconds: 1));
      await _checkLocationPermission();
    }
  }

  // GPS Accuracy
  Future<void> refreshLocationAccuracy() async {
    try {
      final permission = await Permission.location.status;
      if (!permission.isGranted) {
        gpsAccuracy.value = 'Permission required';
        lastLocationUpdate.value = 'N/A';
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      gpsAccuracy.value = '${position.accuracy.toStringAsFixed(1)}m';
      lastLocationUpdate.value = 'Just now';
    } catch (e) {
      gpsAccuracy.value = 'Unable to get';
      lastLocationUpdate.value = 'Error';
      print('Error getting location accuracy: $e');
    }
  }

  // Notifications
  Future<void> _checkNotificationPermission() async {
    try {
      final permission = await Permission.notification.status;
      isNotificationEnabled.value = permission.isGranted;
    } catch (e) {
      isNotificationEnabled.value = false;
      print('Error checking notification permission: $e');
    }
  }

  Future<void> openNotificationSettings() async {
    await openAppSettings();
    await Future.delayed(const Duration(seconds: 1));
    await _checkNotificationPermission();
  }

  // Storage/Cache
  Future<void> _calculateCacheSize() async {
    try {
      isCalculatingCache.value = true;
      final tempDir = await getTemporaryDirectory();
      int totalSize = 0;

      if (await tempDir.exists()) {
        await for (var entity in tempDir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            try {
              totalSize += await entity.length();
            } catch (e) {
              // Skip files that can't be accessed
            }
          }
        }
      }

      cacheSize.value = _formatBytes(totalSize);
    } catch (e) {
      cacheSize.value = 'Unknown';
      print('Error calculating cache size: $e');
    } finally {
      isCalculatingCache.value = false;
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Future<void> clearCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      
      if (await tempDir.exists()) {
        final result = await Get.dialog<bool>(
          AlertDialog(
            title: const Text('Clear Cache'),
            content: Text('Are you sure you want to clear ${cacheSize.value} of cached data?'),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Get.back(result: true),
                child: const Text('Clear', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );

        if (result == true) {
          await for (var entity in tempDir.list()) {
            try {
              if (entity is Directory) {
                await entity.delete(recursive: true);
              } else if (entity is File) {
                await entity.delete();
              }
            } catch (e) {
              print('Error deleting ${entity.path}: $e');
            }
          }

          Get.snackbar(
            'Success',
            'Cache cleared successfully',
            snackPosition: SnackPosition.BOTTOM,
          );

          await _calculateCacheSize();
        }
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to clear cache: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
      );
      print('Error clearing cache: $e');
    }
  }

  // App Version
  Future<void> _getAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      appVersion.value = packageInfo.version;
      appBuildNumber.value = packageInfo.buildNumber;
    } catch (e) {
      appVersion.value = 'Unknown';
      appBuildNumber.value = 'Unknown';
      print('Error getting app version: $e');
    }
  }

  // Rate App
  Future<void> rateApp() async {
    try {
      final Uri androidUrl = Uri.parse('https://play.google.com/store/apps/details?id=com.picku.driver');
      final Uri iosUrl = Uri.parse('https://apps.apple.com/app/picku-driver/id6738854018');
      
      if (Platform.isAndroid) {
        if (await canLaunchUrl(androidUrl)) {
          await launchUrl(androidUrl, mode: LaunchMode.externalApplication);
        }
      } else if (Platform.isIOS) {
        if (await canLaunchUrl(iosUrl)) {
          await launchUrl(iosUrl, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Unable to open store: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
      );
      print('Error launching store: $e');
    }
  }
}
