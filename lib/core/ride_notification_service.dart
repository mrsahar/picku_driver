import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pick_u_driver/routes/app_routes.dart';

class RideNotificationService extends GetxService {
  static RideNotificationService get to => Get.find();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  var isNotificationPermissionGranted = false.obs;
  var hasRequestedPermission = false.obs;

  // Payload separator constant
  static const String _payloadSeparator = '|';

  @override
  void onInit() {
    super.onInit();
    _initializeNotifications();
  }

  /// Initialize notification settings
  Future<void> _initializeNotifications() async {
    // Use app icon for notifications (ic_notification should be in drawable folder)
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_notification');

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

    // Check permission on initialization
    try {
      await checkNotificationPermission();
    } catch (e) {
      print('⚠️ SAHAr Error refreshing ride notification permission on init: $e');
    }
  }

  /// Handle notification tap - parse payload and navigate accordingly
  void _onNotificationTap(NotificationResponse notificationResponse) {
    final String? payload = notificationResponse.payload;
    if (payload == null || payload.isEmpty) {
      print('⚠️ SAHAr Ride notification tapped but payload is empty');
      return;
    }

    try {
      // Parse payload: format is "rideId|status"
      final parts = payload.split(_payloadSeparator);
      if (parts.length != 2) {
        print('⚠️ SAHAr Invalid ride notification payload format: $payload');
        return;
      }

      final String rideId = parts[0];
      final String status = parts[1];

      print('🔔 SAHAr Ride notification tapped - rideId: $rideId, status: $status');

      // Navigate based on status
      switch (status.toLowerCase()) {
        case 'waiting':
        case 'in-progress':
        case 'completed':
          // Navigate to home screen where rides are displayed
          Get.offAllNamed(AppRoutes.HOME);
          break;
        default:
          print('⚠️ SAHAr Unknown ride status: $status');
          Get.offAllNamed(AppRoutes.HOME);
      }
    } catch (e) {
      print('❌ SAHAr Error parsing ride notification payload: $e');
      // Fallback to home screen
      Get.offAllNamed(AppRoutes.HOME);
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

  /// Create payload from ride ID and status
  String _createPayload(String rideId, String status) {
    return '$rideId$_payloadSeparator$status';
  }

  /// Show notification for ride status change with vibration and sound
  Future<void> showRideNotification({
    required String title,
    required String body,
    required String rideId,
    required String status,
    bool isHighPriority = false,
  }) async {
    // Skip if permission not granted
    if (!isNotificationPermissionGranted.value) {
      print('⚠️ SAHAr Skipping ride notification - permission not granted');
      return;
    }

    try {
      print('🔔 SAHAr Showing ride notification: $title - $body');

      // Vibrate the device
      await _vibrateDevice();

      // Configure notification with high priority for heads-up display
      final AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'ride_updates', // channel id
        'Ride Updates', // channel name
        channelDescription: 'Notifications for ride status updates',
        importance: isHighPriority ? Importance.max : Importance.high,
        priority: isHighPriority ? Priority.max : Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('notification'),
        styleInformation: const BigTextStyleInformation(''),
        category: AndroidNotificationCategory.status,
        // Enable heads-up notification for high priority
        fullScreenIntent: isHighPriority,
        visibility: NotificationVisibility.public,
        // Use small icon from drawable (should be white/transparent for Android)
        icon: '@drawable/ic_notification',
      );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      final NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await _flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        platformChannelSpecifics,
        payload: _createPayload(rideId, status),
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

  /// Show high-priority notification for new ride (Waiting status)
  /// This will appear as a heads-up notification
  Future<void> notifyNewRide({
    required String rideId,
    required String pickupLocation,
    required String passengerName,
  }) async {
    await showRideNotification(
      title: '🚗 New Ride from $passengerName',
      body: 'Pickup: $pickupLocation',
      rideId: rideId,
      status: 'Waiting',
      isHighPriority: true, // High priority for heads-up display
    );
  }

  /// Show notification for ride in progress
  Future<void> notifyRideInProgress({
    required String rideId,
    required String destination,
  }) async {
    await showRideNotification(
      title: '🚕 Ride in Progress',
      body: 'Heading to: $destination',
      rideId: rideId,
      status: 'In-Progress',
      isHighPriority: false,
    );
  }

  /// Show notification for completed ride
  Future<void> notifyRideCompleted({
    required String rideId,
    required double fare,
  }) async {
    await showRideNotification(
      title: '✅ Ride Completed',
      body: 'You earned: \$${fare.toStringAsFixed(2)}',
      rideId: rideId,
      status: 'Completed',
      isHighPriority: false,
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

