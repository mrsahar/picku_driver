import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pick_u_driver/core/google_directions_service.dart';
import 'package:pick_u_driver/core/location_service.dart';
import 'package:pick_u_driver/core/sharePref.dart';
import 'package:pick_u_driver/core/signalr_service.dart';
import 'package:pick_u_driver/models/ride_assignment_model.dart';
import 'package:signalr_core/signalr_core.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import '../driver_screen/main_screen/ride_widgets/payment_completion_dialog.dart';
import 'map_service.dart';

// Updated RideAssignmentService with Android 15 support and proper integration
class RideAssignmentService extends GetxService {
  static RideAssignmentService get to => Get.find();

  // Services
  final SignalRService _signalRService = SignalRService.to;
  final LocationService _locationService = LocationService.to;
  final MapService _mapService = MapService.to;

  // SignalR connection
  HubConnection? _hubConnection;

  // Observable variables
  var isSubscribed = false.obs;
  var connectionStatus = 'Disconnected'.obs;
  var currentRide = Rxn<RideAssignment>();
  var rideStatus = 'No Active Ride'.obs;
  var routePolylines = <Polyline>{}.obs;
  var rideMarkers = <Marker>{}.obs;

  // Driver info
  String? _driverId;
  String? _driverName;

  // Background service flag for Android 15+
  bool _isBackgroundServiceEnabled = false;

  // Reconnection timer
  Timer? _reconnectionTimer;

  @override
  void onInit() {
    super.onInit();
    _initializeService();
  }

  Future<void> _initializeService() async {
    print(' SAHAr Initializing RideAssignmentService...');
    await _loadDriverInfo();
    await _initializeConnection();
    await _autoSubscribe();
  }

  // Request permissions for Android 15+
  Future<bool> _requestBackgroundPermissions() async {
    try {
      // Request notification permission for background updates
      var notificationStatus = await Permission.notification.request();
      print(' SAHAr Notification permission: ${notificationStatus}');

      // Request exact alarm permission for scheduled tasks (if available)
      try {
        var alarmStatus = await Permission.scheduleExactAlarm.request();
        print(' SAHAr Exact alarm permission: ${alarmStatus}');
      } catch (e) {
        print(' SAHAr Exact alarm permission not available: $e');
      }

      // Request battery optimization exemption (if available)
      try {
        var batteryStatus = await Permission.ignoreBatteryOptimizations.request();
        print(' SAHAr Battery optimization permission: ${batteryStatus}');
      } catch (e) {
        print(' SAHAr Battery optimization permission not available: $e');
      }

      // Show user notification about background permissions
      if (notificationStatus.isGranted) {
        Get.snackbar(
          'Background Service Ready',
          'App can receive ride notifications in background',
          backgroundColor: Colors.green.shade100,
          colorText: Colors.green.shade800,
          duration: const Duration(seconds: 3),
        );
      } else {
        Get.snackbar(
          'Background Permissions',
          'Enable notifications to receive ride requests in background',
          backgroundColor: Colors.orange.shade100,
          colorText: Colors.orange.shade800,
          duration: const Duration(seconds: 5),
        );
      }

      return notificationStatus.isGranted;
    } catch (e) {
      print(' SAHAr Error requesting background permissions: $e');
      return false;
    }
  }

  // Load driver information
  Future<void> _loadDriverInfo() async {
    try {
      _driverId = await SharedPrefsService.getUserId();
      _driverName = await SharedPrefsService.getUserFullName();
      print(' SAHAr Driver loaded for ride assignments: $_driverName ($_driverId)');

      if (_driverId == null || _driverName == null) {
        print(' SAHAr Warning: Driver information not available');
        Get.snackbar(
          'Driver Info Missing',
          'Please logout and login again to enable ride assignments',
          backgroundColor: Colors.orange.shade100,
          colorText: Colors.orange.shade800,
        );
      }
    } catch (e) {
      print(' SAHAr Error loading driver info: $e');
    }
  }

  // Initialize SignalR connection
  Future<void> _initializeConnection() async {
    try {
      _hubConnection = HubConnectionBuilder()
          .withUrl('http://pickurides.com/ridehub')
          .withAutomaticReconnect([2000, 5000, 10000, 15000, 30000])
          .build();

      _setupConnectionHandlers();
      await _connect();
    } catch (e) {
      print(' SAHAr Error initializing ride assignment SignalR: $e');
      connectionStatus.value = 'Error: $e';
    }
  }

  // Set up SignalR event handlers
  void _setupConnectionHandlers() {
    if (_hubConnection == null) return;

    // Connection state handlers
    _hubConnection!.onclose((error) {
      print(' SAHAr Ride assignment hub disconnected: $error');
      isSubscribed.value = false;
      connectionStatus.value = 'Disconnected';

      // Start reconnection timer
      _startReconnectionTimer();
    });

    _hubConnection!.onreconnecting((error) {
      print(' SAHAr Ride hub reconnecting: $error');
      connectionStatus.value = 'Reconnecting...';
    });

    _hubConnection!.onreconnected((connectionId) {
      print(' SAHAr Ride hub reconnected: $connectionId');
      connectionStatus.value = 'Connected';
      _stopReconnectionTimer();

      // Re-subscribe after reconnection
      if (_driverId != null) {
        _subscribeToRideAssignments();
      }
    });

    // Listen for new ride assignments
    _hubConnection!.on('NewRideAssigned', (List<Object?>? arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        try {
          print(' SAHAr Raw ride data received: ${arguments[0]}');
          final rideData = arguments[0] as Map<String, dynamic>;
          _handleNewRideAssignment(rideData);
        } catch (e) {
          print(' SAHAr Error parsing ride assignment: $e');
        }
      }
    });

    // Listen for ride status updates
    _hubConnection!.on('RideStatusUpdate', (List<Object?>? arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        try {
          final statusUpdate = arguments[0] as Map<String, dynamic>;
          _handleRideStatusUpdate(statusUpdate);
        } catch (e) {
          print(' SAHAr Error parsing status update: $e');
        }
      }
    });
  }

  // Start reconnection timer
  void _startReconnectionTimer() {
    _stopReconnectionTimer(); // Stop any existing timer

    _reconnectionTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (connectionStatus.value == 'Disconnected') {
        print(' SAHAr Attempting automatic reconnection...');
        _connect();
      } else {
        _stopReconnectionTimer();
      }
    });
  }

  // Stop reconnection timer
  void _stopReconnectionTimer() {
    if (_reconnectionTimer != null) {
      _reconnectionTimer!.cancel();
      _reconnectionTimer = null;
    }
  }

  // Connect to SignalR hub
  Future<bool> _connect() async {
    if (_hubConnection == null) return false;

    try {
      connectionStatus.value = 'Connecting...';
      await _hubConnection!.start();
      connectionStatus.value = 'Connected';
      print(' SAHAr Connected to ride assignment hub');
      return true;
    } catch (e) {
      print(' SAHAr Failed to connect to ride hub: $e');
      connectionStatus.value = 'Connection failed';
      return false;
    }
  }

  // Auto-subscribe when driver opens the app
  Future<void> _autoSubscribe() async {
    if (_driverId == null) {
      print(' SAHAr Cannot auto-subscribe: Driver ID not available');
      return;
    }

    // Wait for connection
    int retries = 0;
    while (connectionStatus.value != 'Connected' && retries < 10) {
      await Future.delayed(const Duration(seconds: 1));
      retries++;
    }

    if (connectionStatus.value == 'Connected') {
      await _subscribeToRideAssignments();
    } else {
      print(' SAHAr Could not auto-subscribe - connection failed');
    }
  }

  // Subscribe to ride assignments
  Future<void> _subscribeToRideAssignments() async {
    if (_hubConnection == null || _driverId == null) return;

    try {
      await _hubConnection!.invoke('SubscribeDriver', args: [_driverId]);
      isSubscribed.value = true;
      print(' SAHAr Subscribed to ride assignments for driver: $_driverId');

      Get.snackbar(
        'Ready for Rides',
        'You are now subscribed to receive ride assignments',
        backgroundColor: Colors.green.shade100,
        colorText: Colors.green.shade800,
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      print(' SAHAr Error subscribing to rides: $e');
      Get.snackbar(
        'Subscription Error',
        'Failed to subscribe to ride assignments: $e',
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade800,
      );
    }
  }

  // Handle new ride assignment
  void _handleNewRideAssignment(Map<String, dynamic> rideData) {
    try {
      final ride = RideAssignment.fromJson(rideData);
      currentRide.value = ride;
      rideStatus.value = ride.status;

      // IMPORTANT: Pass ride ID to SignalRService
      _signalRService.currentRideId.value = ride.rideId;
      print(' SAHAr Ride ID passed to SignalRService: ${ride.rideId}');

      // Show notification
      _showRideNotification(ride);

      // Update UI based on status
      _updateUIForRideStatus(ride);

      print(' SAHAr New ride assigned: ${ride.rideId} - Status: ${ride.status}');
    } catch (e) {
      print(' SAHAr Error handling ride assignment: $e');
    }
  }

  // Handle ride status updates
  void _handleRideStatusUpdate(Map<String, dynamic> statusData) {
    try {
      final ride = RideAssignment.fromJson(statusData);
      currentRide.value = ride;
      rideStatus.value = ride.status;

      // Update SignalRService ride ID
      _signalRService.currentRideId.value = ride.rideId;

      _updateUIForRideStatus(ride);

      print(' SAHAr Ride status updated: ${ride.rideId} - Status: ${ride.status}');
    } catch (e) {
      print(' SAHAr Error handling status update: $e');
    }
  }

  // Show ride notification
  void _showRideNotification(RideAssignment ride) {
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
        title = 'Ride Completed';
        message = 'Fare: \$${ride.fareEstimate.toStringAsFixed(2)}';
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

  // Update UI based on ride status
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

  // Show route to pickup location
  Future<void> _showRouteToPickup(RideAssignment ride) async {
    try {
      // Get current location
      await _locationService.getCurrentLocation();

      if (_locationService.currentLatLng.value == null) {
        print(' SAHAr Cannot show route - current location not available');
        return;
      }

      final origin = _locationService.currentLatLng.value!;
      final pickup = LatLng(ride.pickUpLat, ride.pickUpLon);

      print(' SAHAr Showing route from $origin to $pickup');

      // Get route from Google Directions
      final points = await GoogleDirectionsService.getRoutePoints(
        origin: origin,
        destination: pickup,
      );

      // Create polyline
      final polyline = Polyline(
        polylineId: const PolylineId('route_to_pickup'),
        points: points,
        color: Colors.orange,
        width: 5,
        patterns: [], // Solid line
      );

      routePolylines.value = {polyline};

      // Create markers
      final markers = <Marker>{
        Marker(
          markerId: const MarkerId('current_location'),
          position: origin,
          infoWindow: const InfoWindow(title: 'Your Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
        Marker(
          markerId: const MarkerId('pickup'),
          position: pickup,
          infoWindow: InfoWindow(title: 'Pickup', snippet: ride.pickupLocation),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      };

      rideMarkers.value = markers;
      print(' SAHAr Route to pickup displayed');
    } catch (e) {
      print(' SAHAr Error showing route to pickup: $e');
    }
  }

  // Show route to all stops
  Future<void> _showRouteToAllStops(RideAssignment ride) async {
    try {
      // Get current location
      await _locationService.getCurrentLocation();

      if (_locationService.currentLatLng.value == null) {
        print(' SAHAr Cannot show route - current location not available');
        return;
      }

      final origin = _locationService.currentLatLng.value!;

      // Create waypoints from stops
      final waypoints = ride.stops
          .map((stop) => LatLng(stop.latitude, stop.longitude))
          .toList();

      if (waypoints.isEmpty) {
        print(' SAHAr No stops available for route');
        return;
      }

      print(' SAHAr Showing route with ${waypoints.length} stops');

      // Get route with all stops
      final points = await GoogleDirectionsService.getRoutePoints(
        origin: origin,
        destination: waypoints.last,
        waypoints: waypoints.length > 1 ? waypoints.sublist(0, waypoints.length - 1) : null,
      );

      // Create polyline
      final polyline = Polyline(
        polylineId: const PolylineId('route_with_stops'),
        points: points,
        color: Colors.blue,
        width: 5,
        patterns: [], // Solid line
      );

      routePolylines.value = {polyline};

      // Create markers for all stops
      final markers = <Marker>{
        Marker(
          markerId: const MarkerId('current_location'),
          position: origin,
          infoWindow: const InfoWindow(title: 'Your Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      };

      // Add markers for each stop
      for (var stop in ride.stops) {
        markers.add(
          Marker(
            markerId: MarkerId('stop_${stop.stopOrder}'),
            position: LatLng(stop.latitude, stop.longitude),
            infoWindow: InfoWindow(
              title: stop.stopOrder == ride.stops.length - 1 ? 'Destination' : 'Stop ${stop.stopOrder + 1}',
              snippet: stop.location,
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              stop.stopOrder == ride.stops.length - 1
                  ? BitmapDescriptor.hueRed
                  : BitmapDescriptor.hueOrange,
            ),
          ),
        );
      }

      rideMarkers.value = markers;
      print(' SAHAr Route with all stops displayed');
    } catch (e) {
      print(' SAHAr Error showing route with stops: $e');
    }
  }

  // Show completed ride
  void _showCompletedRide(RideAssignment ride) {
    print(' SAHAr Showing completed ride dialog');

    // Clear route and markers
    routePolylines.value = {};
    rideMarkers.value = {};

    // Show payment dialog
    Get.dialog(
      PaymentCompletionDialog(
        ride: ride,
        onPaymentReceived: () {
          _resetRide();
          Get.back();
        },
      ),
      barrierDismissible: false,
    );
  }

  // Reset ride state
  void _resetRide() {
    print(' SAHAr Resetting ride state');

    currentRide.value = null;
    rideStatus.value = 'No Active Ride';
    routePolylines.value = {};
    rideMarkers.value = {};

    // Clear ride ID from SignalRService
    _signalRService.currentRideId.value = '';

    Get.snackbar(
      'Ready for Next Ride',
      'You can now receive new ride assignments',
      backgroundColor: Colors.blue.shade100,
      colorText: Colors.blue.shade800,
      duration: const Duration(seconds: 3),
    );
  }

  // Unsubscribe from ride assignments
  Future<void> unsubscribe() async {
    if (_hubConnection == null || _driverId == null) return;

    try {
      await _hubConnection!.invoke('UnsubscribeDriver', args: [_driverId]);
      isSubscribed.value = false;
      print(' SAHAr Unsubscribed from ride assignments');

      // Clear current ride data
      _resetRide();
    } catch (e) {
      print(' SAHAr Error unsubscribing: $e');
    }
  }

  // Manual reconnect
  Future<void> reconnect() async {
    print(' SAHAr Manual reconnect requested');
    await _connect();

    if (connectionStatus.value == 'Connected' && _driverId != null) {
      await _subscribeToRideAssignments();
    }
  }

  // Get connection status for debugging
  Map<String, dynamic> getConnectionInfo() {
    return {
      'isSubscribed': isSubscribed.value,
      'connectionStatus': connectionStatus.value,
      'currentRideId': currentRide.value?.rideId,
      'rideStatus': rideStatus.value,
      'driverId': _driverId,
      'driverName': _driverName,
      'backgroundServiceEnabled': _isBackgroundServiceEnabled,
      'hubUrl': 'http://pickurides.com/ridehub',
    };
  }

  @override
  void onClose() {
    print(' SAHAr Disposing RideAssignmentService');

    _stopReconnectionTimer();
    unsubscribe();
    _hubConnection?.stop();
    super.onClose();
  }
}