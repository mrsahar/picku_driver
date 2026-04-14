import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:pick_u_driver/core/chat_notification_service.dart';
import 'package:pick_u_driver/core/global_variables.dart';
import 'package:pick_u_driver/core/ride_notification_service.dart';
import 'package:pick_u_driver/core/sharePref.dart';
import 'package:pick_u_driver/providers/api_provider.dart';
import 'package:pick_u_driver/routes/app_routes.dart';

// Keep these IDs in sync with the notification services; background isolate cannot depend on Get services.
const String _bgDriverChatChannelId = 'chat_messages_pick_u_driver_v4';
const String _bgDriverChatChannelName = 'Chat Messages';
const String _bgDriverRideChannelId = 'ride_updates_pick_u_driver_v4';
const String _bgDriverRideChannelName = 'Ride Updates';

@pragma('vm:entry-point')
Future<void> _bgEnsureAndroidChannels(FlutterLocalNotificationsPlugin fln) async {
  if (!Platform.isAndroid) return;
  final androidPlugin =
      fln.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  if (androidPlugin == null) return;

  const chatChannel = AndroidNotificationChannel(
    _bgDriverChatChannelId,
    _bgDriverChatChannelName,
    description: 'Notifications for new chat messages',
    importance: Importance.max,
    enableVibration: true,
    playSound: true,
    showBadge: true,
  );
  const rideChannel = AndroidNotificationChannel(
    _bgDriverRideChannelId,
    _bgDriverRideChannelName,
    description: 'Notifications for ride status updates',
    importance: Importance.max,
    enableVibration: true,
    playSound: true,
    showBadge: true,
  );

  await androidPlugin.createNotificationChannel(chatChannel);
  await androidPlugin.createNotificationChannel(rideChannel);
}

@pragma('vm:entry-point')
Future<void> _bgShowLocalNotification({
  required RemoteMessage message,
  required Map<String, dynamic> data,
}) async {
  final fln = FlutterLocalNotificationsPlugin();
  const initSettings = InitializationSettings(
    android: AndroidInitializationSettings('@drawable/ic_notification'),
    iOS: DarwinInitializationSettings(),
  );
  await fln.initialize(initSettings);
  await _bgEnsureAndroidChannels(fln);

  final type = (data['type'] ?? '').toString();
  final rideId = (data['rideId'] ?? '').toString();
  final title =
      message.notification?.title ?? (data['title'] ?? (type == 'ride_chat_message' ? 'New message' : 'PickU Driver')).toString();
  final body = message.notification?.body ?? (data['body'] ?? data['message'] ?? '').toString();

  if (type.toLowerCase() == 'ride_chat_message' && rideId.isNotEmpty) {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _bgDriverChatChannelId,
        _bgDriverChatChannelName,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        icon: '@drawable/ic_notification',
        category: AndroidNotificationCategory.message,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    await fln.show(
      rideId.hashCode.abs(),
      title,
      body,
      details,
      payload: rideId, // ChatNotificationService expects rideId payload
    );
    return;
  }

  // Ride updates: keep payload compatible with RideNotificationService ("rideId|status").
  final status = type.isEmpty ? 'update' : type;
  const details = NotificationDetails(
    android: AndroidNotificationDetails(
      _bgDriverRideChannelId,
      _bgDriverRideChannelName,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      icon: '@drawable/ic_notification',
      category: AndroidNotificationCategory.status,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );
  await fln.show(
    DateTime.now().millisecondsSinceEpoch.remainder(100000),
    title,
    body,
    details,
    payload: rideId.isNotEmpty ? '$rideId|$status' : null,
  );
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}

  // Only show a local notification for data-only messages; otherwise the OS will display it.
  try {
    if (message.notification != null) return;
    final data = message.data;
    if (data.isEmpty) return;
    await _bgShowLocalNotification(message: message, data: Map<String, dynamic>.from(data));
  } catch (_) {}
}

class PushService extends GetxService {
  static PushService get to => Get.find<PushService>();

  final RxString _fcmToken = ''.obs;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedSub;

  String get currentToken => _fcmToken.value;

  @override
  Future<void> onInit() async {
    super.onInit();
    await _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadCachedToken();
    await ensurePermissions();
    await _syncTokenFromFcm();
    _listenTokenRefresh();
    _listenMessages();
    await _handleColdStartMessage();
  }

  Future<void> ensurePermissions() async {
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {}
  }

  Future<void> _loadCachedToken() async {
    final cached = await SharedPrefsService.getFcmToken();
    if (cached != null && cached.isNotEmpty) {
      _fcmToken.value = cached;
    }
  }

  Future<void> _syncTokenFromFcm() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await _setToken(token, sendToServerIfLoggedIn: false);
    } catch (_) {}
  }

  void _listenTokenRefresh() {
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      await _setToken(token, sendToServerIfLoggedIn: true);
    });
  }

  void _listenMessages() {
    _onMessageSub?.cancel();
    _onMessageSub = FirebaseMessaging.onMessage.listen((message) async {
      await _handleIncomingMessage(message, appWasOpenedByTap: false);
    });

    _onMessageOpenedSub?.cancel();
    _onMessageOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen((message) async {
      await _handleIncomingMessage(message, appWasOpenedByTap: true);
    });
  }

  Future<void> _handleColdStartMessage() async {
    try {
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        await _handleIncomingMessage(initial, appWasOpenedByTap: true);
      }
    } catch (_) {}
  }

  Future<void> _setToken(String token, {required bool sendToServerIfLoggedIn}) async {
    _fcmToken.value = token;
    await SharedPrefsService.saveFcmToken(token);

    if (!sendToServerIfLoggedIn) return;

    final jwt = GlobalVariables.instance.userToken;
    if (jwt.isEmpty) return;

    try {
      final api = Get.find<ApiProvider>();
      await api.updateFcmToken(token);
    } catch (_) {}
  }

  Future<void> _handleIncomingMessage(RemoteMessage message, {required bool appWasOpenedByTap}) async {
    final data = message.data;
    if (data.isEmpty) return;

    final type = (data['type'] ?? '').toString();
    final rideId = (data['rideId'] ?? '').toString();

    if (!appWasOpenedByTap) {
      await _showForegroundNotification(type: type, rideId: rideId, data: data, message: message);
      return;
    }

    _routeFromData(type: type, rideId: rideId, data: data);
  }

  Future<void> _showForegroundNotification({
    required String type,
    required String rideId,
    required Map<String, dynamic> data,
    required RemoteMessage message,
  }) async {
    final title = message.notification?.title ?? _titleFromType(type);
    final body = message.notification?.body ?? (data['body'] ?? data['message'] ?? '').toString();

    switch (type) {
      case 'ride_chat_message':
        if (Get.isRegistered<ChatNotificationService>() && rideId.isNotEmpty) {
          await ChatNotificationService.to.showChatMessageNotification(
            senderName: (data['senderName'] ?? data['senderRole'] ?? 'Passenger').toString(),
            message: body,
            rideId: rideId,
          );
        }
        break;
      case 'ride_completed':
      case 'payment_success':
        if (Get.isRegistered<RideNotificationService>() && rideId.isNotEmpty) {
          await RideNotificationService.to.showRideNotification(
            title: title,
            body: body,
            rideId: rideId,
            status: type,
            isHighPriority: false,
          );
        }
        break;
      default:
        if (Get.isRegistered<RideNotificationService>() && rideId.isNotEmpty) {
          await RideNotificationService.to.showRideNotification(
            title: title,
            body: body,
            rideId: rideId,
            status: type.isEmpty ? 'update' : type,
          );
        }
        break;
    }
  }

  void _routeFromData({required String type, required String rideId, required Map<String, dynamic> data}) {
    switch (type) {
      case 'ride_chat_message':
        if (rideId.isNotEmpty) {
          Get.toNamed(AppRoutes.chatScreen, arguments: rideId);
        }
        break;
      case 'ride_completed':
      case 'payment_success':
        Get.offAllNamed(AppRoutes.HOME);
        break;
      default:
        Get.offAllNamed(AppRoutes.HOME);
        break;
    }
  }

  String _titleFromType(String type) {
    switch (type) {
      case 'ride_completed':
        return 'Ride completed';
      case 'payment_success':
        return 'Payment successful';
      case 'ride_chat_message':
        return 'New message';
      default:
        return 'PickU Driver';
    }
  }

  @override
  void onClose() {
    _tokenRefreshSub?.cancel();
    _onMessageSub?.cancel();
    _onMessageOpenedSub?.cancel();
    super.onClose();
  }
}

