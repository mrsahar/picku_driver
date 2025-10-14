import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pick_u_driver/core/google_directions_service.dart';
import 'package:pick_u_driver/core/location_service.dart';
import 'package:pick_u_driver/core/sharePref.dart';
import 'package:pick_u_driver/driver_screen/widget/modern_payment_dialog.dart';
import 'package:pick_u_driver/models/ride_assignment_model.dart';
import 'package:signalr_core/signalr_core.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pick_u_driver/utils/theme/mcolors.dart';

class BackgroundTrackingService extends GetxService {
  static BackgroundTrackingService get to => Get.find();

  // Services
  final LocationService _locationService = LocationService.to;

  // SignalR connection (single connection for everything)
  HubConnection? _hubConnection;

  // Observable variables
  var isRunning = false.obs;
  var isConnected = false.obs;
  var connectionStatus = 'Disconnected'.obs;
  var currentRideId = ''.obs;
  var isLocationSending = false.obs;
  var lastSentLocation = Rxn<Position>();
  var locationUpdateCount = 0.obs;
  var isWaitingForPayment = false.obs;
  var paymentCompleted = false.obs;
  var showPaymentDialog = false.obs;

  // Ride assignment observables
  var isSubscribed = false.obs;
  var currentRide = Rxn<RideAssignment>();
  var rideStatus = 'No Active Ride'.obs;
  var routePolylines = <Polyline>{}.obs;
  var rideMarkers = <Marker>{}.obs;

  // Driver info
  String? _driverId;
  String? _driverName;

  // Timers and streams
  Timer? _locationTimer;
  StreamSubscription<Position>? _positionStream;
  Timer? _reconnectionTimer;

  // Configuration
  static const String _hubUrl = 'http://pickurides.com/ridehub';
  static const String _emptyGuid = '00000000-0000-0000-0000-000000000000';
  static const double _minimumDistanceFilter = 10.0; // meters
  static const int _locationUpdateIntervalSeconds = 5;

  // Custom marker icons
  BitmapDescriptor? _currentLocationIcon;
  BitmapDescriptor? _pickupIcon;
  BitmapDescriptor? _destinationIcon;
  BitmapDescriptor? _stopIcon;

  @override
  void onInit() {
    super.onInit();
    _loadDriverInfo();
    _initializeConnection();
    _loadCustomMarkers();
  }

  /// Load custom marker icons
  Future<void> _loadCustomMarkers() async {
    try {
      _currentLocationIcon = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/img/points.png',
      );

      _pickupIcon = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/img/points.png',
      );

      _destinationIcon = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/img/points.png',
      );

      _stopIcon = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/img/points.png',
      );

      print('✅ SAHAr Custom markers loaded');
    } catch (e) {
      print('⚠️ SAHAr Failed to load custom markers: $e');
      // Fallback to default markers
      _currentLocationIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      _pickupIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      _destinationIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
      _stopIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan);
    }
  }

  /// Load driver information
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

      print('🚗 SAHAr Driver loaded: $_driverName ($_driverId)');
    } catch (e) {
      print('❌ SAHAr Error loading driver info: $e');
      Timer(const Duration(seconds: 5), () => _loadDriverInfo());
    }
  }

  /// Initialize SignalR connection
  Future<void> _initializeConnection() async {
    try {
      _hubConnection = HubConnectionBuilder()
          .withUrl(_hubUrl)
          .withAutomaticReconnect([2000, 5000, 10000, 15000, 30000])
          .build();

      _setupConnectionHandlers();
      print('✅ SAHAr SignalR hub initialized');
    } catch (e) {
      print('❌ SAHAr Error initializing SignalR: $e');
      connectionStatus.value = 'Error: $e';
    }
  }

  /// Set up all SignalR event handlers
  void _setupConnectionHandlers() {
    if (_hubConnection == null) return;

    // Connection state handlers
    _hubConnection!.onclose((error) {
      print('❌ SAHAr Hub disconnected: $error');
      isConnected.value = false;
      isSubscribed.value = false;
      connectionStatus.value = 'Disconnected';
      _pauseLocationUpdates();
      _startReconnectionTimer();
    });

    _hubConnection!.onreconnecting((error) {
      print('🔄 SAHAr Hub reconnecting: $error');
      connectionStatus.value = 'Reconnecting...';
    });

    _hubConnection!.onreconnected((connectionId) {
      print('✅ SAHAr Hub reconnected: $connectionId');
      isConnected.value = true;
      connectionStatus.value = 'Connected';
      _stopReconnectionTimer();
      _resumeLocationUpdates();

      // Re-subscribe to ride assignments
      if (_driverId != null) {
        _autoSubscribe();
      }
    });

    // ===== RIDE ASSIGNMENT EVENTS =====
    _hubConnection!.on('NewRideAssigned', (List<Object?>? arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        try {
          print('🚕 SAHAr New ride assigned!');
          final rideData = arguments[0] as Map<String, dynamic>;
          _handleNewRideAssignment(rideData);
        } catch (e) {
          print('❌ SAHAr Error parsing ride: $e');
        }
      }
    });

    _hubConnection!.on('RideStatusUpdate', (List<Object?>? arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        try {
          final statusUpdate = arguments[0] as Map<String, dynamic>;
          _handleRideStatusUpdate(statusUpdate);
        } catch (e) {
          print('❌ SAHAr Error parsing status: $e');
        }
      }
    });

    // ===== LOCATION TRACKING EVENTS =====
    _hubConnection!.on('LocationReceived', (List<Object?>? arguments) {
      print('📍 SAHAr Location acknowledged by server');
    });

    _hubConnection!.on('RideCompleted', (List<Object?>? arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        String completedRideId = arguments[0].toString();
        if (currentRideId.value == completedRideId) {
          print('✅ SAHAr Ride completed: $completedRideId');
          currentRideId.value = '';
        }
      }
    });


    _hubConnection!.on('PaymentCompleted', (List<Object?>? arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        try {
          final paymentData = arguments[0] as Map<String, dynamic>;
          String rideId = paymentData['rideId']?.toString() ?? '';
          String message = paymentData['message']?.toString() ?? '';

          print('💰 SAHAr Payment data received: $paymentData');

          // Update the current ride with payment info
          if (currentRide.value != null) {
            // Parse tip value properly
            double tip = 0.0;
            if (paymentData['tip'] != null) {
              if (paymentData['tip'] is int) {
                tip = (paymentData['tip'] as int).toDouble();
              } else if (paymentData['tip'] is double) {
                tip = paymentData['tip'] as double;
              } else {
                tip = double.tryParse(paymentData['tip'].toString()) ?? 0.0;
              }
            }

            print('💰 SAHAr Parsed tip: \$${tip.toStringAsFixed(2)}');

            // Create updated ride data with payment info
            final updatedRideData = {
              'rideId': currentRide.value!.rideId,
              'rideType': currentRide.value!.rideType,
              'fareFinal': currentRide.value!.fareFinal,
              'createdAt': currentRide.value!.createdAt.toIso8601String(),
              'status': 'Completed',
              'passengerId': currentRide.value!.passengerId,
              'passengerName': currentRide.value!.passengerName,
              'passengerPhone': currentRide.value!.passengerPhone,
              'pickupLocation': currentRide.value!.pickupLocation,
              'pickUpLat': currentRide.value!.pickUpLat,
              'pickUpLon': currentRide.value!.pickUpLon,
              'dropoffLocation': currentRide.value!.dropoffLocation,
              'dropoffLat': currentRide.value!.dropoffLat,
              'dropoffLon': currentRide.value!.dropoffLon,
              'stops': currentRide.value!.stops.map((s) => {
                'stopOrder': s.stopOrder,
                'location': s.location,
                'latitude': s.latitude,
                'longitude': s.longitude,
              }).toList(),
              'passengerCount': currentRide.value!.passengerCount,
              'payment': 'Successful',
              'tip': tip,
            };

            print('💰 SAHAr Creating new ride assignment with payment info');

            // CRITICAL: Force reactive update by setting to null first, then updating
            // This ensures GetX detects the change
            currentRide.value = null;

            // Update after short delay to ensure GetX processes the null value
            Future.delayed(const Duration(milliseconds: 100), () {
              currentRide.value = RideAssignment.fromJson(updatedRideData);

              print('💰 SAHAr ✅ Ride updated successfully!');
              print('   - Payment: ${currentRide.value!.payment}');
              print('   - Tip: \$${currentRide.value!.tip?.toStringAsFixed(2) ?? "0.00"}');
              print('   - Total: \$${(currentRide.value!.fareFinal + (currentRide.value!.tip ?? 0)).toStringAsFixed(2)}');

              // Update flags - this will trigger bottom sheet to update
              paymentCompleted.value = true;
              isWaitingForPayment.value = false;

              // NO snackbar here - the bottom sheet will update automatically
              print('💰 SAHAr Bottom sheet should update now with payment info');
            });
          } else {
            print('⚠️ SAHAr Cannot update payment - no current ride');
          }

          print('💰 SAHAr Payment received: $message for ride: $rideId');
        } catch (e) {
          print('❌ SAHAr Error parsing payment: $e');
          print('❌ SAHAr Stack trace: ${StackTrace.current}');
        }
      }
    });

    // ===== DRIVER STATUS EVENTS =====
    _hubConnection!.on('DriverStatusChanged', (List<Object?>? arguments) {
      if (arguments != null && arguments.length >= 2) {
        try {
          String driverId = arguments[0].toString();
          bool isOnline = arguments[1] as bool;

          if (driverId == _driverId) {
            print('🔄 SAHAr Driver status changed from server: ${isOnline ? "Online" : "Offline"}');

            Get.snackbar(
              'Status Update',
              'Your status has been changed to ${isOnline ? "Online" : "Offline"}',
              backgroundColor: isOnline ? Colors.green.shade100 : Colors.orange.shade100,
              colorText: isOnline ? Colors.green.shade800 : Colors.orange.shade800,
              duration: const Duration(seconds: 3),
              icon: Icon(
                isOnline ? Icons.check_circle : Icons.offline_bolt,
                color: isOnline ? Colors.green.shade800 : Colors.orange.shade800,
              ),
            );
          }
        } catch (e) {
          print('❌ SAHAr Error parsing driver status change: $e');
        }
      }
    });
  }


  /// Start reconnection timer
  void _startReconnectionTimer() {
    _stopReconnectionTimer();
    _reconnectionTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!isConnected.value) {
        print('🔄 SAHAr Attempting reconnection...');
        _connect();
      } else {
        _stopReconnectionTimer();
      }
    });
  }

  void _stopReconnectionTimer() {
    _reconnectionTimer?.cancel();
    _reconnectionTimer = null;
  }

  /// Connect to SignalR hub
  Future<bool> _connect() async {
    if (_hubConnection != null) {
      try {
        final state = _hubConnection!.state;
        print('🔄 SAHAr Current hub state: $state');

        if (state != HubConnectionState.disconnected) {
          print('🔄 SAHAr Disposing existing connection...');
          await _hubConnection!.stop();
          _hubConnection = null;
        }
      } catch (e) {
        print('⚠️ SAHAr Error checking/stopping existing connection: $e');
        _hubConnection = null;
      }
    }

    if (_hubConnection == null) {
      await _initializeConnection();
    }

    if (_hubConnection == null) return false;

    try {
      connectionStatus.value = 'Connecting...';
      await _hubConnection!.start();
      isConnected.value = true;
      connectionStatus.value = 'Connected';
      print('✅ SAHAr Connected to hub');
      return true;
    } catch (e) {
      print('❌ SAHAr Connection failed: $e');
      connectionStatus.value = 'Failed';
      _hubConnection = null;
      return false;
    }
  }

  /// Auto-subscribe with retry logic (wait for connection)
  Future<void> _autoSubscribe() async {
    if (_driverId == null || _driverId!.isEmpty) {
      print('❌ SAHAr Cannot auto-subscribe: Driver ID not available');
      return;
    }

    print('🔄 SAHAr Starting auto-subscribe...');

    // Wait for connection with retries
    int retries = 0;
    const maxRetries = 10;

    while (connectionStatus.value != 'Connected' && retries < maxRetries) {
      print('⏳ SAHAr Waiting for connection... (${retries + 1}/$maxRetries)');
      await Future.delayed(const Duration(seconds: 1));
      retries++;
    }

    if (connectionStatus.value == 'Connected') {
      await _subscribeToRideAssignments();
      print('✅ SAHAr Auto-subscribe completed successfully');
    } else {
      print('❌ SAHAr Auto-subscribe failed: connection timeout after $maxRetries retries');

      Get.snackbar(
        'Connection Issue',
        'Could not subscribe to ride assignments. Retrying...',
        backgroundColor: Colors.orange.shade100,
        colorText: Colors.orange.shade800,
        duration: const Duration(seconds: 3),
      );

      // Retry after delay
      Timer(const Duration(seconds: 5), () => _autoSubscribe());
    }
  }

  /// Subscribe to ride assignments
  Future<void> _subscribeToRideAssignments() async {
    if (_hubConnection == null || _driverId == null) return;

    try {
      await _hubConnection!.invoke('SubscribeDriver', args: [_driverId]);
      isSubscribed.value = true;
      print('✅ SAHAr Subscribed to rides for: $_driverId');
    } catch (e) {
      print('❌ SAHAr Subscription error: $e');
    }
  }

  /// Unsubscribe from ride assignments
  Future<void> _unsubscribeFromRideAssignments() async {
    if (_hubConnection == null || _driverId == null) return;

    try {
      await _hubConnection!.invoke('UnsubscribeDriver', args: [_driverId]);
      isSubscribed.value = false;
      print('✅ SAHAr Unsubscribed from rides');
      _resetRide();
    } catch (e) {
      print('❌ SAHAr Unsubscribe error: $e');
    }
  }

  /// Handle new ride assignment
  void _handleNewRideAssignment(Map<String, dynamic> rideData) {
    try {
      final ride = RideAssignment.fromJson(rideData);
      currentRide.value = ride;
      rideStatus.value = ride.status;
      currentRideId.value = ride.rideId;

      _showRideNotification(ride);
      _updateUIForRideStatus(ride);

      print('🚕 SAHAr Ride ${ride.rideId} - ${ride.status}');
    } catch (e) {
      print('❌ SAHAr Error handling ride: $e');
    }
  }

  /// Handle ride status updates
  void _handleRideStatusUpdate(Map<String, dynamic> statusData) {
    try {
      final ride = RideAssignment.fromJson(statusData);
      currentRide.value = ride;
      rideStatus.value = ride.status;
      currentRideId.value = ride.rideId;
      _updateUIForRideStatus(ride);
      print('🔄 SAHAr Ride status: ${ride.status}');
    } catch (e) {
      print('❌ SAHAr Error handling status: $e');
    }
  }

  /// Show ride notification
  /// Show ride notification - Replace your existing method
  void _showRideNotification(RideAssignment ride) {
    // Don't show notification if payment dialog is showing
    // (payment completion will be shown in the bottom sheet)
    if (showPaymentDialog.value && ride.status == 'Completed') {
      print('🔕 SAHAr Skipping notification - payment dialog is active');
      return;
    }

    String title = '';
    String message = '';
    Color bgColor = Colors.blue.shade100;
    Color textColor = Colors.blue.shade800;
    IconData icon = Icons.directions_car;

    switch (ride.status) {
      case 'Waiting':
        title = 'New Ride Request!';
        message = 'Pickup: ${ride.pickupLocation}';
        bgColor = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        icon = Icons.schedule;
        break;
      case 'In-Progress':
        title = 'Ride Started';
        message = 'Heading to: ${ride.dropoffLocation}';
        bgColor = Colors.blue.shade100;
        textColor = Colors.blue.shade800;
        icon = Icons.directions_car;
        break;
      case 'Completed':
      // Only show this if payment dialog is NOT active
        title = 'Ride Completed';
        message = 'Waiting for payment...';
        bgColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        icon = Icons.check_circle;
        break;
    }

    Get.snackbar(
      title,
      message,
      backgroundColor: bgColor,
      colorText: textColor,
      duration: const Duration(seconds: 5),
      icon: Icon(icon, color: textColor),
    );
  }

  /// Update UI for ride status
  void _updateUIForRideStatus(RideAssignment ride) {
    switch (ride.status) {
      case 'Waiting':
        _showRouteToPickup(ride);
        break;
      case 'In-Progress':
        _showRouteToAllStops(ride);
        break;
      case 'Completed':
        _showCompletedRide(ride);
        break;
    }
  }

  /// Show route to pickup with custom markers
  Future<void> _showRouteToPickup(RideAssignment ride) async {
    try {
      await _locationService.getCurrentLocation();
      if (_locationService.currentLatLng.value == null) return;

      final origin = _locationService.currentLatLng.value!;
      final pickup = LatLng(ride.pickUpLat, ride.pickUpLon);

      final points = await GoogleDirectionsService.getRoutePoints(
        origin: origin,
        destination: pickup,
      );

      final polyline = Polyline(
        polylineId: const PolylineId('route_to_pickup'),
        points: points,
        color: Colors.orange,
        width: 5,
      );

      routePolylines.assignAll({polyline});

      final markers = <Marker>{
        Marker(
          markerId: const MarkerId('current_location'),
          position: origin,
          infoWindow: const InfoWindow(title: 'Your Location'),
          icon: _currentLocationIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
        Marker(
          markerId: const MarkerId('pickup'),
          position: pickup,
          infoWindow: InfoWindow(title: 'Pickup', snippet: ride.pickupLocation),
          icon: _pickupIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      };

      rideMarkers.assignAll(markers);
      print('✅ SAHAr Route to pickup displayed with custom markers');
    } catch (e) {
      print('❌ SAHAr Error showing pickup route: $e');
    }
  }

  /// Show route to all stops with custom markers
  Future<void> _showRouteToAllStops(RideAssignment ride) async {
    try {
      await _locationService.getCurrentLocation();
      if (_locationService.currentLatLng.value == null) return;

      final origin = _locationService.currentLatLng.value!;
      final waypoints = ride.stops
          .map((stop) => LatLng(stop.latitude, stop.longitude))
          .toList();

      if (waypoints.isEmpty) return;

      final points = await GoogleDirectionsService.getRoutePoints(
        origin: origin,
        destination: waypoints.last,
        waypoints: waypoints.length > 1 ? waypoints.sublist(0, waypoints.length - 1) : null,
      );

      final polyline = Polyline(
        polylineId: const PolylineId('route_with_stops'),
        points: points,
        color: MColor.primaryNavy,
        width: 5,
      );

      routePolylines.assignAll({polyline});

      final markers = <Marker>{
        Marker(
          markerId: const MarkerId('current_location'),
          position: origin,
          infoWindow: const InfoWindow(title: 'Your Location'),
          icon: _currentLocationIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      };

      for (var stop in ride.stops) {
        final isDestination = stop.stopOrder == ride.stops.length - 1;
        markers.add(
          Marker(
            markerId: MarkerId('stop_${stop.stopOrder}'),
            position: LatLng(stop.latitude, stop.longitude),
            infoWindow: InfoWindow(
              title: isDestination ? 'Destination' : 'Stop ${stop.stopOrder + 1}',
              snippet: stop.location,
            ),
            icon: isDestination
                ? (_destinationIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet))
                : (_stopIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan)),
          ),
        );
      }

      rideMarkers.assignAll(markers);
      print('✅ SAHAr Route with all stops displayed with custom markers');
    } catch (e) {
      print('❌ SAHAr Error showing route: $e');
    }
  }

  /// Show completed ride
  /// Show completed ride - Replace your existing method with this
  void _showCompletedRide(RideAssignment ride) {
    routePolylines.clear();
    rideMarkers.clear();

    // Set waiting for payment state
    isWaitingForPayment.value = true;
    paymentCompleted.value = false;
    showPaymentDialog.value = true;

    print('💰 SAHAr Showing payment bottom sheet for ride: ${ride.rideId}');

    // Show the modern payment bottom sheet (no ride parameter - it observes currentRide)
    Get.bottomSheet(
      ModernPaymentBottomSheet(
        onDismiss: () {
          print('💰 SAHAr Payment bottom sheet dismissed');
          _resetRide();
          isWaitingForPayment.value = false;
          paymentCompleted.value = false;
          showPaymentDialog.value = false;
          Get.back();
        },
      ),
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  /// Reset ride state
  void _resetRide() {
    currentRide.value = null;
    rideStatus.value = 'No Active Ride';
    routePolylines.clear();
    rideMarkers.clear();
    currentRideId.value = '';
    isWaitingForPayment.value = false;
    paymentCompleted.value = false;
    showPaymentDialog.value = false;
  }

  /// Manual reconnect (public method for UI)
  Future<void> manualReconnect() async {
    print('🔄 SAHAr Manual reconnect requested by user');

    Get.snackbar(
      'Reconnecting',
      'Attempting to reconnect to server...',
      backgroundColor: Colors.blue.shade100,
      colorText: Colors.blue.shade800,
      duration: const Duration(seconds: 2),
    );

    bool connected = await _connect();

    if (connected && _driverId != null) {
      await _autoSubscribe();

      Get.snackbar(
        'Reconnected',
        'Successfully reconnected and subscribed to rides',
        backgroundColor: Colors.green.shade100,
        colorText: Colors.green.shade800,
        duration: const Duration(seconds: 3),
      );
    } else {
      Get.snackbar(
        'Connection Failed',
        'Could not reconnect. Will retry automatically.',
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade800,
        duration: const Duration(seconds: 3),
      );
    }
  }

  /// Send location update
  Future<bool> sendLocationUpdate(double latitude, double longitude) async {
    if (!isConnected.value || _hubConnection == null) {
      print('❌ SAHAr Cannot send location: not connected');
      return false;
    }

    if (_driverId == null || _driverName == null || _driverId!.isEmpty || _driverName!.isEmpty) {
      print('❌ SAHAr Driver info missing, attempting to reload...');
      await _loadDriverInfo();

      if (_driverId == null || _driverName == null || _driverId!.isEmpty || _driverName!.isEmpty) {
        print('❌ SAHAr Cannot send location: driver info still missing after reload');
        return false;
      }
    }

    try {
      String rideId = currentRideId.value.isEmpty ? _emptyGuid : currentRideId.value;

      await _hubConnection!.invoke(
        'UpdateLocation',
        args: [rideId, _driverId, _driverName, latitude, longitude],
      );

      locationUpdateCount.value++;
      print('📍 SAHAr Location sent (${locationUpdateCount.value}) for driver: $_driverName ($_driverId)');
      return true;
    } catch (e) {
      print('❌ SAHAr Location send error: $e');
      return false;
    }
  }

  /// Check if location update should be sent
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

  /// Start location updates
  Future<void> _startLocationUpdates() async {
    if (isLocationSending.value) return;

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
          }
        }
      },
      onError: (error) => print('❌ SAHAr Position stream error: $error'),
    );

    _locationTimer = Timer.periodic(
      const Duration(seconds: _locationUpdateIntervalSeconds),
          (timer) async {
        try {
          Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );
          bool success = await sendLocationUpdate(position.latitude, position.longitude);
          if (success) lastSentLocation.value = position;
        } catch (e) {
          print('❌ SAHAr Timer location error: $e');
        }
      },
    );

    isLocationSending.value = true;

    // Send initial location
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      bool success = await sendLocationUpdate(position.latitude, position.longitude);
      if (success) lastSentLocation.value = position;
    } catch (e) {
      print('❌ SAHAr Initial location error: $e');
    }
  }

  /// Stop location updates
  void _stopLocationUpdates() {
    _locationTimer?.cancel();
    _locationTimer = null;
    _positionStream?.cancel();
    _positionStream = null;
    isLocationSending.value = false;
    print('⏹️ SAHAr Location updates stopped');
  }

  /// Pause location updates
  void _pauseLocationUpdates() {
    _positionStream?.pause();
  }

  /// Resume location updates
  void _resumeLocationUpdates() {
    if (_positionStream != null && _positionStream!.isPaused) {
      _positionStream!.resume();
    }
  }

  /// Request background permissions (Android 15+)
  Future<bool> requestBackgroundPermissions() async {
    try {
      var notificationStatus = await Permission.notification.request();

      try {
        await Permission.scheduleExactAlarm.request();
      } catch (e) {
        print('⚠️ SAHAr Exact alarm permission not available');
      }

      try {
        await Permission.ignoreBatteryOptimizations.request();
      } catch (e) {
        print('⚠️ SAHAr Battery optimization permission not available');
      }

      return notificationStatus.isGranted;
    } catch (e) {
      print('❌ SAHAr Permission error: $e');
      return false;
    }
  }

  /// Start background service
  Future<bool> startBackgroundService() async {
    if (isRunning.value) {
      print('⚠️ SAHAr Service already running');
      return true;
    }

    try {
      await requestBackgroundPermissions();
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'pickurides_tracking',
          channelName: 'PickuRides Location Tracking',
          channelDescription: 'Tracking your location for ride assignments',
          channelImportance: NotificationChannelImportance.LOW,
          priority: NotificationPriority.LOW,
        ),
        iosNotificationOptions: const IOSNotificationOptions(
          showNotification: true,
          playSound: false,
        ),
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.repeat(5000),
          autoRunOnBoot: false,
          allowWakeLock: true,
          allowWifiLock: true,
        ),
      );

      // Connect to SignalR
      bool connected = await _connect();
      if (!connected) {
        throw Exception('Failed to connect to server');
      }

      // Auto-subscribe with retry logic
      await _autoSubscribe();

      // Start location updates
      await _startLocationUpdates();

      // Start foreground service
      await FlutterForegroundTask.startService(
        notificationTitle: 'PickuRides',
        notificationText: "You're online and available for rides",
      );

      isRunning.value = true;
      print('✅ SAHAr Background service started');
      return true;
    } catch (e) {
      print('❌ SAHAr Start service error: $e');
      await stopBackgroundService();
      return false;
    }
  }

  /// Stop background service
  Future<void> stopBackgroundService() async {
    if (!isRunning.value) return;

    try {
      _stopReconnectionTimer();
      await _unsubscribeFromRideAssignments();
      _stopLocationUpdates();

      if (_hubConnection != null) {
        try {
          await _hubConnection!.stop();
          print('🔄 SAHAr SignalR connection stopped');
        } catch (e) {
          print('⚠️ SAHAr Error stopping SignalR connection: $e');
        }
        _hubConnection = null;
      }

      isConnected.value = false;
      isSubscribed.value = false;
      connectionStatus.value = 'Disconnected';

      await FlutterForegroundTask.stopService();
      isRunning.value = false;

      print('✅ SAHAr Background service stopped completely');
    } catch (e) {
      print('❌ SAHAr Stop service error: $e');

      // Force reset all states even if there were errors
      isRunning.value = false;
      isConnected.value = false;
      isSubscribed.value = false;
      connectionStatus.value = 'Disconnected';
      _hubConnection = null;
    }
  }

  /// Update foreground notification
  Future<void> updateNotification({String? title, String? text}) async {
    if (isRunning.value) {
      await FlutterForegroundTask.updateService(
        notificationTitle: title ?? 'PickuRides',
        notificationText: text ?? "You're online and available for rides",
      );
    }
  }

  /// Get service info
  Map<String, dynamic> getServiceInfo() {
    return {
      'isRunning': isRunning.value,
      'isConnected': isConnected.value,
      'connectionStatus': connectionStatus.value,
      'isSubscribed': isSubscribed.value,
      'currentRideId': currentRideId.value,
      'rideStatus': rideStatus.value,
      'isLocationSending': isLocationSending.value,
      'locationUpdateCount': locationUpdateCount.value,
      'driverId': _driverId,
      'driverName': _driverName,
      'customMarkersLoaded': _currentLocationIcon != null,
      'lastLocation': lastSentLocation.value != null
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
    stopBackgroundService();
    _stopReconnectionTimer();
    super.onClose();
  }
}