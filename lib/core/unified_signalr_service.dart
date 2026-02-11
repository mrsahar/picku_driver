import 'dart:async';

import 'package:get/get.dart';
import 'package:pick_u_driver/core/driver_service.dart';
import 'package:pick_u_driver/core/location_service.dart';
import 'package:pick_u_driver/core/global_variables.dart';
import 'package:pick_u_driver/core/chat_notification_service.dart';
import 'package:pick_u_driver/core/notification_sound_service.dart';
import 'package:pick_u_driver/core/background_tracking_service.dart';
import 'package:pick_u_driver/core/internet_connectivity_service.dart';
import 'package:pick_u_driver/core/database_helper.dart';
import 'package:signalr_core/signalr_core.dart';
import 'package:geolocator/geolocator.dart'; // Remove usage, keep type if needed or use LocationService types
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
  // Use getters via DriverService if possible, or local cache updated from it.

  // Timers and streams
  StreamSubscription<Position?>? _locationServiceSubscription;
  StreamSubscription<bool>? _connectivitySubscription;

  // Configuration
  static const String _hubUrl = 'https://api.pickurides.com/ridechathub/';
  static const String _emptyGuid = '00000000-0000-0000-0000-000000000000';
  static const double _minimumDistanceFilter = 10.0; // meters

  // Track recently sent messages to avoid duplicates
  final Map<String, DateTime> _recentlySentMessages = {};
  
  // Track last connectivity state to detect changes
  bool _wasConnectedToInternet = true;

  @override
  void onInit() {
    super.onInit();
    // Driver info is managed by DriverService, but we might want to ensure it's loaded?
    // DriverService.to.onInit() is called automatically.
    _initializeConnection();
    _setupConnectivityListener();
    // We can listen to DriverService changes if needed, but usually it's static during session.
  }

  /// Setup listener for internet connectivity changes
  void _setupConnectivityListener() {
    try {
      if (!Get.isRegistered<InternetConnectivityService>()) {
        print('⚠️ SAHAr InternetConnectivityService not registered yet');
        return;
      }

      final connectivityService = InternetConnectivityService.to;
      
      // Listen to connectivity changes
      _connectivitySubscription = connectivityService.isConnected.listen((isConnected) {
        print('🌐 SAHAr Internet connectivity changed: $isConnected');
        _handleConnectivityChange(isConnected);
      });

      print('✅ SAHAr Connectivity listener setup complete');
    } catch (e) {
      print('❌ SAHAr Error setting up connectivity listener: $e');
    }
  }

  /// Handle internet connectivity changes
  void _handleConnectivityChange(bool isConnectedToInternet) {
    // Internet connection restored
    if (isConnectedToInternet && !_wasConnectedToInternet) {
      print('🟢 SAHAr Internet restored, attempting SignalR reconnection...');
      _attemptReconnection();
    } 
    // Internet connection lost
    else if (!isConnectedToInternet && _wasConnectedToInternet) {
      print('🔴 SAHAr Internet lost, SignalR will attempt automatic reconnection');
      // SignalR has automatic reconnect, but we pause location updates
      if (isLocationSending.value) {
        _pauseLocationUpdates();
      }
    }

    _wasConnectedToInternet = isConnectedToInternet;
  }

  /// Attempt to reconnect SignalR after internet restoration
  Future<void> _attemptReconnection() async {
    try {
      // If already connected, no need to reconnect
      if (isConnected.value) {
        print('✅ SAHAr SignalR already connected');
        // Resume location updates if needed
        if (isLocationSending.value) {
          _resumeLocationUpdates();
        }
        return;
      }

      // Try to connect
      print('🔄 SAHAr Attempting SignalR reconnection...');
      bool success = await connect();

      if (success) {
        print('✅ SAHAr SignalR reconnected successfully');
        
        // Resume location updates if they were active
        if (isLocationSending.value) {
          _resumeLocationUpdates();
        }
      } else {
        print('❌ SAHAr SignalR reconnection failed, will retry...');
        // Schedule retry after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (!isConnected.value && _wasConnectedToInternet) {
            _attemptReconnection();
          }
        });
      }
    } catch (e) {
      print('❌ SAHAr Error during reconnection attempt: $e');
    }
  }

  /// Get driver info from DriverService
  String? get _driverId => DriverService.to.driverId.value;
  String? get _driverName => DriverService.to.driverName.value;

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

       // Rejoin active ride chat group after reconnection so messages & history resume.
       try {
         if (currentRideId.value.isNotEmpty) {
           print('💬 SAHAr Rejoining ride chat after reconnection for rideId: ${currentRideId.value}');
           joinRideChat(currentRideId.value);
           loadRideChatHistory(currentRideId.value);
         }
       } catch (e) {
         print('⚠️ SAHAr Error rejoining ride chat after reconnection: $e');
       }
    });

    // ==================== Location Tracking Events ====================
    _hubConnection!.on('RideAssigned', (List<Object?>? arguments) {
      print('📥 SAHAr [SignalR] RideAssigned event received');
      print('📥 SAHAr [SignalR] Raw arguments: $arguments');
      if (arguments != null && arguments.isNotEmpty) {
        String newRideId = arguments[0].toString();
        print('🚕 SAHAr Ride assigned: $newRideId');
        print('📥 SAHAr [SignalR] Parsed rideId: $newRideId');
        currentRideId.value = newRideId;
        _playNotificationSound();
        _onRideAssigned(newRideId);
      } else {
        print('⚠️ SAHAr [SignalR] RideAssigned: arguments is null or empty');
      }
    });

    _hubConnection!.on('RideCompleted', (List<Object?>? arguments) {
      print('📥 SAHAr [SignalR] RideCompleted event received');
      print('📥 SAHAr [SignalR] Raw arguments: $arguments');
      if (arguments != null && arguments.isNotEmpty) {
        String completedRideId = arguments[0].toString();
        print('✅ SAHAr Ride completed: $completedRideId');
        print('📥 SAHAr [SignalR] Parsed rideId: $completedRideId');
        print('📥 SAHAr [SignalR] Current rideId: ${currentRideId.value}');

        if (currentRideId.value == completedRideId) {
          currentRideId.value = '';
          _onRideCompleted(completedRideId);
        } else {
          print('⚠️ SAHAr [SignalR] RideCompleted: rideId mismatch (current: ${currentRideId.value}, received: $completedRideId)');
        }
      } else {
        print('⚠️ SAHAr [SignalR] RideCompleted: arguments is null or empty');
      }
    });

    _hubConnection!.on('LocationReceived', (List<Object?>? arguments) {
      print('📥 SAHAr [SignalR] LocationReceived event received');
      print('📥 SAHAr [SignalR] Raw arguments: $arguments');
      print('📍 SAHAr Location update acknowledged by server');
      // Note: Not playing sound for location acknowledgments as they're too frequent
    });

    _hubConnection!.on('DriverStatusChanged', (List<Object?>? arguments) {
      print('📥 SAHAr [SignalR] DriverStatusChanged event received');
      print('📥 SAHAr [SignalR] Raw arguments: $arguments');
      if (arguments != null && arguments.length >= 2) {
        String driverId = arguments[0].toString();
        bool isOnline = arguments[1] as bool;
        print('📥 SAHAr [SignalR] Parsed driverId: $driverId, isOnline: $isOnline');
        print('📥 SAHAr [SignalR] Current driverId: $_driverId');

        if (driverId == _driverId) {
          print('👤 SAHAr Driver status changed from server: $isOnline');
          _playNotificationSound();
        } else {
          print('⚠️ SAHAr [SignalR] DriverStatusChanged: driverId mismatch (current: $_driverId, received: $driverId)');
        }
      } else {
        print('⚠️ SAHAr [SignalR] DriverStatusChanged: arguments is null or insufficient (length: ${arguments?.length ?? 0})');
      }
    });

    _hubConnection!.on('RideStatusUpdate', (List<Object?>? arguments) {
       print('📥 SAHAr [SignalR] RideStatusUpdate event received');
       if (arguments != null && arguments.isNotEmpty) {
         try {
           final statusUpdate = arguments[0] as Map<String, dynamic>;
           // Update reactive variables
           // Assuming statusUpdate has 'status' and 'rideId'
           if (statusUpdate.containsKey('status')) {
             rideStatus.value = statusUpdate['status'];
           }
           // TODO: Update currentRide object if needed
           print('✅ SAHAr Status updated: ${rideStatus.value}');
         } catch (e) {
           print('❌ SAHAr Error parsing RideStatusUpdate: $e');
         }
       }
    });

    // ==================== Ride Chat Events ====================
    _hubConnection!.on('ReceiveMessage', (List<Object?>? arguments) {
      print('📥 SAHAr [SignalR] ReceiveMessage event received');
      print('📥 SAHAr [SignalR] Raw arguments: $arguments');
      if (arguments != null && arguments.isNotEmpty) {
        print('📥 SAHAr [SignalR] Arguments count: ${arguments.length}');
        print('📥 SAHAr [SignalR] First argument type: ${arguments[0].runtimeType}');
        print('📥 SAHAr [SignalR] First argument value: ${arguments[0]}');
        try {
          final messageData = arguments[0] as Map<String, dynamic>;
          print('📥 SAHAr [SignalR] Parsed messageData: $messageData');
          print('📥 SAHAr [SignalR] MessageData keys: ${messageData.keys.toList()}');
          _handleRideChatMessage(messageData);
        } catch (e) {
          print('❌ SAHAr [SignalR] Error parsing ReceiveMessage: $e');
          print('❌ SAHAr [SignalR] Stack trace: ${StackTrace.current}');
        }
      } else {
        print('⚠️ SAHAr [SignalR] ReceiveMessage: arguments is null or empty');
      }
    });

    _hubConnection!.on('ReceiveRideChatHistory', (List<Object?>? arguments) {
      print('📥 SAHAr [SignalR] ReceiveRideChatHistory event received');
      print('📥 SAHAr [SignalR] Raw arguments: $arguments');
      print('📜 SAHAr ReceiveRideChatHistory event triggered');
      if (arguments != null && arguments.isNotEmpty) {
        print('📥 SAHAr [SignalR] Arguments count: ${arguments.length}');
        print('📥 SAHAr [SignalR] First argument type: ${arguments[0].runtimeType}');
        try {
          final historyData = arguments[0] as List<dynamic>;
          print('📜 SAHAr Chat history data received: ${historyData.length} messages');
          print('📥 SAHAr [SignalR] History data sample (first item): ${historyData.isNotEmpty ? historyData[0] : "empty"}');
          // Note: Not playing sound for chat history as it's a bulk load, not a new message
          _handleRideChatHistory(historyData);
        } catch (e) {
          print('❌ SAHAr [SignalR] Error parsing ReceiveRideChatHistory: $e');
          print('❌ SAHAr [SignalR] Stack trace: ${StackTrace.current}');
        }
      } else {
        print('⚠️ SAHAr [SignalR] ReceiveRideChatHistory: arguments is null or empty');
      }
    });

    // ==================== Driver-Admin Chat Events ====================
    _hubConnection!.on('ReceiveDriverAdminMessage', (List<Object?>? arguments) {
      print('📥 SAHAr [SignalR] ReceiveDriverAdminMessage event received');
      print('📥 SAHAr [SignalR] Raw arguments: $arguments');
      if (arguments != null && arguments.isNotEmpty) {
        print('📥 SAHAr [SignalR] Arguments count: ${arguments.length}');
        print('📥 SAHAr [SignalR] First argument type: ${arguments[0].runtimeType}');
        print('📥 SAHAr [SignalR] First argument value: ${arguments[0]}');
        try {
          final messageData = arguments[0] as Map<String, dynamic>;
          print('📥 SAHAr [SignalR] Parsed messageData: $messageData');
          print('📥 SAHAr [SignalR] MessageData keys: ${messageData.keys.toList()}');
          _handleAdminChatMessage(messageData);
        } catch (e) {
          print('❌ SAHAr [SignalR] Error parsing ReceiveDriverAdminMessage: $e');
          print('❌ SAHAr [SignalR] Stack trace: ${StackTrace.current}');
        }
      } else {
        print('⚠️ SAHAr [SignalR] ReceiveDriverAdminMessage: arguments is null or empty');
      }
    });

    _hubConnection!.on('ReceiveDriverAdminChatHistory', (List<Object?>? arguments) {
      print('📥 SAHAr [SignalR] ReceiveDriverAdminChatHistory event received');
      print('📥 SAHAr [SignalR] Raw arguments: $arguments');
      if (arguments != null && arguments.isNotEmpty) {
        print('📥 SAHAr [SignalR] Arguments count: ${arguments.length}');
        print('📥 SAHAr [SignalR] First argument type: ${arguments[0].runtimeType}');
        try {
          final historyList = arguments[0] as List<dynamic>;
          print('📥 SAHAr [SignalR] History list length: ${historyList.length}');
          print('📥 SAHAr [SignalR] History data sample (first item): ${historyList.isNotEmpty ? historyList[0] : "empty"}');
          // Note: Not playing sound for chat history as it's a bulk load, not a new message
          _handleAdminChatHistory(historyList);
        } catch (e) {
          print('❌ SAHAr [SignalR] Error parsing ReceiveDriverAdminChatHistory: $e');
          print('❌ SAHAr [SignalR] Stack trace: ${StackTrace.current}');
        }
      } else {
        print('⚠️ SAHAr [SignalR] ReceiveDriverAdminChatHistory: arguments is null or empty');
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
      // print('⚠️ SAHAr Cannot send location: not connected'); // Optional logging
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
  void startLocationUpdates() {
    if (isLocationSending.value) {
      print('⚠️ SAHAr Location updates already running');
      return;
    }

    // Check if we have driver info
    if (_driverId == null) {
        print('❌ SAHAr Cannot start location updates: driver info not available');
        return;
    }

    isLocationSending.value = true;
    locationUpdateCount.value = 0;
    print('🚀 SAHAr Starting signalr location updates listening to LocationService');

    _locationServiceSubscription?.cancel();
    _locationServiceSubscription = LocationService.to.currentPosition.listen((Position? position) async {
         if (position != null && isLocationSending.value) {
             // Throttling or logic to decide when to send
             if (_shouldSendLocationUpdate(position)) {
                 bool success = await sendLocationUpdate(position.latitude, position.longitude);
                  if (success) {
                    lastSentLocation.value = position;
                  } else if (!isConnected.value) {
                    await connect();
                  }
             }
         }
    });
  }

  void stopLocationUpdates() {
    _locationServiceSubscription?.cancel();
    _locationServiceSubscription = null;
    isLocationSending.value = false;
    print('🛑 SAHAr SignalR location updates stopped');
  }

  // Internal helpers
  void _stopLocationUpdates() {
      stopLocationUpdates();
  }

  void _pauseLocationUpdates() {
      _locationServiceSubscription?.pause();
      print('⏸️ SAHAr SignalR Location updates paused');
  }

  void _resumeLocationUpdates() {
      _locationServiceSubscription?.resume();
      print('▶️ SAHAr SignalR Location updates resumed');
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
    // UI update removed (Snackbar)
  }

  void _onRideCompleted(String rideId) {
    // UI update removed (Snackbar)
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

          // Determine alignment using the same rule as SignalR history.
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
    if (_hubConnection == null || !isConnected.value) {
      print('❌ SAHAr Error: Not connected to chat service');
      return;
    }

    // Automatically set senderRole to "Driver" since this is the driver app
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
      rideChatMessages.refresh(); // Force UI update
      print('📤 SAHAr Optimistically added message to UI. Total: ${rideChatMessages.length}');
      print('📤 SAHAr Sending message with role: $role');

      // Persist optimistically added message locally so history survives restarts.
      _saveRideChatMessageToLocal(
        rideId: rideId,
        message: newMessage,
      );

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
        role,
      ]);

      print('💬 SAHAr Ride chat message sent successfully with role: $role');
    } catch (e) {
      print('❌ SAHAr Failed to send ride chat message: $e');

      // Remove optimistically added message on error
      if (rideChatMessages.isNotEmpty && rideChatMessages.last.message == message) {
        rideChatMessages.removeLast();
      }
    } finally {
      isRideChatSending.value = false;
    }
  }

  void _handleRideChatMessage(Map<String, dynamic> messageData) {
    try {
      print('📨 SAHAr _handleRideChatMessage called with data: $messageData');
      print('📨 SAHAr [SignalR] MessageData keys: ${messageData.keys.toList()}');
      print('📨 SAHAr [SignalR] MessageData values: ${messageData.values.toList()}');
      print('📨 SAHAr [SignalR] senderId: ${messageData['senderId']}');
      print('📨 SAHAr [SignalR] senderRole: ${messageData['senderRole']}');
      print('📨 SAHAr [SignalR] message: ${messageData['message']}');
      print('📨 SAHAr [SignalR] dateTime: ${messageData['dateTime']}');
      print('📨 SAHAr [SignalR] timestamp: ${messageData['timestamp']}');

      final chatMessage = ChatMessage.fromJson(messageData);
      final userId = _driverId ?? '';
      
      // Determine if message is from current user (driver) based on senderRole
      // Driver messages should show on right, Passenger messages on left
      final isFromCurrentUser = chatMessage.senderRole.toLowerCase() == 'driver' || 
                                chatMessage.senderId == userId;

      print('📨 SAHAr Parsed message - Sender: ${chatMessage.senderId}, Message: ${chatMessage.message}');
      print('📨 SAHAr [SignalR] Parsed senderRole: ${chatMessage.senderRole}');
      print('📨 SAHAr [SignalR] Parsed dateTime: ${chatMessage.dateTime}');
      print('📨 SAHAr Current user ID: $userId, isFromCurrentUser: $isFromCurrentUser');
      print('📨 SAHAr [SignalR] Message alignment: ${isFromCurrentUser ? "RIGHT (Driver)" : "LEFT (Passenger)"}');

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

      // Persist received message locally using current rideId (used for notifications as well).
      _saveRideChatMessageToLocal(
        rideId: currentRideId.value.isEmpty ? _emptyGuid : currentRideId.value,
        message: messageWithUserFlag,
      );

      // Show notification if message is from passenger (not current user)
      if (!isFromCurrentUser) {
        try {
          if (Get.isRegistered<ChatNotificationService>()) {
            final notificationService = Get.find<ChatNotificationService>();
            
            // Get passenger name from BackgroundTrackingService if available
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
            } else if (chatMessage.senderRole.toLowerCase() == 'driver') {
              // If message is from driver, use driver name
              senderName = _driverName ?? 'Driver';
            } else {
              // For other senders, use senderId as fallback
              senderName = chatMessage.senderId;
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
    } catch (e) {
      print('❌ SAHAr Error handling ride chat message: $e');
      print('❌ SAHAr Stack trace: ${StackTrace.current}');
    }
  }

  void _handleRideChatHistory(List<dynamic> chatHistory) {
    try {
      print('📜 SAHAr Processing ride chat history: ${chatHistory.length} messages');
      print('📜 SAHAr [SignalR] Chat history list type: ${chatHistory.runtimeType}');
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
          print('📜 SAHAr [SignalR] Message data type: ${messageData.runtimeType}');
          if (messageData is Map) {
            print('📜 SAHAr [SignalR] Message data keys: ${messageData.keys.toList()}');
            print('📜 SAHAr [SignalR] senderId: ${messageData['senderId']}');
            print('📜 SAHAr [SignalR] senderRole: ${messageData['senderRole']}');
            print('📜 SAHAr [SignalR] message: ${messageData['message']}');
            print('📜 SAHAr [SignalR] dateTime: ${messageData['dateTime']}');
            print('📜 SAHAr [SignalR] timestamp: ${messageData['timestamp']}');
          }
          final chatMessage = ChatMessage.fromJson(messageData as Map<String, dynamic>);
          // Determine if message is from current user (driver) based on senderRole
          // Driver messages should show on right, Passenger messages on left
          final isFromCurrentUser = chatMessage.senderRole.toLowerCase() == 'driver' || 
                                    chatMessage.senderId == userId;
          loadedMessages.add(chatMessage.copyWith(isFromCurrentUser: isFromCurrentUser));
          print('📜 SAHAr Added message: ${chatMessage.message} (from current user: $isFromCurrentUser)');
          print('📜 SAHAr [SignalR] Parsed senderRole: ${chatMessage.senderRole}');
          print('📜 SAHAr [SignalR] Message alignment: ${isFromCurrentUser ? "RIGHT (Driver)" : "LEFT (Passenger)"}');
        } catch (e) {
          print('❌ SAHAr Error processing ride chat message: $e');
          print('❌ SAHAr Problematic message data: $messageData');
          print('❌ SAHAr [SignalR] Stack trace: ${StackTrace.current}');
        }
      }

      rideChatMessages.assignAll(loadedMessages);
      print('✅ SAHAr Loaded ${loadedMessages.length} ride chat messages');
      print('✅ SAHAr rideChatMessages.length after assignAll: ${rideChatMessages.length}');

      // Persist full history locally for offline access.
      _saveRideChatHistoryToLocal(
        rideId: currentRideId.value.isEmpty ? _emptyGuid : currentRideId.value,
        messages: loadedMessages,
      );
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

  // ==================== Ride Chat Local Persistence ====================

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
        // Replace existing history for this ride to avoid unbounded growth.
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
       print('❌ SAHAr Not Connected, please wait');
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
    } finally {
      isAdminChatSending.value = false;
    }
  }

  void _handleAdminChatMessage(Map<String, dynamic> messageData) {
    try {
      print('📨 SAHAr [SignalR] _handleAdminChatMessage called with data: $messageData');
      print('📨 SAHAr [SignalR] MessageData keys: ${messageData.keys.toList()}');
      print('📨 SAHAr [SignalR] MessageData values: ${messageData.values.toList()}');
      final newMessage = ChatMessageModel.ChatMessage.fromJson(messageData);
      adminChatMessages.add(newMessage);
      print('💬 SAHAr Received admin message: ${newMessage.message}');
      print('📨 SAHAr [SignalR] Parsed admin message - Sender: ${newMessage.senderId}, Role: ${newMessage.senderRole}, Message: ${newMessage.message}');
    } catch (e) {
      print('❌ SAHAr Error handling admin message: $e');
      print('❌ SAHAr [SignalR] Stack trace: ${StackTrace.current}');
    }
  }

  void _handleAdminChatHistory(List<dynamic> historyList) {
    try {
      print('📨 SAHAr [SignalR] _handleAdminChatHistory called with ${historyList.length} items');
      adminChatMessages.clear();

      for (var item in historyList) {
        print('📨 SAHAr [SignalR] Processing admin history item: $item');
        final message = ChatMessageModel.ChatMessage.fromJson(item as Map<String, dynamic>);
        adminChatMessages.add(message);
        print('📨 SAHAr [SignalR] Added admin message - Sender: ${message.senderId}, Role: ${message.senderRole}, Message: ${message.message}');
      }

      print('✅ SAHAr Loaded ${adminChatMessages.length} admin messages');
    } catch (e) {
      print('❌ SAHAr Error handling admin chat history: $e');
      print('❌ SAHAr [SignalR] Stack trace: ${StackTrace.current}');
    } finally {
      isAdminChatLoading.value = false;
    }
  }

  /// Clear admin chat messages
  void clearAdminChatMessages() {
    adminChatMessages.clear();
  }

  // ==================== Utility Methods ====================

  /// Play notification sound when SignalR message is received
  void _playNotificationSound() {
    try {
      if (Get.isRegistered<NotificationSoundService>()) {
        NotificationSoundService.to.playNotificationSound();
      }
    } catch (e) {
      print('⚠️ SAHAr Could not play notification sound: $e');
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
    _connectivitySubscription?.cancel();
    disconnect();
    super.onClose();
  }
}






