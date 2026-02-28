import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pick_u_driver/core/sharePref.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signalr_core/signalr_core.dart';

// ============================================================
// Background Service Initializer
// ============================================================
// This file contains the background isolate logic for:
//   1. SignalR connection (with JWT auth)
//   2. Location tracking (10m distance stream + 60s timer fallback)
//   3. Forwarding SignalR events to the UI via service.invoke()
//
// IMPORTANT: This code runs in a SEPARATE ISOLATE.
//   - No GetX (Get.find, Get.put, etc.)
//   - No access to main isolate memory
//   - Must read SharedPreferences directly
// ============================================================

/// Hub URL (must match the one in UnifiedSignalRService / BackgroundTrackingService)
const String _hubUrl = 'https://api.pickurides.com/ridechathub/';
const String _emptyGuid = '00000000-0000-0000-0000-000000000000';
const double _minimumDistanceMeters = 10.0;
const int _timerFallbackSeconds = 60;

/// Call this from main() BEFORE runApp()
Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false, // We start manually after login
      isForegroundMode: true,
      autoStartOnBoot: false,
      notificationChannelId: 'pickurides_bg_service_channel',
      initialNotificationTitle: 'Pick U Driver',
      initialNotificationContent: 'App is running in background',
      foregroundServiceNotificationId: 8888,
      foregroundServiceTypes: [AndroidForegroundType.location],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );

  print('✅ SAHAr Background service configured');
}

/// iOS background handler
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

/// ============================================================
/// TOP-LEVEL onStart — runs in background isolate
/// ============================================================
@pragma('vm:entry-point')
Future<void> onStart(ServiceInstance service) async {
  // Ensure Flutter binding is available in isolate
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  print('🚀 SAHAr [BG-ISO] Background isolate started');

  // ── Read credentials from SharedPreferences ──
  final prefs = await SharedPreferences.getInstance();

  // Use SharedPrefsService to get the JWT token
  String? jwtToken = await SharedPrefsService.getUserToken();
  // Try DriverService keys first, then SharedPrefsService keys as fallback
  String? driverId = prefs.getString('driver_id') ?? prefs.getString('user_id');
  String? driverName = prefs.getString('driver_name') ?? prefs.getString('user_full_name');

  print('🔐 SAHAr [BG-ISO] Token: ${jwtToken != null && jwtToken.isNotEmpty ? "${jwtToken.substring(0, 20)}..." : "MISSING"}');
  print('🔐 SAHAr [BG-ISO] DriverId: $driverId, DriverName: $driverName');

  if (jwtToken == null || jwtToken.isEmpty) {
    print('❌ SAHAr [BG-ISO] No JWT token, stopping service');
    service.invoke('bg_error', {'message': 'No JWT token available'});
    service.stopSelf();
    return;
  }

  if (driverId == null || driverId.isEmpty) {
    print('❌ SAHAr [BG-ISO] No driver ID, stopping service');
    service.invoke('bg_error', {'message': 'No driver ID available'});
    service.stopSelf();
    return;
  }

  // ── Track current ride ID (updated from UI or from events) ──
  String currentRideId = '';

  // ── Track last location send time (for timer fallback) ──
  DateTime lastSendTime = DateTime.now();

  // ── Build SignalR HubConnection ──
  HubConnection? hubConnection;
  try {
    hubConnection = HubConnectionBuilder()
        .withUrl(
      _hubUrl,
      HttpConnectionOptions(
        accessTokenFactory: () async => jwtToken,
      ),
    )
        .withAutomaticReconnect([2000, 5000, 10000, 15000, 30000])
        .build();

    print('✅ SAHAr [BG-ISO] HubConnection built');
  } catch (e) {
    print('❌ SAHAr [BG-ISO] Error building HubConnection: $e');
    service.invoke('bg_error', {'message': 'Failed to build SignalR connection: $e'});
    service.stopSelf();
    return;
  }

  // ── Connection state handlers ──
  hubConnection.onclose((error) {
    print('🔴 SAHAr [BG-ISO] SignalR closed: $error');
    service.invoke('bg_connectionState', {'state': 'disconnected', 'error': error?.toString()});
  });

  hubConnection.onreconnecting((error) {
    print('🟡 SAHAr [BG-ISO] SignalR reconnecting: $error');
    service.invoke('bg_connectionState', {'state': 'reconnecting', 'error': error?.toString()});
  });

  hubConnection.onreconnected((connectionId) {
    print('🟢 SAHAr [BG-ISO] SignalR reconnected: $connectionId');
    service.invoke('bg_connectionState', {'state': 'connected', 'connectionId': connectionId});

    // Re-subscribe after reconnection
    if (hubConnection != null) {
      _subscribeDriver(hubConnection, driverId);
    }

    // Rejoin ride chat if active
    if (currentRideId.isNotEmpty && hubConnection != null) {
      _joinRideChat(hubConnection, currentRideId);
    }
  });

  // ── Register ALL SignalR event listeners ──

  // --- Ride Assignment ---
  hubConnection.on('RideAssigned', (List<Object?>? args) {
    print('🚨 SAHAr [BG-ISO] RideAssigned: $args');
    if (args != null && args.isNotEmpty) {
      String rideId = args[0].toString();
      currentRideId = rideId;
      service.invoke('bg_RideAssigned', {'rideId': rideId});
    }
  });

  hubConnection.on('NewRideAssigned', (List<Object?>? args) {
    print('🚨 SAHAr [BG-ISO] NewRideAssigned: $args');
    if (args != null && args.isNotEmpty) {
      try {
        final data = args[0];
        if (data is Map<String, dynamic>) {
          if (data['rideId'] != null) {
            currentRideId = data['rideId'].toString();
          }
          service.invoke('bg_NewRideAssigned', data);
        } else {
          service.invoke('bg_NewRideAssigned', {'raw': data.toString()});
        }
      } catch (e) {
        print('❌ SAHAr [BG-ISO] Error parsing NewRideAssigned: $e');
      }
    }
  });

  hubConnection.on('RideCompleted', (List<Object?>? args) {
    print('🚨 SAHAr [BG-ISO] RideCompleted: $args');
    if (args != null && args.isNotEmpty) {
      String completedRideId = args[0].toString();
      if (currentRideId == completedRideId) {
        currentRideId = '';
      }
      service.invoke('bg_RideCompleted', {'rideId': completedRideId});
    }
  });

  hubConnection.on('RideStatusUpdate', (List<Object?>? args) {
    print('🚨 SAHAr [BG-ISO] RideStatusUpdate: $args');
    if (args != null && args.isNotEmpty) {
      try {
        final data = args[0];
        if (data is Map<String, dynamic>) {
          service.invoke('bg_RideStatusUpdate', data);
        } else {
          service.invoke('bg_RideStatusUpdate', {'raw': data.toString()});
        }
      } catch (e) {
        print('❌ SAHAr [BG-ISO] Error parsing RideStatusUpdate: $e');
      }
    }
  });

  hubConnection.on('DriverStatusChanged', (List<Object?>? args) {
    print('🚨 SAHAr [BG-ISO] DriverStatusChanged: $args');
    if (args != null && args.length >= 2) {
      service.invoke('bg_DriverStatusChanged', {
        'driverId': args[0].toString(),
        'isOnline': args[1],
      });
    }
  });

  hubConnection.on('LocationReceived', (List<Object?>? args) {
    print('📍 SAHAr [BG-ISO] LocationReceived (ack)');
    service.invoke('bg_LocationReceived', {'ack': true});
  });

  // --- Ride Chat ---
  hubConnection.on('ReceiveMessage', (List<Object?>? args) {
    print('💬 SAHAr [BG-ISO] ReceiveMessage: $args');
    if (args != null && args.isNotEmpty) {
      try {
        final data = args[0];
        if (data is Map<String, dynamic>) {
          service.invoke('bg_ReceiveMessage', data);
        } else {
          service.invoke('bg_ReceiveMessage', {'raw': data.toString()});
        }
      } catch (e) {
        print('❌ SAHAr [BG-ISO] Error parsing ReceiveMessage: $e');
      }
    }
  });

  hubConnection.on('ReceiveRideChatHistory', (List<Object?>? args) {
    print('📜 SAHAr [BG-ISO] ReceiveRideChatHistory');
    if (args != null && args.isNotEmpty) {
      try {
        final data = args[0];
        if (data is List) {
          // Convert to list of maps for serialization
          final list = data.map((e) {
            if (e is Map<String, dynamic>) return e;
            return {'raw': e.toString()};
          }).toList();
          service.invoke('bg_ReceiveRideChatHistory', {'messages': list});
        }
      } catch (e) {
        print('❌ SAHAr [BG-ISO] Error parsing ReceiveRideChatHistory: $e');
      }
    }
  });

  // --- Driver-Admin Chat ---
  hubConnection.on('ReceiveDriverAdminMessage', (List<Object?>? args) {
    print('💬 SAHAr [BG-ISO] ReceiveDriverAdminMessage: $args');
    if (args != null && args.isNotEmpty) {
      try {
        final data = args[0];
        if (data is Map<String, dynamic>) {
          service.invoke('bg_ReceiveDriverAdminMessage', data);
        } else {
          service.invoke('bg_ReceiveDriverAdminMessage', {'raw': data.toString()});
        }
      } catch (e) {
        print('❌ SAHAr [BG-ISO] Error parsing ReceiveDriverAdminMessage: $e');
      }
    }
  });

  hubConnection.on('ReceiveDriverAdminChatHistory', (List<Object?>? args) {
    print('📜 SAHAr [BG-ISO] ReceiveDriverAdminChatHistory');
    if (args != null && args.isNotEmpty) {
      try {
        final data = args[0];
        if (data is List) {
          final list = data.map((e) {
            if (e is Map<String, dynamic>) return e;
            return {'raw': e.toString()};
          }).toList();
          service.invoke('bg_ReceiveDriverAdminChatHistory', {'messages': list});
        }
      } catch (e) {
        print('❌ SAHAr [BG-ISO] Error parsing ReceiveDriverAdminChatHistory: $e');
      }
    }
  });

  // --- PaymentCompleted (used by BackgroundTrackingService) ---
  hubConnection.on('PaymentCompleted', (List<Object?>? args) {
    print('💰 SAHAr [BG-ISO] PaymentCompleted: $args');
    if (args != null && args.isNotEmpty) {
      try {
        final data = args[0];
        if (data is Map<String, dynamic>) {
          service.invoke('bg_PaymentCompleted', data);
        } else {
          service.invoke('bg_PaymentCompleted', {'raw': data.toString()});
        }
      } catch (e) {
        print('❌ SAHAr [BG-ISO] Error parsing PaymentCompleted: $e');
      }
    }
  });

  // ── Start SignalR connection ──
  try {
    print('🔌 SAHAr [BG-ISO] Starting SignalR connection...');
    await hubConnection.start();
    print('✅ SAHAr [BG-ISO] SignalR connected! ConnectionId: ${hubConnection.connectionId}');
    service.invoke('bg_connectionState', {'state': 'connected', 'connectionId': hubConnection.connectionId});

    // Subscribe driver for ride assignments
    await _subscribeDriver(hubConnection, driverId);

  } catch (e) {
    print('❌ SAHAr [BG-ISO] SignalR start failed: $e');
    service.invoke('bg_connectionState', {'state': 'error', 'error': e.toString()});
    // Don't stop service — automatic reconnect will kick in
  }

  // ── Promote to foreground and set notification ──
  if (service is AndroidServiceInstance) {
    try {
      service.setAsForegroundService();
      service.setForegroundNotificationInfo(
        title: 'Pick U Driver',
        content: "You're online and available for rides",
      );
    } catch (e) {
      print('❌ SAHAr [BG-ISO] Failed to set foreground notification: $e');
      // If foreground promotion fails (e.g. notification permission revoked),
      // stop the service gracefully instead of letting Android kill the process.
      service.stopSelf();
      return;
    }
  }

  // ══════════════════════════════════════════════════════════
  // LOCATION TRACKING — 2 Conditions: 10m distance + 60s timer
  // ══════════════════════════════════════════════════════════

  // Condition 1: Distance-based stream (10 meter filter)
  StreamSubscription<Position>? positionSubscription;
  try {
    final locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: _minimumDistanceMeters.toInt(),
    );

    positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) async {
        print('📍 SAHAr [BG-ISO] Position: ${position.latitude}, ${position.longitude}');

        // Send to server
        await _sendLocation(hubConnection!, driverId, driverName, currentRideId, position.latitude, position.longitude);
        lastSendTime = DateTime.now();

        // Forward to UI for map updates
        service.invoke('bg_LocationUpdate', {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'speed': position.speed,
          'heading': position.heading,
          'timestamp': position.timestamp.millisecondsSinceEpoch,
        });
      },
      onError: (error) {
        print('❌ SAHAr [BG-ISO] Position stream error: $error');
      },
    );

    print('✅ SAHAr [BG-ISO] Location stream started (${_minimumDistanceMeters}m filter)');
  } catch (e) {
    print('❌ SAHAr [BG-ISO] Error starting location stream: $e');
  }

  // Condition 2: Timer fallback — every 60 seconds
  Timer timerFallback = Timer.periodic(
    const Duration(seconds: _timerFallbackSeconds),
    (timer) async {
      final secondsSinceLastSend = DateTime.now().difference(lastSendTime).inSeconds;
      if (secondsSinceLastSend >= _timerFallbackSeconds) {
        print('⏰ SAHAr [BG-ISO] Timer fallback: ${secondsSinceLastSend}s since last send, force-fetching location');
        try {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );
          await _sendLocation(hubConnection!, driverId, driverName, currentRideId, position.latitude, position.longitude);
          lastSendTime = DateTime.now();

          service.invoke('bg_LocationUpdate', {
            'latitude': position.latitude,
            'longitude': position.longitude,
            'speed': position.speed,
            'heading': position.heading,
            'timestamp': position.timestamp.millisecondsSinceEpoch,
          });

          print('✅ SAHAr [BG-ISO] Timer fallback location sent');
        } catch (e) {
          print('❌ SAHAr [BG-ISO] Timer fallback error: $e');
        }
      }
    },
  );

  // ══════════════════════════════════════════════════════════
  // LISTEN FOR UI → BACKGROUND COMMANDS
  // ══════════════════════════════════════════════════════════

  // Update foreground notification text from UI
  service.on('updateNotification').listen((event) {
    if (event != null) {
      final androidService = service is AndroidServiceInstance ? service : null;
      androidService?.setForegroundNotificationInfo(
        title: event['title']?.toString() ?? 'Pick U Driver',
        content: event['content']?.toString() ?? "You're online and available for rides",
      );
    }
  });

  // Update ride ID from UI
  service.on('updateRideId').listen((event) {
    if (event != null && event['rideId'] != null) {
      currentRideId = event['rideId'].toString();
      print('🔄 SAHAr [BG-ISO] Ride ID updated from UI: $currentRideId');
    }
  });

  // Join ride chat from UI
  service.on('joinRideChat').listen((event) async {
    if (event != null && event['rideId'] != null && hubConnection != null) {
      String rideId = event['rideId'].toString();
      currentRideId = rideId;
      await _joinRideChat(hubConnection!, rideId);
    }
  });

  // Load ride chat history from UI
  service.on('loadRideChatHistory').listen((event) async {
    if (event != null && event['rideId'] != null && hubConnection != null) {
      try {
        await hubConnection!.invoke('GetRideChatHistory', args: [event['rideId']]);
        print('📜 SAHAr [BG-ISO] Chat history requested for: ${event['rideId']}');
      } catch (e) {
        print('❌ SAHAr [BG-ISO] Error requesting chat history: $e');
      }
    }
  });

  // Send ride chat message from UI
  service.on('sendRideChatMessage').listen((event) async {
    if (event != null && hubConnection != null) {
      try {
        await hubConnection!.invoke('SendMessage', args: [
          event['rideId'] ?? currentRideId,
          event['senderId'] ?? driverId,
          event['message'] ?? '',
          event['senderRole'] ?? 'Driver',
        ]);
        print('💬 SAHAr [BG-ISO] Ride chat message sent');
      } catch (e) {
        print('❌ SAHAr [BG-ISO] Error sending ride chat message: $e');
        service.invoke('bg_chatError', {'error': e.toString(), 'type': 'ride'});
      }
    }
  });

  // Join driver support from UI
  service.on('joinDriverSupport').listen((event) async {
    try {
      await hubConnection!.invoke('JoinDriverSupport', args: [driverId]);
      print('🎧 SAHAr [BG-ISO] Joined driver support group');
    } catch (e) {
      print('❌ SAHAr [BG-ISO] Error joining driver support: $e');
    }
  });

  // Load driver-admin chat history from UI
  service.on('loadAdminChatHistory').listen((event) async {
    try {
      await hubConnection!.invoke('GetDriverAdminChatHistory', args: [driverId]);
      print('📜 SAHAr [BG-ISO] Admin chat history requested');
    } catch (e) {
      print('❌ SAHAr [BG-ISO] Error requesting admin chat history: $e');
    }
  });

  // Send driver-admin chat message from UI
  service.on('sendAdminMessage').listen((event) async {
    if (event != null && event['message'] != null) {
      try {
        await hubConnection!.invoke('SendDriverAdminMessage', args: [
          driverId,
          driverId,
          'Driver',
          event['message'],
        ]);
        print('💬 SAHAr [BG-ISO] Admin message sent');
      } catch (e) {
        print('❌ SAHAr [BG-ISO] Error sending admin message: $e');
        service.invoke('bg_chatError', {'error': e.toString(), 'type': 'admin'});
      }
    }
  });

  // Subscribe to rides from UI
  service.on('subscribeDriver').listen((event) async {
    await _subscribeDriver(hubConnection!, driverId);
  });

  // Force reconnect from UI
  service.on('reconnect').listen((event) async {
    print('🔄 SAHAr [BG-ISO] Force reconnect requested');
    try {
      if (hubConnection!.state == HubConnectionState.disconnected) {
        await hubConnection!.start();
        print('✅ SAHAr [BG-ISO] Reconnected');
        service.invoke('bg_connectionState', {'state': 'connected'});
        await _subscribeDriver(hubConnection!, driverId);
      }
    } catch (e) {
      print('❌ SAHAr [BG-ISO] Reconnect failed: $e');
      service.invoke('bg_connectionState', {'state': 'error', 'error': e.toString()});
    }
  });

  // Stop service from UI
  service.on('stopService').listen((event) async {
    print('🛑 SAHAr [BG-ISO] Stop requested');
    timerFallback.cancel();
    positionSubscription?.cancel();
    try {
      await hubConnection!.stop();
    } catch (e) {
      print('⚠️ SAHAr [BG-ISO] Error stopping hub: $e');
    }
    service.stopSelf();
    print('🛑 SAHAr [BG-ISO] Service stopped');
  });

  // Stop tracking command from UI
  service.on('stopTracking').listen((event) {
    currentRideId = ''; // Clear the ride ID in the background isolate
    print('🛑 SAHAr [BG-ISO] Tracking stopped for completed ride');
  });

  print('✅ SAHAr [BG-ISO] Background isolate setup complete');

}

// ══════════════════════════════════════════════════════════
// Helper functions (used within the background isolate)
// ══════════════════════════════════════════════════════════

/// Subscribe driver for ride assignments
Future<void> _subscribeDriver(HubConnection hub, String driverId) async {
  try {
    if (hub.state != HubConnectionState.connected) {
      print('⚠️ SAHAr [BG-ISO] Cannot subscribe: not connected');
      return;
    }
    await hub.invoke('SubscribeDriver', args: [driverId]);
    print('✅ SAHAr [BG-ISO] SubscribeDriver invoked for: $driverId');
  } catch (e) {
    print('❌ SAHAr [BG-ISO] Error subscribing driver: $e');
  }
}

/// Join ride chat room
Future<void> _joinRideChat(HubConnection hub, String rideId) async {
  try {
    if (hub.state != HubConnectionState.connected) return;
    await hub.invoke('JoinRideChat', args: [rideId]);
    print('💬 SAHAr [BG-ISO] Joined ride chat: $rideId');
  } catch (e) {
    print('❌ SAHAr [BG-ISO] Error joining ride chat: $e');
  }
}

/// Send location update to SignalR hub.
/// Server expects 4 args: rideId, driverId, latitude, longitude (same as main isolate).
Future<void> _sendLocation(
  HubConnection hub,
  String driverId,
  String? driverName,
  String currentRideId,
  double latitude,
  double longitude,
) async {
  try {
    if (hub.state != HubConnectionState.connected) {
      print('⚠️ SAHAr [BG-ISO] Cannot send location: not connected');
      return;
    }

    String rideId = currentRideId.isEmpty ? _emptyGuid : currentRideId;
    await hub.invoke('UpdateLocation', args: [rideId, driverId, latitude, longitude]);
    print('📍 SAHAr [BG-ISO] Location sent: $latitude, $longitude');
  } catch (e) {
    print('❌ SAHAr [BG-ISO] Error sending location: $e');
  }
}
