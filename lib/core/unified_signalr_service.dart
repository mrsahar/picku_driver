import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pick_u_driver/core/sharePref.dart';
import 'package:pick_u_driver/core/global_variables.dart';
import 'package:pick_u_driver/core/chat_notification_service.dart';
import 'package:signalr_core/signalr_core.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pick_u_driver/models/ride_assignment_model.dart';
import 'package:pick_u_driver/models/chat_message_model.dart' as ChatMessageModel;
import 'package:pick_u_driver/models/message_screen_model.dart';


/// Unified SignalR Service
/// Handles all SignalR functionality including:
/// - Location tracking
/// - Ride chat
/// - Driver-Admin chat
/// - Ride assignment
/// - All with JWT authentication
class UnifiedSignalRService extends GetxService {
  static UnifiedSignalRService get to => Get.find();

  final GlobalVariables _globalVars = GlobalVariables.instance;

  // SignalR connection (single connection for everything)
  HubConnection? _hubConnection;

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

  // Driver information
  String? _driverId;
  String? _driverName;

  // Timers and streams
  Timer? _locationTimer;
  StreamSubscription<Position>? _positionStream;

  // Configuration
  static const String _hubUrl = 'http://pickurides.com/ridechathub/';
  static const String _emptyGuid = '00000000-0000-0000-0000-000000000000';
  static const double _minimumDistanceFilter = 10.0; // meters

  // Track recently sent messages to avoid duplicates
  final Map<String, DateTime> _recentlySentMessages = {};

  @override
  void onInit() {
    super.onInit();
    _loadDriverInfo();
    _initializeConnection();
  }

  /// Load driver information from SharedPreferences
  Future<void> _loadDriverInfo() async {
    try {
      _driverId = await SharedPrefsService.getUserId();
      _driverName = await SharedPrefsService.getUserFullName();

      // Ensure we have valid driver info
      if (_driverId == null || _driverId!.isEmpty) {
        print('❌ SAHAr Driver ID is null or empty, retrying...');
        await Future.delayed(const Duration(seconds: 2));
        _driverId = await SharedPrefsService.getUserId();
      }

      if (_driverName == null || _driverName!.isEmpty) {
        print('❌ SAHAr Driver name is null or empty, retrying...');
        await Future.delayed(const Duration(seconds: 2));
        _driverName = await SharedPrefsService.getUserFullName();
      }

      print('🚗 SAHAr Driver info loaded: $_driverName ($_driverId)');
    } catch (e) {
      print('❌ SAHAr Error loading driver info: $e');
      Timer(const Duration(seconds: 5), () => _loadDriverInfo());
    }
  }

  /// Set driver information manually
  void setDriverInfo(String driverId, String driverName) {
    _driverId = driverId;
    _driverName = driverName;
    print('🚗 SAHAr Driver info set: $driverName ($driverId)');
  }

  /// Initialize SignalR connection with JWT authentication
  Future<void> _initializeConnection() async {
    try {
      // Get JWT token from GlobalVariables
      final jwtToken = _globalVars.userToken;

      if (jwtToken.isEmpty) {
        print('⚠️ SAHAr No JWT token available, waiting for login...');
        connectionStatus.value = 'No token available';
        return;
      }

      print('🔐 SAHAr Initializing SignalR with JWT authentication');

      _hubConnection = HubConnectionBuilder()
          .withUrl(
        _hubUrl,
        HttpConnectionOptions(
          accessTokenFactory: () async => jwtToken,
          logging: (level, message) => print('SignalR: $message'),
        ),
      )
          .withAutomaticReconnect([2000, 5000, 10000, 15000, 30000])
          .build();

      _setupConnectionHandlers();
      print('✅ SAHAr SignalR hub initialized with JWT');
    } catch (e) {
      print('❌ SAHAr Error initializing SignalR: $e');
      connectionStatus.value = 'Error: $e';
    }
  }

  /// Set up connection event handlers for all features
  void _setupConnectionHandlers() {
    if (_hubConnection == null) return;

    // ==================== Connection State Changes ====================
    _hubConnection!.onclose((error) {
      print('🔴 SAHAr SignalR connection closed: $error');
      isConnected.value = false;
      connectionStatus.value = 'Disconnected';

      if (isLocationSending.value) {
        _pauseLocationUpdates();
      }
    });

    _hubConnection!.onreconnecting((error) {
      print('🟡 SAHAr SignalR reconnecting: $error');
      connectionStatus.value = 'Reconnecting...';
    });

    _hubConnection!.onreconnected((connectionId) {
      print('🟢 SAHAr SignalR reconnected: $connectionId');
      isConnected.value = true;
      connectionStatus.value = 'Connected';

      if (isLocationSending.value) {
        _resumeLocationUpdates();
      }
    });

    // ==================== Location Tracking Events ====================
    _hubConnection!.on('RideAssigned', (List<Object?>? arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        String newRideId = arguments[0].toString();
        print('🚕 SAHAr Ride assigned: $newRideId');
        currentRideId.value = newRideId;
        _onRideAssigned(newRideId);
      }
    });

    _hubConnection!.on('RideCompleted', (List<Object?>? arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        String completedRideId = arguments[0].toString();
        print('✅ SAHAr Ride completed: $completedRideId');

        if (currentRideId.value == completedRideId) {
          currentRideId.value = '';
          _onRideCompleted(completedRideId);
        }
      }
    });

    _hubConnection!.on('LocationReceived', (List<Object?>? arguments) {
      print('📍 SAHAr Location update acknowledged by server');
    });

    _hubConnection!.on('DriverStatusChanged', (List<Object?>? arguments) {
      if (arguments != null && arguments.length >= 2) {
        String driverId = arguments[0].toString();
        bool isOnline = arguments[1] as bool;

        if (driverId == _driverId) {
          print('👤 SAHAr Driver status changed from server: $isOnline');
        }
      }
    });

    // ==================== Ride Chat Events ====================
    _hubConnection!.on('ReceiveMessage', (List<Object?>? arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        final messageData = arguments[0] as Map<String, dynamic>;
        _handleRideChatMessage(messageData);
      }
    });

    _hubConnection!.on('ReceiveRideChatHistory', (List<Object?>? arguments) {
      print('📜 SAHAr ReceiveRideChatHistory event triggered');
      if (arguments != null && arguments.isNotEmpty) {
        final historyData = arguments[0] as List<dynamic>;
        print('📜 SAHAr Chat history data received: ${historyData.length} messages');
        _handleRideChatHistory(historyData);
      }
    });

    // ==================== Driver-Admin Chat Events ====================
    _hubConnection!.on('ReceiveDriverAdminMessage', (List<Object?>? arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        final messageData = arguments[0] as Map<String, dynamic>;
        _handleAdminChatMessage(messageData);
      }
    });

    _hubConnection!.on('ReceiveDriverAdminChatHistory', (List<Object?>? arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        final historyList = arguments[0] as List<dynamic>;
        _handleAdminChatHistory(historyList);
      }
    });
  }

  // ==================== Connection Management ====================

  /// Connect to SignalR hub
  Future<bool> connect() async {
    if (_hubConnection == null) {
      await _initializeConnection();
      if (_hubConnection == null) return false;
    }

    try {
      connectionStatus.value = 'Connecting...';
      await _hubConnection!.start();
      isConnected.value = true;
      connectionStatus.value = 'Connected';
      print('✅ SAHAr Successfully connected to SignalR hub');
      return true;
    } catch (e) {
      print('❌ SAHAr Failed to connect to SignalR: $e');
      isConnected.value = false;
      connectionStatus.value = 'Connection failed: $e';
      return false;
    }
  }

  /// Disconnect from SignalR hub
  Future<void> disconnect() async {
    if (_hubConnection != null) {
      await _hubConnection!.stop();
      _stopLocationUpdates();
      isConnected.value = false;
      connectionStatus.value = 'Disconnected';
    }
  }

  /// Reconnect with updated JWT token
  Future<void> reconnectWithNewToken() async {
    print('🔄 SAHAr Reconnecting with new JWT token');
    await disconnect();
    await _initializeConnection();
    await connect();
  }

  // ==================== Location Tracking ====================

  /// Send location update to SignalR hub
  Future<bool> sendLocationUpdate(double latitude, double longitude) async {
    if (!isConnected.value || _hubConnection == null) {
      print('⚠️ SAHAr Cannot send location: not connected');
      return false;
    }

    if (_driverId == null || _driverName == null) {
      print('⚠️ SAHAr Cannot send location: driver info not set');
      return false;
    }

    try {
      String rideId = currentRideId.value.isEmpty ? _emptyGuid : currentRideId.value;

      await _hubConnection!.invoke(
          'UpdateLocation',
          args: [rideId, _driverId, _driverName, latitude, longitude]
      );

      locationUpdateCount.value++;
      print('📍 SAHAr Location sent successfully (Count: ${locationUpdateCount.value})');
      return true;
    } catch (e) {
      print('❌ SAHAr Error sending location: $e');
      return false;
    }
  }

  /// Start continuous location updates
  Future<void> startLocationUpdates({Duration interval = const Duration(seconds: 5)}) async {
    if (isLocationSending.value) {
      print('⚠️ SAHAr Location updates already running');
      return;
    }

    await _loadDriverInfo();

    if (_driverId == null || _driverName == null) {
      print('❌ SAHAr Cannot start location updates: driver info not available');
      Get.snackbar('Error', 'Driver information not available. Please login again.');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      print('❌ SAHAr Location permission denied');
      Get.snackbar('Permission Required', 'Location permission is needed for live tracking');
      return;
    }

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('❌ SAHAr Location services are disabled');
      Get.snackbar('GPS Required', 'Please enable GPS to start location tracking');
      return;
    }

    isLocationSending.value = true;
    locationUpdateCount.value = 0;
    print('🚀 SAHAr Starting continuous location updates every ${interval.inSeconds}s');

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
          (Position position) async {
        if (_shouldSendLocationUpdate(position)) {
          bool success = await sendLocationUpdate(position.latitude, position.longitude);
          if (success) {
            lastSentLocation.value = position;
          } else if (!isConnected.value) {
            await connect();
          }
        }
      },
      onError: (error) {
        print('❌ SAHAr Position stream error: $error');
      },
    );

    _locationTimer = Timer.periodic(interval, (timer) async {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        bool success = await sendLocationUpdate(position.latitude, position.longitude);
        if (success) {
          lastSentLocation.value = position;
        } else if (!isConnected.value) {
          await connect();
        }
      } catch (e) {
        print('❌ SAHAr Error getting location in timer: $e');
      }
    });

    // Send initial location immediately
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      bool success = await sendLocationUpdate(position.latitude, position.longitude);
      if (success) {
        lastSentLocation.value = position;
      }
    } catch (e) {
      print('❌ SAHAr Error sending initial location: $e');
    }
  }

  /// Stop continuous location updates
  void stopLocationUpdates() {
    _stopLocationUpdates();
  }

  void _stopLocationUpdates() {
    _locationTimer?.cancel();
    _locationTimer = null;
    _positionStream?.cancel();
    _positionStream = null;
    isLocationSending.value = false;
    print('🛑 SAHAr All location updates stopped');
  }

  void _pauseLocationUpdates() {
    _positionStream?.pause();
    print('⏸️ SAHAr Location updates paused');
  }

  void _resumeLocationUpdates() {
    if (_positionStream != null && _positionStream!.isPaused) {
      _positionStream!.resume();
      print('▶️ SAHAr Location updates resumed');
    }
  }

  bool _shouldSendLocationUpdate(Position newPosition) {
    if (lastSentLocation.value == null) return true;

    double distance = Geolocator.distanceBetween(
      lastSentLocation.value!.latitude,
      lastSentLocation.value!.longitude,
      newPosition.latitude,
      newPosition.longitude,
    );

    return distance >= _minimumDistanceFilter;
  }

  void _onRideAssigned(String rideId) {
    Get.snackbar(
      'Ride Assigned',
      'You have been assigned ride: ${rideId.substring(0, 8)}...',
      duration: const Duration(seconds: 5),
      backgroundColor: Colors.green.shade100,
      colorText: Colors.green.shade800,
    );
  }

  void _onRideCompleted(String rideId) {
    Get.snackbar(
      'Ride Completed',
      'Ride ${rideId.substring(0, 8)}... has been completed',
      duration: const Duration(seconds: 3),
      backgroundColor: Colors.blue.shade100,
      colorText: Colors.blue.shade800,
    );
  }

  // ==================== Ride Chat ====================

  /// Join ride chat group
  Future<void> joinRideChat(String rideId) async {
    if (_hubConnection != null && rideId.isNotEmpty) {
      try {
        await _hubConnection!.invoke('JoinRideChat', args: [rideId]);
        print('💬 SAHAr Joined ride chat for: $rideId');
      } catch (e) {
        print('❌ SAHAr Failed to join ride chat: $e');
      }
    }
  }

  /// Load ride chat history
  Future<void> loadRideChatHistory(String rideId) async {
    if (rideId.isEmpty || _hubConnection == null || !isConnected.value) {
      print('⚠️ SAHAr Cannot load ride chat history');
      return;
    }

    try {
      isRideChatLoading.value = true;
      await _hubConnection!.invoke('GetRideChatHistory', args: [rideId]);
      print('📜 SAHAr Ride chat history request sent');
    } catch (e) {
      print('❌ SAHAr Failed to load ride chat history: $e');
      isRideChatLoading.value = false;
    }
  }

  /// Send ride chat message
  Future<void> sendRideChatMessage({
    required String rideId,
    required String senderId,
    required String message,
    required String senderRole,
  }) async {
    if (_hubConnection == null || !isConnected.value) {
      Get.snackbar('Error', 'Not connected to chat service');
      return;
    }

    try {
      isRideChatSending.value = true;

      // Add message optimistically
      final now = DateTime.now();
      final newMessage = ChatMessage(
        senderId: senderId,
        senderRole: senderRole,
        message: message,
        dateTime: now,
        isFromCurrentUser: true,
      );

      rideChatMessages.add(newMessage);
      rideChatMessages.refresh(); // Force UI update
      print('📤 SAHAr Optimistically added message to UI. Total: ${rideChatMessages.length}');

      // Track message to avoid duplicates
      _recentlySentMessages[message] = now;
      Future.delayed(const Duration(seconds: 5), () {
        _recentlySentMessages.remove(message);
      });

      // Send via SignalR
      await _hubConnection!.invoke('SendMessage', args: [
        rideId,
        senderId,
        message,
        senderRole,
      ]);

      print('💬 SAHAr Ride chat message sent successfully');
    } catch (e) {
      print('❌ SAHAr Failed to send ride chat message: $e');

      // Remove optimistically added message on error
      if (rideChatMessages.isNotEmpty && rideChatMessages.last.message == message) {
        rideChatMessages.removeLast();
      }

      Get.snackbar('Send Error', 'Failed to send message');
    } finally {
      isRideChatSending.value = false;
    }
  }

  void _handleRideChatMessage(Map<String, dynamic> messageData) {
    try {
      print('📨 SAHAr _handleRideChatMessage called with data: $messageData');

      final chatMessage = ChatMessage.fromJson(messageData);
      final userId = _driverId ?? '';
      final isFromCurrentUser = chatMessage.senderId == userId;

      print('📨 SAHAr Parsed message - Sender: ${chatMessage.senderId}, Message: ${chatMessage.message}');
      print('📨 SAHAr Current user ID: $userId, isFromCurrentUser: $isFromCurrentUser');

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

      final messageWithUserFlag = chatMessage.copyWith(
        isFromCurrentUser: isFromCurrentUser,
      );

      rideChatMessages.add(messageWithUserFlag);
      rideChatMessages.refresh(); // Force UI update
      print('✅ SAHAr Message added to rideChatMessages. Total messages: ${rideChatMessages.length}');
      print('💬 SAHAr Received ride chat message: ${chatMessage.message}');

      // Show notification if message is from passenger (not current user)
      if (!isFromCurrentUser) {
        try {
          if (Get.isRegistered<ChatNotificationService>()) {
            final notificationService = Get.find<ChatNotificationService>();
            notificationService.showChatMessageNotification(
              senderName: chatMessage.senderRole == 'Passenger' ? 'Passenger' : chatMessage.senderId,
              message: chatMessage.message,
              rideId: currentRideId.value,
            );
          }
        } catch (e) {
          print('⚠️ SAHAr Could not show notification: $e');
        }
      }
    } catch (e) {
      print('❌ SAHAr Error handling ride chat message: $e');
      print('❌ SAHAr Stack trace: ${StackTrace.current}');
    }
  }

  void _handleRideChatHistory(List<dynamic> chatHistory) {
    try {
      print('📜 SAHAr Processing ride chat history: ${chatHistory.length} messages');
      print('📜 SAHAr Current driver ID: $_driverId');

      if (chatHistory.isEmpty) {
        print('📜 SAHAr Chat history is empty, clearing messages');
        rideChatMessages.clear();
        isRideChatLoading.value = false;
        return;
      }

      List<ChatMessage> loadedMessages = [];
      final userId = _driverId ?? '';

      for (var messageData in chatHistory) {
        try {
          print('📜 SAHAr Processing message data: $messageData');
          final chatMessage = ChatMessage.fromJson(messageData);
          final isFromCurrentUser = chatMessage.senderId == userId;
          loadedMessages.add(chatMessage.copyWith(isFromCurrentUser: isFromCurrentUser));
          print('📜 SAHAr Added message: ${chatMessage.message} (from current user: $isFromCurrentUser)');
        } catch (e) {
          print('❌ SAHAr Error processing ride chat message: $e');
          print('❌ SAHAr Problematic message data: $messageData');
        }
      }

      rideChatMessages.assignAll(loadedMessages);
      print('✅ SAHAr Loaded ${loadedMessages.length} ride chat messages');
      print('✅ SAHAr rideChatMessages.length after assignAll: ${rideChatMessages.length}');
    } catch (e) {
      print('❌ SAHAr Error handling ride chat history: $e');
      print('❌ SAHAr Stack trace: ${StackTrace.current}');
    } finally {
      isRideChatLoading.value = false;
    }
  }

  /// Clear ride chat messages
  void clearRideChatMessages() {
    rideChatMessages.clear();
  }

  // ==================== Driver-Admin Chat ====================

  /// Join driver support group
  Future<void> joinDriverSupport() async {
    if (_driverId == null || _driverId!.isEmpty) {
      print('⚠️ SAHAr Cannot join driver support: driver ID not set');
      return;
    }

    try {
      await _hubConnection?.invoke('JoinDriverSupport', args: [_driverId]);
      print('🎧 SAHAr Joined driver support group for: $_driverId');
    } catch (e) {
      print('❌ SAHAr Failed to join driver support: $e');
    }
  }

  /// Load driver-admin chat history
  Future<void> loadDriverAdminChatHistory() async {
    if (_driverId == null || _driverId!.isEmpty) {
      print('⚠️ SAHAr Cannot load admin chat history: driver ID not set');
      return;
    }

    try {
      isAdminChatLoading.value = true;
      await _hubConnection?.invoke('GetDriverAdminChatHistory', args: [_driverId]);
      print('📜 SAHAr Admin chat history request sent');
    } catch (e) {
      print('❌ SAHAr Failed to load admin chat history: $e');
      isAdminChatLoading.value = false;
    }
  }

  /// Send driver-admin chat message
  Future<void> sendDriverAdminMessage(String message) async {
    if (!isConnected.value || _hubConnection == null) {
      Get.snackbar('Not Connected', 'Please wait for connection');
      return;
    }

    if (_driverId == null || _driverId!.isEmpty) {
      print('⚠️ SAHAr Cannot send admin message: driver ID not set');
      return;
    }

    try {
      isAdminChatSending.value = true;

      await _hubConnection!.invoke(
        'SendDriverAdminMessage',
        args: [_driverId, _driverId, 'Driver', message],
      );

      print('💬 SAHAr Admin message sent: $message');
      await loadDriverAdminChatHistory();
    } catch (e) {
      print('❌ SAHAr Failed to send admin message: $e');
      Get.snackbar('Send Failed', 'Could not send message');
    } finally {
      isAdminChatSending.value = false;
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

  /// Clear admin chat messages
  void clearAdminChatMessages() {
    adminChatMessages.clear();
  }

  // ==================== Utility Methods ====================

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
      'hubUrl': _hubUrl,
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
    _stopLocationUpdates();
    disconnect();
    super.onClose();
  }
}

