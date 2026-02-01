import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pick_u_driver/core/sharePref.dart';
import 'package:signalr_core/signalr_core.dart';
import 'package:geolocator/geolocator.dart';

class SignalRService extends GetxService {
  static SignalRService get to => Get.find();

  // SignalR connection
  HubConnection? _hubConnection;

  // Observable variables
  var isConnected = false.obs;
  var currentRideId = ''.obs;
  var isLocationSending = false.obs;
  var connectionStatus = 'Disconnected'.obs;
  var lastSentLocation = Rxn<Position>();
  var locationUpdateCount = 0.obs;

  // Timers and streams
  Timer? _locationTimer;
  StreamSubscription<Position>? _positionStream;

  // Configuration
  static const String _hubUrl = 'http://api.pickurides.com/ridechathub';
  static const String _emptyGuid = '00000000-0000-0000-0000-000000000000';
  static const double _minimumDistanceFilter = 10.0; // meters
  static const int _locationUpdateIntervalSeconds = 5;
  /// Set driver information
  void setDriverInfo(String driverId, String driverName) {
    _driverId = driverId;
    _driverName = driverName;
    print(' SAHAr Driver info set: $driverName ($driverId)');
  }
  // Driver information (loaded from SharedPrefs)
  String? _driverId;
  String? _driverName;

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
      print(' SAHAr Driver info loaded: $_driverName ($_driverId)');
    } catch (e) {
      print(' SAHAr Error loading driver info: $e');
    }
  }

  /// Initialize SignalR connection
  Future<void> _initializeConnection() async {
    try {
      _hubConnection = HubConnectionBuilder()
          .withUrl(_hubUrl)
          .withAutomaticReconnect([2000, 5000, 10000, 15000, 30000]) // Progressive backoff
          .build();

      // Set up connection event handlers
      _setupConnectionHandlers();


    } catch (e) {
      print(' SAHAr Error initializing SignalR: $e');
      connectionStatus.value = 'Error: $e';
    }
  }

  /// Set up connection event handlers
  void _setupConnectionHandlers() {
    if (_hubConnection == null) return;

    // Connection state changes
    _hubConnection!.onclose((error) {
      print(' SAHAr SignalR connection closed: $error');
      isConnected.value = false;
      connectionStatus.value = 'Disconnected';

      // Stop location updates when connection is lost
      if (isLocationSending.value) {
        _pauseLocationUpdates();
      }
    });

    _hubConnection!.onreconnecting((error) {
      print(' SAHAr SignalR reconnecting: $error');
      connectionStatus.value = 'Reconnecting...';
    });

    _hubConnection!.onreconnected((connectionId) {
      print(' SAHAr SignalR reconnected: $connectionId');
      isConnected.value = true;
      connectionStatus.value = 'Connected';

      // Resume location updates if they were active
      if (isLocationSending.value) {
        _resumeLocationUpdates();
      }
    });

    // Listen for ride assignment updates from server
    _hubConnection!.on('RideAssigned', (List<Object?>? arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        String newRideId = arguments[0].toString();
        print(' SAHAr Ride assigned: $newRideId');
        currentRideId.value = newRideId;
        _onRideAssigned(newRideId);
      }
    });

    // Listen for ride completion/cancellation
    _hubConnection!.on('RideCompleted', (List<Object?>? arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        String completedRideId = arguments[0].toString();
        print(' SAHAr Ride completed: $completedRideId');

        if (currentRideId.value == completedRideId) {
          currentRideId.value = '';
          _onRideCompleted(completedRideId);
        }
      }
    });

    // Listen for location acknowledgments
    _hubConnection!.on('LocationReceived', (List<Object?>? arguments) {
      print(' SAHAr Location update acknowledged by server');
    });

    // Listen for driver status changes from server
    _hubConnection!.on('DriverStatusChanged', (List<Object?>? arguments) {
      if (arguments != null && arguments.length >= 2) {
        String driverId = arguments[0].toString();
        bool isOnline = arguments[1] as bool;

        if (driverId == _driverId) {
          print(' SAHAr Driver status changed from server: $isOnline');
          // You can emit this to update UI if needed
        }
      }
    });
  }

  /// Connect to SignalR hub
  Future<bool> connect() async {
    if (_hubConnection == null) return false;

    try {
      connectionStatus.value = 'Connecting...';

      await _hubConnection!.start();

      isConnected.value = true;
      connectionStatus.value = 'Connected';
      print(' SAHAr Successfully connected to SignalR hub');

      return true;

    } catch (e) {
      print(' SAHAr Failed to connect to SignalR: $e');
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

  /// Send location update to SignalR hub
  Future<bool> sendLocationUpdate(double latitude, double longitude) async {
    if (!isConnected.value || _hubConnection == null) {
      print(' SAHAr Cannot send location: not connected');
      return false;
    }

    if (_driverId == null || _driverName == null) {
      print(' SAHAr Cannot send location: driver info not set');
      return false;
    }

    try {
      // Use current ride ID if available, otherwise use empty GUID
      String rideId = currentRideId.value.isEmpty ? _emptyGuid : currentRideId.value;

      print(' SAHAr Sending location: ($latitude, $longitude) for ride: $rideId');

      await _hubConnection!.invoke(
          'UpdateLocation',
          args: [rideId, _driverId, _driverName, latitude, longitude]
      );

      locationUpdateCount.value++;
      print(' SAHAr Location sent successfully (Count: ${locationUpdateCount.value})');
      return true;

    } catch (e) {
      print(' SAHAr Error sending location: $e');
      return false;
    }
  }

  /// Start continuous location updates
  Future<void> startLocationUpdates({Duration interval = const Duration(seconds: 5)}) async {
    if (isLocationSending.value) {
      print(' SAHAr Location updates already running');
      return;
    }

    // Reload driver info to ensure it's current
    await _loadDriverInfo();

    if (_driverId == null || _driverName == null) {
      print(' SAHAr Cannot start location updates: driver info not available');
      Get.snackbar('Error', 'Driver information not available. Please login again.');
      return;
    }

    // Check if we have location permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      print(' SAHAr Location permission denied');
      Get.snackbar('Permission Required', 'Location permission is needed for live tracking');
      return;
    }

    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print(' SAHAr Location services are disabled');
      Get.snackbar('GPS Required', 'Please enable GPS to start location tracking');
      return;
    }

    isLocationSending.value = true;
    locationUpdateCount.value = 0;
    print(' SAHAr Starting continuous location updates every ${interval.inSeconds}s');

    // Start position stream for real-time updates
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Update every 5 meters
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
          (Position position) async {
        // Check if we should send this update (distance filter)
        if (_shouldSendLocationUpdate(position)) {
          bool success = await sendLocationUpdate(position.latitude, position.longitude);

          if (success) {
            lastSentLocation.value = position;
          } else if (!isConnected.value) {
            // Try to reconnect if sending failed due to connection
            print(' SAHAr Attempting to reconnect due to location send failure');
            await connect();
          }
        }
      },
      onError: (error) {
        print(' SAHAr Position stream error: $error');
      },
    );

    // Also start a timer-based backup system
    _locationTimer = Timer.periodic(interval, (timer) async {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        // Send update regardless of distance (timer-based backup)
        bool success = await sendLocationUpdate(position.latitude, position.longitude);

        if (success) {
          lastSentLocation.value = position;
        } else if (!isConnected.value) {
          // Try to reconnect if sending failed due to connection
          await connect();
        }

      } catch (e) {
        print(' SAHAr Error getting location in timer: $e');
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
      print(' SAHAr Error sending initial location: $e');
    }
  }

  /// Check if we should send a location update based on distance
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

  /// Stop continuous location updates
  void stopLocationUpdates() {
    _stopLocationUpdates();
  }

  void _stopLocationUpdates() {
    if (_locationTimer != null) {
      _locationTimer!.cancel();
      _locationTimer = null;
    }

    if (_positionStream != null) {
      _positionStream!.cancel();
      _positionStream = null;
    }

    isLocationSending.value = false;
    print(' SAHAr All location updates stopped');
  }

  /// Pause location updates (during connection issues)
  void _pauseLocationUpdates() {
    if (_positionStream != null) {
      _positionStream!.pause();
    }
    print(' SAHAr Location updates paused due to connection issue');
  }

  /// Resume location updates (after reconnection)
  void _resumeLocationUpdates() {
    if (_positionStream != null && _positionStream!.isPaused) {
      _positionStream!.resume();
    }
    print(' SAHAr Location updates resumed after reconnection');
  }

  /// Handle ride assignment
  void _onRideAssigned(String rideId) {
    Get.snackbar(
      'Ride Assigned',
      'You have been assigned ride: ${rideId.substring(0, 8)}...',
      duration: const Duration(seconds: 5),
      backgroundColor: Colors.green.shade100,
      colorText: Colors.green.shade800,
    );

    // Increase location update frequency for active rides
    if (isLocationSending.value) {
      _restartLocationUpdatesForRide();
    }
  }

  /// Handle ride completion
  void _onRideCompleted(String rideId) {
    Get.snackbar(
      'Ride Completed',
      'Ride ${rideId.substring(0, 8)}... has been completed',
      duration: const Duration(seconds: 3),
      backgroundColor: Colors.blue.shade100,
      colorText: Colors.blue.shade800,
    );

    // Return to normal location update frequency
    if (isLocationSending.value) {
      _restartLocationUpdatesNormal();
    }
  }

  /// Restart location updates with higher frequency for active rides
  void _restartLocationUpdatesForRide() {
    if (isLocationSending.value) {
      _stopLocationUpdates();
      startLocationUpdates(interval: const Duration(seconds: 3)); // Higher frequency during rides
    }
  }

  /// Restart location updates with normal frequency
  void _restartLocationUpdatesNormal() {
    if (isLocationSending.value) {
      _stopLocationUpdates();
      startLocationUpdates(); // Normal frequency
    }
  }

  /// Manual location send (for testing or immediate updates)
  Future<void> sendCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      await sendLocationUpdate(position.latitude, position.longitude);

    } catch (e) {
      print(' SAHAr Error sending current location: $e');
      Get.snackbar('Error', 'Failed to send location: $e');
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