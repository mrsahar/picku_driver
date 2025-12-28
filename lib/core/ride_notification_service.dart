import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

class RideNotificationService extends GetxService {
  static RideNotificationService get to => Get.find();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  var isNotificationPermissionGranted = false.obs;
  var hasRequestedPermission = false.obs;

  @override
  void onInit() {
    super.onInit();
    _initializeNotifications();
  }

  /// Initialize notification settings
  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    print('🔔 SAHAr Ride Notification service initialized');
  }

  /// Handle notification tap
  void _onNotificationTap(NotificationResponse notificationResponse) {
    final String? payload = notificationResponse.payload;
    if (payload != null) {
      print('🔔 SAHAr Ride notification tapped with payload: $payload');
      // You can navigate to ride details screen here if needed
    }
  }

  /// Request notification permission
  Future<bool> requestNotificationPermission() async {
    if (hasRequestedPermission.value) {
      return isNotificationPermissionGranted.value;
    }

    try {
      hasRequestedPermission.value = true;

      // For Android 13+ (API 33+)
      final PermissionStatus status = await Permission.notification.request();

      if (status.isGranted) {
        isNotificationPermissionGranted.value = true;
        print('✅ SAHAr Ride notification permission granted');
        return true;
      } else if (status.isDenied) {
        isNotificationPermissionGranted.value = false;
        print('❌ SAHAr Ride notification permission denied');
        return false;
      } else if (status.isPermanentlyDenied) {
        isNotificationPermissionGranted.value = false;
        print('❌ SAHAr Ride notification permission permanently denied');
        return false;
      }

      return false;
    } catch (e) {
      print('❌ SAHAr Error requesting ride notification permission: $e');
      return false;
    }
  }

  /// Check if notification permission is granted
  Future<bool> checkNotificationPermission() async {
    try {
      final PermissionStatus status = await Permission.notification.status;
      isNotificationPermissionGranted.value = status.isGranted;
      return status.isGranted;
    } catch (e) {
      print('❌ SAHAr Error checking ride notification permission: $e');
      return false;
    }
  }

  /// Show notification for ride status change with vibration and sound
  Future<void> showRideNotification({
    required String title,
    required String body,
    required String rideId,
    required String status,
  }) async {
    try {
      // Request permission if not granted
      if (!isNotificationPermissionGranted.value) {
        final hasPermission = await checkNotificationPermission();
        if (!hasPermission) {
          print('⚠️ SAHAr Skipping ride notification - permission not granted');
          return;
        }
      }

      print('🔔 SAHAr Showing ride notification: $title - $body');

      // Vibrate the device
      await _vibrateDevice();

      // Play system notification sound and show notification
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'ride_updates', // channel id
        'Ride Updates', // channel name
        channelDescription: 'Notifications for ride status updates',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('notification'), // System default sound
        styleInformation: BigTextStyleInformation(''),
        category: AndroidNotificationCategory.status,
      );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
      );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await _flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        platformChannelSpecifics,
        payload: '$rideId|$status',
      );

      print('✅ SAHAr Ride notification shown for status: $status');
    } catch (e) {
      print('❌ SAHAr Error showing ride notification: $e');
    }
  }

  /// Vibrate the device with haptic feedback
  Future<void> _vibrateDevice() async {
    try {
      // Use heavy impact haptic feedback for important notifications
      await HapticFeedback.heavyImpact();

      // Wait a bit and vibrate again for emphasis
      await Future.delayed(const Duration(milliseconds: 200));
      await HapticFeedback.heavyImpact();

      print('📳 SAHAr Device vibrated for ride notification');
    } catch (e) {
      print('❌ SAHAr Error vibrating device: $e');
    }
  }

  /// Show notification for new ride (Waiting status)
  Future<void> notifyNewRide({
    required String rideId,
    required String pickupLocation,
    required String passengerName,
  }) async {
    await showRideNotification(
      title: '🚗 New Ride Request!',
      body: 'Pickup: $pickupLocation\nPassenger: $passengerName',
      rideId: rideId,
      status: 'Waiting',
    );
  }

  /// Show notification for ride in progress
  Future<void> notifyRideInProgress({
    required String rideId,
    required String destination,
  }) async {
    await showRideNotification(
      title: '🚕 Ride Started',
      body: 'On the way to: $destination',
      rideId: rideId,
      status: 'In-Progress',
    );
  }

  /// Show notification for completed ride
  Future<void> notifyRideCompleted({
    required String rideId,
    required double fare,
  }) async {
    await showRideNotification(
      title: '✅ Ride Completed',
      body: 'Fare: \$${fare.toStringAsFixed(2)}',
      rideId: rideId,
      status: 'Completed',
    );
  }

  /// Show permission request dialog
  Future<bool> showPermissionRequestDialog() async {
    return await Get.dialog<bool>(
          AlertDialog(
            title: const Text('Enable Ride Notifications'),
            content: const Text(
              'Allow notifications to receive alerts for new rides, ride status updates, and completions.',
              style: TextStyle(fontSize: 16),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Get.back(result: false);
                },
                child: const Text('Not Now'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final granted = await requestNotificationPermission();
                  Get.back(result: granted);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A2A44),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Allow'),
              ),
            ],
          ),
          barrierDismissible: false,
        ) ??
        false;
  }
}

