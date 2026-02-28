import 'dart:async';
import 'dart:io';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pick_u_driver/core/driver_service.dart';
import 'package:pick_u_driver/core/global_variables.dart';
import 'package:pick_u_driver/core/chat_notification_service.dart';
import 'package:pick_u_driver/core/notification_sound_service.dart';
import 'package:pick_u_driver/core/background_tracking_service.dart';
import 'package:pick_u_driver/core/database_helper.dart';
import 'package:pick_u_driver/core/location_service.dart';
import 'package:pick_u_driver/core/map_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pick_u_driver/models/ride_assignment_model.dart';
import 'package:pick_u_driver/models/chat_message_model.dart' as ChatMessageModel;
import 'package:pick_u_driver/models/message_screen_model.dart';


/// Unified SignalR Service — UI Bridge Layer
///
/// This service NO LONGER manages the SignalR HubConnection directly.
/// Instead, it communicates with the background isolate via
/// FlutterBackgroundService. The background isolate handles:
///   - SignalR connection + reconnection
///   - Location tracking (10m distance stream + 60s timer fallback)
///   - All SignalR event listeners
///
/// This class:
///   - Listens for events FROM the background service (bg_*)
///   - Updates reactive (Rx) variables for the UI
///   - Sends commands TO the background service (chat, join, etc.)
class UnifiedSignalRService extends GetxService {
  static UnifiedSignalRService get to => Get.find();

  final GlobalVariables _globalVars = GlobalVariables.instance;
  final FlutterBackgroundService _bgService = FlutterBackgroundService();

  // Observable variables - Connection
  var isConnected = false.obs;
  var connectionStatus = 'Disconnected'.obs;

  // Observable variables - Location Tracking
  var currentRideId = ''.obs;
  var isLocationSending = false.obs;
  var lastSentLocation = Rxn<Position>();
  var locationUpdateCount = 0.obs;

  // Observable variables - Ride Chat
  final rideChatMessages = <ChatMessage>[].obs;
  final isRideChatLoading = false.obs;
  final isRideChatSending = false.obs;

  // Observable variables - Driver-Admin Chat
  final adminChatMessages = <ChatMessageModel.ChatMessage>[].obs;
  final isAdminChatLoading = false.obs;
  final isAdminChatSending = false.obs;

  // Observable variables - Ride Assignment
  var isSubscribed = false.obs;
  var currentRide = Rxn<RideAssignment>();
  var rideStatus = 'No Active Ride'.obs;
  var routePolylines = <Polyline>{}.obs;
  var rideMarkers = <Marker>{}.obs;

  // Track recently sent messages to avoid duplicates
  final Map<String, DateTime> _recentlySentMessages = {};

  // Background service event subscriptions
  final List<StreamSubscription> _bgSubscriptions = [];

  // Configuration
  static const String _emptyGuid = '00000000-0000-0000-0000-000000000000';

  /// Driver info helpers (from DriverService)
  String? get _driverId {
    try {
      if (Get.isRegistered<DriverService>()) {
        return DriverService.to.driverId.value;
      }
    } catch (e) {
      print('⚠️ SAHAr Could not access DriverService: $e');
    }
    return null;
  }

  String? get _driverName {
    try {
      if (Get.isRegistered<DriverService>()) {
        return DriverService.to.driverName.value;
      }
    } catch (e) {
      print('⚠️ SAHAr Could not access DriverService: $e');
    }
    return null;
  }

  @override
  void onInit() {
    super.onInit();
    _listenToBackgroundService();
  }

  // ══════════════════════════════════════════════════════════
  // LISTEN TO BACKGROUND SERVICE EVENTS
  // ══════════════════════════════════════════════════════════

  void _listenToBackgroundService() {
    print('🔗 SAHAr Setting up background service listeners...');

    // --- Connection State ---
    _bgSubscriptions.add(
      _bgService.on('bg_connectionState').listen((event) {
        if (event == null) return;
        final state = event['state']?.toString() ?? '';
        print('🔗 SAHAr [UI] Connection state: $state');

        switch (state) {
          case 'connected':
            isConnected.value = true;
            connectionStatus.value = 'Connected';
            isSubscribed.value = true;
            break;
          case 'disconnected':
            isConnected.value = false;
            connectionStatus.value = 'Disconnected';
            break;
          case 'reconnecting':
            connectionStatus.value = 'Reconnecting...';
            break;
          case 'error':
            isConnected.value = false;
            connectionStatus.value = 'Error: ${event['error']}';
            break;
        }
      }),
    );

    // --- Ride Assigned ---
    _bgSubscriptions.add(
      _bgService.on('bg_RideAssigned').listen((event) {
        if (event == null) return;
        print('🚕 SAHAr [UI] RideAssigned: $event');
        String rideId = event['rideId']?.toString() ?? '';
        if (rideId.isNotEmpty) {
          currentRideId.value = rideId;
          _playNotificationSound();
        }
      }),
    );

    // --- New Ride Assigned ---
    _bgSubscriptions.add(
      _bgService.on('bg_NewRideAssigned').listen((event) {
        if (event == null) return;
        print('🚕 SAHAr [UI] NewRideAssigned: $event');
        if (event['rideId'] != null) {
          currentRideId.value = event['rideId'].toString();
        }
        // Sync full ride to UI: parse and set currentRide + BackgroundTrackingService so home_screen etc. update
        try {
          final data = Map<String, dynamic>.from(event as Map);
          if (data['rideId'] != null && data['pickUpLat'] != null) {
            final ride = RideAssignment.fromJson(data);
            currentRide.value = ride;
            rideStatus.value = ride.status;
            if (Get.isRegistered<BackgroundTrackingService>()) {
              final bg = BackgroundTrackingService.to;
              bg.currentRide.value = ride;
              bg.currentRideId.value = ride.rideId;
              bg.rideStatus.value = ride.status;
            }
          }
        } catch (e) {
          print('⚠️ SAHAr [UI] NewRideAssigned parse/sync: $e');
        }
        _playNotificationSound();
      }),
    );

    // --- Ride Completed ---
    _bgSubscriptions.add(
      _bgService.on('bg_RideCompleted').listen((event) {
        if (event == null) return;
        print('✅ SAHAr [UI] RideCompleted: $event');
        String completedRideId = event['rideId']?.toString() ?? '';
        if (currentRideId.value == completedRideId) {
          currentRideId.value = '';
        }
      }),
    );

    // --- Ride Status Update ---
    _bgSubscriptions.add(
      _bgService.on('bg_RideStatusUpdate').listen((event) {
        if (event == null) return;
        print('📊 SAHAr [UI] RideStatusUpdate: $event');
        if (event['status'] != null) {
          final status = event['status'].toString();
          rideStatus.value = status;
          if (Get.isRegistered<BackgroundTrackingService>()) {
            BackgroundTrackingService.to.rideStatus.value = status;
          }
        }
      }),
    );

    // --- Driver Status Changed ---
    _bgSubscriptions.add(
      _bgService.on('bg_DriverStatusChanged').listen((event) {
        if (event == null) return;
        print('👤 SAHAr [UI] DriverStatusChanged: $event');
        String eventDriverId = event['driverId']?.toString() ?? '';
        if (eventDriverId == _driverId) {
          _playNotificationSound();
        }
      }),
    );

    // --- Location Update ---
    _bgSubscriptions.add(
      _bgService.on('bg_LocationUpdate').listen((event) {
        if (event == null) return;
        locationUpdateCount.value++;
        isLocationSending.value = true;
        // Sync location to UI so map driver marker and currentLatLng update
        try {
          final lat = event['latitude'] as num?;
          final lng = event['longitude'] as num?;
          if (lat != null && lng != null) {
            final latLng = LatLng(lat.toDouble(), lng.toDouble());
            if (Get.isRegistered<LocationService>()) {
              LocationService.to.currentLatLng.value = latLng;
            }
            if (Get.isRegistered<MapService>()) {
              MapService.to.updateDriverMarker(lat.toDouble(), lng.toDouble());
            }
          }
        } catch (e) {
          print('⚠️ SAHAr [UI] bg_LocationUpdate sync: $e');
        }
      }),
    );

    // --- Location Received (ack) ---
    _bgSubscriptions.add(
      _bgService.on('bg_LocationReceived').listen((event) {
        print('📍 SAHAr [UI] Location acknowledged by server');
      }),
    );

    // --- Ride Chat: ReceiveMessage ---
    _bgSubscriptions.add(
      _bgService.on('bg_ReceiveMessage').listen((event) {
        if (event == null) return;
        print('💬 SAHAr [UI] ReceiveMessage: $event');
        _handleRideChatMessage(Map<String, dynamic>.from(event));
      }),
    );

    // --- Ride Chat: History ---
    _bgSubscriptions.add(
      _bgService.on('bg_ReceiveRideChatHistory').listen((event) {
        if (event == null) return;
        print('📜 SAHAr [UI] ReceiveRideChatHistory');
        final messages = event['messages'];
        if (messages is List) {
          _handleRideChatHistory(messages.cast<dynamic>());
        }
      }),
    );

    // --- Admin Chat: ReceiveMessage ---
    _bgSubscriptions.add(
      _bgService.on('bg_ReceiveDriverAdminMessage').listen((event) {
        if (event == null) return;
        print('💬 SAHAr [UI] ReceiveDriverAdminMessage: $event');
        _handleAdminChatMessage(Map<String, dynamic>.from(event));
      }),
    );

    // --- Admin Chat: History ---
    _bgSubscriptions.add(
      _bgService.on('bg_ReceiveDriverAdminChatHistory').listen((event) {
        if (event == null) return;
        print('📜 SAHAr [UI] ReceiveDriverAdminChatHistory');
        final messages = event['messages'];
        if (messages is List) {
          _handleAdminChatHistory(messages.cast<dynamic>());
        }
      }),
    );

    // --- Payment Completed ---
    _bgSubscriptions.add(
      _bgService.on('bg_PaymentCompleted').listen((event) {
        if (event == null) return;
        print('💰 SAHAr [UI] PaymentCompleted: $event');
      }),
    );

    // --- Errors ---
    _bgSubscriptions.add(
      _bgService.on('bg_error').listen((event) {
        if (event == null) return;
        print('❌ SAHAr [UI] Background error: ${event['message']}');
      }),
    );

    // --- Chat Errors ---
    _bgSubscriptions.add(
      _bgService.on('bg_chatError').listen((event) {
        if (event == null) return;
        print('❌ SAHAr [UI] Chat error: ${event['error']} (${event['type']})');
      }),
    );

    print('✅ SAHAr Background service listeners set up');
  }

  // ══════════════════════════════════════════════════════════
  // BACKGROUND SERVICE LIFECYCLE
  // ══════════════════════════════════════════════════════════

  /// Start the background service (call after login when token is saved)
  Future<void> startBackgroundServiceIfNeeded() async {
    final isRunning = await _bgService.isRunning();
    if (!isRunning) {
      // On Android 13+, notification permission is required before starting
      // a foreground service — without it the notification is rejected and
      // the system throws CannotPostForegroundServiceNotificationException.
      if (Platform.isAndroid) {
        final status = await Permission.notification.status;
        if (!status.isGranted) {
          final result = await Permission.notification.request();
          if (!result.isGranted) {
            print('⚠️ SAHAr Notification permission denied — cannot start foreground service');
            return;
          }
        }
      }

      print('🚀 SAHAr Starting background service...');
      await _bgService.startService();
    } else {
      print('✅ SAHAr Background service already running');
    }
  }

  /// Stop the background service (call on logout)
  Future<void> stopBackgroundServiceIfRunning() async {
    final isRunning = await _bgService.isRunning();
    if (isRunning) {
      print('🛑 SAHAr Stopping background service...');
      _bgService.invoke('stopService');
    }
  }

  // ══════════════════════════════════════════════════════════
  // CONNECTION MANAGEMENT (delegate to background)
  // ══════════════════════════════════════════════════════════

  /// Connect — starts the background service if not running
  Future<bool> connect() async {
    await startBackgroundServiceIfNeeded();
    int retries = 0;
    while (!isConnected.value && retries < 10) {
      await Future.delayed(const Duration(milliseconds: 500));
      retries++;
    }
    return isConnected.value;
  }

  /// Disconnect
  Future<void> disconnect() async {
    await stopBackgroundServiceIfRunning();
    isConnected.value = false;
    connectionStatus.value = 'Disconnected';
  }

  /// Reconnect with updated JWT token
  Future<void> reconnectWithNewToken() async {
    print('🔄 SAHAr Reconnecting with new JWT token');
    await stopBackgroundServiceIfRunning();
    await Future.delayed(const Duration(seconds: 1));
    await startBackgroundServiceIfNeeded();
  }

  // ══════════════════════════════════════════════════════════
  // LOCATION TRACKING (now handled by background isolate)
  // ══════════════════════════════════════════════════════════

  /// Start location updates (background service handles this automatically)
  void startLocationUpdates() {
    isLocationSending.value = true;
    locationUpdateCount.value = 0;
    print('🚀 SAHAr Location updates delegated to background service');
  }

  /// Stop location updates
  void stopLocationUpdates() {
    isLocationSending.value = false;
    print('🛑 SAHAr Location updates stop signaled');
  }

  /// Send a single location update via background service
  Future<bool> sendLocationUpdate(double latitude, double longitude) async {
    return isConnected.value;
  }

  // ══════════════════════════════════════════════════════════
  // RIDE CHAT (delegate to background)
  // ══════════════════════════════════════════════════════════

  /// Join ride chat group
  Future<void> joinRideChat(String rideId) async {
    if (rideId.isNotEmpty) {
      _bgService.invoke('joinRideChat', {'rideId': rideId});
      print('💬 SAHAr Join ride chat requested: $rideId');
    }
  }

  /// Load ride chat history
  Future<void> loadRideChatHistory(String rideId) async {
    if (rideId.isEmpty) return;
    isRideChatLoading.value = true;
    _bgService.invoke('loadRideChatHistory', {'rideId': rideId});
    print('📜 SAHAr Ride chat history requested: $rideId');
  }

  /// Load ride chat history from local database for immediate display.
  Future<List<ChatMessage>> getLocalRideChatHistory(String rideId) async {
    if (rideId.isEmpty) {
      print('⚠️ SAHAr Cannot load local chat history - empty ride ID');
      return [];
    }

    if (!Get.isRegistered<DatabaseHelper>()) {
      print('⚠️ SAHAr DatabaseHelper not registered, skipping local chat history load');
      return [];
    }

    try {
      final rows = await DatabaseHelper.to.getRideChatMessages(rideId);
      final messages = <ChatMessage>[];

      for (final row in rows) {
        try {
          final timestampMs = row['timestamp'] as int;
          final dateTime = DateTime.fromMillisecondsSinceEpoch(timestampMs);
          final msg = ChatMessage(
            senderId: row['sender_id']?.toString() ?? '',
            senderRole: row['sender_role']?.toString() ?? '',
            message: row['message']?.toString() ?? '',
            dateTime: dateTime,
          );

          final userId = _driverId ?? '';
          final isFromCurrentUser =
              msg.senderRole.toLowerCase() == 'driver' || msg.senderId == userId;

          messages.add(msg.copyWith(isFromCurrentUser: isFromCurrentUser));
        } catch (e) {
          print('❌ SAHAr Error mapping local chat row: $e');
        }
      }

      print('✅ SAHAr Loaded ${messages.length} local ride chat messages for $rideId');
      return messages;
    } catch (e) {
      print('❌ SAHAr Error loading local chat history: $e');
      return [];
    }
  }

  /// Send ride chat message
  Future<void> sendRideChatMessage({
    required String rideId,
    required String senderId,
    required String message,
    String? senderRole,
  }) async {
    final role = senderRole ?? 'Driver';

    try {
      isRideChatSending.value = true;

      // Add message optimistically
      final now = DateTime.now();
      final newMessage = ChatMessage(
        senderId: senderId,
        senderRole: role,
        message: message,
        dateTime: now,
        isFromCurrentUser: true,
      );

      rideChatMessages.add(newMessage);
      rideChatMessages.refresh();
      print('📤 SAHAr Optimistically added message. Total: ${rideChatMessages.length}');

      // Persist locally
      _saveRideChatMessageToLocal(rideId: rideId, message: newMessage);

      // Track to avoid duplicates
      _recentlySentMessages[message] = now;
      Future.delayed(const Duration(seconds: 5), () {
        _recentlySentMessages.remove(message);
      });

      // Send via background service
      _bgService.invoke('sendRideChatMessage', {
        'rideId': rideId,
        'senderId': senderId,
        'message': message,
        'senderRole': role,
      });

      print('💬 SAHAr Ride chat message sent via background service');
    } catch (e) {
      print('❌ SAHAr Failed to send ride chat message: $e');
      if (rideChatMessages.isNotEmpty && rideChatMessages.last.message == message) {
        rideChatMessages.removeLast();
      }
    } finally {
      isRideChatSending.value = false;
    }
  }

  /// Clear ride chat messages
  void clearRideChatMessages() {
    rideChatMessages.clear();
  }

  // ══════════════════════════════════════════════════════════
  // DRIVER-ADMIN CHAT (delegate to background)
  // ══════════════════════════════════════════════════════════

  /// Join driver support group
  Future<void> joinDriverSupport() async {
    _bgService.invoke('joinDriverSupport');
    print('🎧 SAHAr Join driver support requested');
  }

  /// Load driver-admin chat history
  Future<void> loadDriverAdminChatHistory() async {
    isAdminChatLoading.value = true;
    _bgService.invoke('loadAdminChatHistory');
    print('📜 SAHAr Admin chat history requested');
  }

  /// Send driver-admin chat message
  Future<void> sendDriverAdminMessage(String message) async {
    try {
      isAdminChatSending.value = true;
      _bgService.invoke('sendAdminMessage', {'message': message});
      print('💬 SAHAr Admin message sent via background service');
      await Future.delayed(const Duration(milliseconds: 500));
      await loadDriverAdminChatHistory();
    } catch (e) {
      print('❌ SAHAr Failed to send admin message: $e');
    } finally {
      isAdminChatSending.value = false;
    }
  }

  /// Clear admin chat messages
  void clearAdminChatMessages() {
    adminChatMessages.clear();
  }

  // ══════════════════════════════════════════════════════════
  // EVENT HANDLERS (process data FROM background service)
  // ══════════════════════════════════════════════════════════

  void _handleRideChatMessage(Map<String, dynamic> messageData) {
    try {
      print('📨 SAHAr _handleRideChatMessage: $messageData');

      final chatMessage = ChatMessage.fromJson(messageData);
      final userId = _driverId ?? '';

      final isFromCurrentUser = chatMessage.senderRole.toLowerCase() == 'driver' ||
          chatMessage.senderId == userId;

      // Check for duplicates
      if (isFromCurrentUser && _recentlySentMessages.containsKey(chatMessage.message)) {
        final sentTime = _recentlySentMessages[chatMessage.message]!;
        final timeDifference = chatMessage.dateTime.difference(sentTime).abs();
        if (timeDifference.inSeconds < 3) {
          print('⏭️ SAHAr Skipping duplicate ride chat message');
          _recentlySentMessages.remove(chatMessage.message);
          return;
        }
      }

      final messageWithUserFlag = chatMessage.copyWith(isFromCurrentUser: isFromCurrentUser);

      rideChatMessages.add(messageWithUserFlag);
      rideChatMessages.refresh();
      print('✅ SAHAr Message added. Total: ${rideChatMessages.length}');

      // Persist locally
      _saveRideChatMessageToLocal(
        rideId: currentRideId.value.isEmpty ? _emptyGuid : currentRideId.value,
        message: messageWithUserFlag,
      );

      // Show notification for passenger messages
      if (!isFromCurrentUser) {
        _showChatNotification(chatMessage);
      }
    } catch (e) {
      print('❌ SAHAr Error handling ride chat message: $e');
    }
  }

  void _handleRideChatHistory(List<dynamic> chatHistory) {
    try {
      print('📜 SAHAr Processing ride chat history: ${chatHistory.length} messages');

      if (chatHistory.isEmpty) {
        rideChatMessages.clear();
        isRideChatLoading.value = false;
        return;
      }

      List<ChatMessage> loadedMessages = [];
      final userId = _driverId ?? '';

      for (var messageData in chatHistory) {
        try {
          final chatMessage = ChatMessage.fromJson(messageData as Map<String, dynamic>);
          final isFromCurrentUser = chatMessage.senderRole.toLowerCase() == 'driver' ||
              chatMessage.senderId == userId;
          loadedMessages.add(chatMessage.copyWith(isFromCurrentUser: isFromCurrentUser));
        } catch (e) {
          print('❌ SAHAr Error processing ride chat message: $e');
        }
      }

      rideChatMessages.assignAll(loadedMessages);
      print('✅ SAHAr Loaded ${loadedMessages.length} ride chat messages');

      // Persist locally
      _saveRideChatHistoryToLocal(
        rideId: currentRideId.value.isEmpty ? _emptyGuid : currentRideId.value,
        messages: loadedMessages,
      );
    } catch (e) {
      print('❌ SAHAr Error handling ride chat history: $e');
    } finally {
      isRideChatLoading.value = false;
    }
  }

  void _handleAdminChatMessage(Map<String, dynamic> messageData) {
    try {
      final newMessage = ChatMessageModel.ChatMessage.fromJson(messageData);
      adminChatMessages.add(newMessage);
      print('💬 SAHAr Received admin message: ${newMessage.message}');
    } catch (e) {
      print('❌ SAHAr Error handling admin message: $e');
    }
  }

  void _handleAdminChatHistory(List<dynamic> historyList) {
    try {
      adminChatMessages.clear();
      for (var item in historyList) {
        final message = ChatMessageModel.ChatMessage.fromJson(item as Map<String, dynamic>);
        adminChatMessages.add(message);
      }
      print('✅ SAHAr Loaded ${adminChatMessages.length} admin messages');
    } catch (e) {
      print('❌ SAHAr Error handling admin chat history: $e');
    } finally {
      isAdminChatLoading.value = false;
    }
  }

  // ══════════════════════════════════════════════════════════
  // LOCAL PERSISTENCE (unchanged from before)
  // ══════════════════════════════════════════════════════════

  void _saveRideChatMessageToLocal({
    required String rideId,
    required ChatMessage message,
  }) {
    if (rideId.isEmpty) return;
    if (!Get.isRegistered<DatabaseHelper>()) {
      print('⚠️ SAHAr DatabaseHelper not registered, skipping local chat save');
      return;
    }

    try {
      DatabaseHelper.to.insertRideChatMessage(
        rideId: rideId,
        senderId: message.senderId,
        senderRole: message.senderRole,
        message: message.message,
        timestamp: message.dateTime,
      );
    } catch (e) {
      print('⚠️ SAHAr Error saving chat message locally: $e');
    }
  }

  void _saveRideChatHistoryToLocal({
    required String rideId,
    required List<ChatMessage> messages,
  }) {
    if (rideId.isEmpty) return;
    if (!Get.isRegistered<DatabaseHelper>()) {
      print('⚠️ SAHAr DatabaseHelper not registered, skipping local chat history save');
      return;
    }

    () async {
      try {
        await DatabaseHelper.to.clearRideChatMessages(rideId);
        for (final msg in messages) {
          await DatabaseHelper.to.insertRideChatMessage(
            rideId: rideId,
            senderId: msg.senderId,
            senderRole: msg.senderRole,
            message: msg.message,
            timestamp: msg.dateTime,
          );
        }
        print('✅ SAHAr Saved ${messages.length} chat history messages locally for $rideId');
      } catch (e) {
        print('⚠️ SAHAr Error saving chat history locally: $e');
      }
    }();
  }

  // ══════════════════════════════════════════════════════════
  // UTILITY METHODS
  // ══════════════════════════════════════════════════════════

  void _playNotificationSound() {
    try {
      if (Get.isRegistered<NotificationSoundService>()) {
        NotificationSoundService.to.playNotificationSound();
      }
    } catch (e) {
      print('⚠️ SAHAr Could not play notification sound: $e');
    }
  }

  void _showChatNotification(ChatMessage chatMessage) {
    try {
      if (Get.isRegistered<ChatNotificationService>()) {
        final notificationService = Get.find<ChatNotificationService>();

        String senderName = 'Passenger';
        if (chatMessage.senderRole.toLowerCase() == 'passenger') {
          try {
            if (Get.isRegistered<BackgroundTrackingService>()) {
              final backgroundService = Get.find<BackgroundTrackingService>();
              if (backgroundService.currentRide.value != null) {
                senderName = backgroundService.currentRide.value!.passengerName;
              }
            }
          } catch (e) {
            print('⚠️ SAHAr Could not get passenger name: $e');
          }
        }

        notificationService.showChatMessageNotification(
          senderName: senderName,
          message: chatMessage.message,
          rideId: currentRideId.value,
        );
      }
    } catch (e) {
      print('⚠️ SAHAr Could not show notification: $e');
    }
  }

  /// Get current connection and tracking info for debugging
  Map<String, dynamic> getConnectionInfo() {
    return {
      'isConnected': isConnected.value,
      'connectionStatus': connectionStatus.value,
      'currentRideId': currentRideId.value,
      'isLocationSending': isLocationSending.value,
      'locationUpdateCount': locationUpdateCount.value,
      'driverId': _driverId,
      'driverName': _driverName,
      'hasJwtToken': _globalVars.userToken.isNotEmpty,
      'lastSentLocation': lastSentLocation.value != null
          ? {
              'lat': lastSentLocation.value!.latitude,
              'lng': lastSentLocation.value!.longitude,
              'timestamp': lastSentLocation.value!.timestamp.toString(),
            }
          : null,
    };
  }

  @override
  void onClose() {
    for (var sub in _bgSubscriptions) {
      sub.cancel();
    }
    _bgSubscriptions.clear();
    super.onClose();
  }
}

