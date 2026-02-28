import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pick_u_driver/core/notification_sound_service.dart';
import 'package:pick_u_driver/routes/app_routes.dart';

class ChatNotificationService extends GetxService {
  static ChatNotificationService get to => Get.find();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  var isNotificationPermissionGranted = false.obs;
  var hasRequestedPermission = false.obs;
  var isOnChatScreen = false.obs;

  @override
  void onInit() {
    super.onInit();
    _initializeNotifications();
  }

  /// Initialize notification settings
  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@drawable/ic_notification');

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

    print('🔔 SAHAr Chat Notification service initialized');

    // Refresh permission flag so notifications can work even before chat screen opens
    try {
      await checkNotificationPermission();
    } catch (e) {
      print('⚠️ SAHAr Error refreshing notification permission on init: $e');
    }
  }

  /// Handle notification tap - navigate to chat screen with ride ID
  void _onNotificationTap(NotificationResponse notificationResponse) {
    final String? payload = notificationResponse.payload;
    if (payload != null && payload.isNotEmpty) {
      print('🔔 SAHAr Chat notification tapped with rideId: $payload');

      // Navigate to chat screen with the ride ID
      try {
        Get.toNamed(AppRoutes.chatScreen, arguments: payload);
      } catch (e) {
        print('❌ SAHAr Error navigating to chat screen: $e');
      }
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
        print('✅ SAHAr Chat notification permission granted');
        return true;
      } else if (status.isDenied) {
        isNotificationPermissionGranted.value = false;
        print('❌ SAHAr Chat notification permission denied');
        return false;
      } else if (status.isPermanentlyDenied) {
        isNotificationPermissionGranted.value = false;
        print('❌ SAHAr Chat notification permission permanently denied');
        return false;
      }

      return false;
    } catch (e) {
      print('❌ SAHAr Error requesting chat notification permission: $e');
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
      print('❌ SAHAr Error checking chat notification permission: $e');
      return false;
    }
  }

  /// Show notification for new chat message
  Future<void> showChatMessageNotification({
    required String senderName,
    required String message,
    required String rideId,
  }) async {
    // Don't show notification if user is on chat screen
    if (isOnChatScreen.value) {
      print('⏭️ SAHAr Skipping notification - user is on chat screen');
      return;
    }

    // Don't show notification if permission not granted
    if (!isNotificationPermissionGranted.value) {
      print('⏭️ SAHAr Skipping notification - permission not granted');
      return;
    }

    try {
      // Play custom notification sound via NotificationSoundService
      // This prevents sound overlap with system notification sound
      try {
        if (Get.isRegistered<NotificationSoundService>()) {
          await NotificationSoundService.to.playNotificationSound();
        }
      } catch (e) {
        print('⚠️ SAHAr Could not play notification sound: $e');
      }

      // Configure notification WITHOUT system sound to prevent overlap
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'chat_messages', // channel id
        'Chat Messages', // channel name
        channelDescription: 'Notifications for new chat messages',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: false, // Disabled to prevent overlap - sound played via NotificationSoundService
        styleInformation: BigTextStyleInformation(''),
        category: AndroidNotificationCategory.message,
        icon: '@drawable/ic_notification', // Use notification icon (white vector drawable)
      );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await _flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        'Message from Passenger',
        message,
        platformChannelSpecifics,
        payload: rideId, // Pass rideId for navigation
      );

      print('🔔 SAHAr Chat notification shown for message from $senderName');
    } catch (e) {
      print('❌ SAHAr Error showing chat notification: $e');
    }
  }

  /// Mark that user is on chat screen
  void setOnChatScreen(bool isOnScreen) {
    isOnChatScreen.value = isOnScreen;
    print('📱 SAHAr isOnChatScreen: $isOnScreen');
  }

  /// Show permission request dialog
  Future<bool> showPermissionRequestDialog() async {
    return await Get.dialog<bool>(
          AlertDialog(
            title: const Text('Enable Chat Notifications'),
            content: const Text(
              'Allow notifications to receive messages from passengers even when you\'re not in the chat.',
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

