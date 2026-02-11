import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pick_u_driver/controllers/active_ride_controller.dart';
import 'package:pick_u_driver/core/google_directions_service.dart';
import 'package:pick_u_driver/core/location_service.dart';
import 'package:pick_u_driver/core/sharePref.dart';
import 'package:pick_u_driver/core/global_variables.dart';
import 'package:pick_u_driver/core/ride_notification_service.dart';
import 'package:pick_u_driver/core/notification_sound_service.dart';
import 'package:pick_u_driver/core/internet_connectivity_service.dart';
import 'package:pick_u_driver/driver_screen/widget/modern_payment_dialog.dart';
import 'package:pick_u_driver/models/ride_assignment_model.dart'; 
import 'package:pick_u_driver/routes/app_routes.dart';
import 'package:signalr_core/signalr_core.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pick_u_driver/utils/theme/mcolors.dart';
import 'package:pick_u_driver/core/map_service.dart';
import 'package:pick_u_driver/core/database_helper.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class BackgroundTrackingService extends GetxService {
  static BackgroundTrackingService get to => Get.find();

  // Services - lazy loaded to avoid initialization errors
  LocationService? get _locationService {
    try {
      return Get.isRegistered<LocationService>()
          ? LocationService.to
          : null;
    } catch (e) {
      return null;
    }
  }

  // Get ride notification service
  RideNotificationService? get _rideNotificationService {
    try {
      return Get.isRegistered<RideNotificationService>()
          ? RideNotificationService.to
          : null;
    } catch (e) {
      return null;
    }
  }

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
  // ⚠️ DEPRECATED: routePolylines - Now using MapService.polylines as Single Source of Truth
  // var routePolylines = <Polyline>{}.obs;
  var rideMarkers = <Marker>{}.obs;

  // Driver info
  String? _driverId;
  String? _driverName;

  // Timers and streams
  StreamSubscription<Position>? _positionStream;
  Timer? _reconnectionTimer;
  StreamSubscription<bool>? _connectivitySubscription;

  // Route update throttling
  DateTime? _lastRouteUpdateTime;
  LatLng? _lastRouteUpdatePosition;
  static const double _routeUpdateDistanceThreshold = 50.0; // meters
  static const Duration _routeUpdateTimeThreshold = Duration(seconds: 10); // ✅ Update every 10 seconds (like Uber)
  
  // Prevent concurrent route updates
  bool _isUpdatingRoute = false;
  
  // Track last connectivity state to detect changes
  bool _wasConnectedToInternet = true;

  // Connection/subscription state guards
  bool _isConnecting = false;
  bool _isSubscribing = false;

  // Marker update debouncing
  Timer? _markerUpdateDebounce;
  Position? _pendingMarkerUpdate;

  // WakeLock management
  bool _isWakeLockEnabled = false;
  // Configuration
  static const String _hubUrl = 'https://api.pickurides.com/ridechathub/';
  static const String _emptyGuid = '00000000-0000-0000-0000-000000000000';
  static const double _minimumDistanceFilter = 2.0; // meters

  // Custom marker icons (driver/taxi marker is handled by MapService)
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
    _setupConnectivityListener();
  }

  /// Setup listener for internet connectivity changes
  void _setupConnectivityListener() {
    try {
      if (!Get.isRegistered<InternetConnectivityService>()) {
        print('⚠️ SAHAr InternetConnectivityService not registered yet in BackgroundTrackingService');
        return;
      }

      final connectivityService = InternetConnectivityService.to;
      
      // Listen to connectivity changes
      _connectivitySubscription = connectivityService.isConnected.listen((isConnected) {
        print('🌐 SAHAr [BG] Internet connectivity changed: $isConnected');
        _handleConnectivityChange(isConnected);
      });

      print('✅ SAHAr [BG] Connectivity listener setup complete');
    } catch (e) {
      print('❌ SAHAr [BG] Error setting up connectivity listener: $e');
    }
  }

  /// Handle internet connectivity changes
  void _handleConnectivityChange(bool isConnectedToInternet) {
    // Internet connection restored
    if (isConnectedToInternet && !_wasConnectedToInternet) {
      print('🟢 SAHAr [BG] Internet restored');
      _onInternetRestored();
    } 
    // Internet connection lost
    else if (!isConnectedToInternet && _wasConnectedToInternet) {
      print('🔴 SAHAr [BG] Internet lost');
      _onInternetLost();
    }

    _wasConnectedToInternet = isConnectedToInternet;
  }

  /// Handle internet connection restored
  Future<void> _onInternetRestored() async {
    try {
      print('🔄 SAHAr [BG] Internet restored, reconnecting...');

      // 1. Ensure SignalR connection + subscription in a single idempotent flow
      await _ensureConnectedAndSubscribed();

      // 2. Resume location updates if active
      if (isLocationSending.value) {
        _resumeLocationUpdates();
      }

      // 3. Recalculate route if we have an active ride
      if (currentRide.value != null && _locationService?.currentLatLng.value != null) {
        print('🗺️ SAHAr [BG] Recalculating route after internet restoration');
        await _recalculateRoute();
      }

      // 4. Sync any offline data
      _syncOfflineData();

    } catch (e) {
      print('❌ SAHAr [BG] Error handling internet restoration: $e');
    }
  }

  /// Handle internet connection lost
  void _onInternetLost() {
    print('⏸️ SAHAr [BG] Internet lost, will buffer location updates');
    // Location tracking continues, SignalR will buffer/retry automatically
    // We just log this event for debugging
  }

  /// Recalculate route from current position
  Future<void> _recalculateRoute() async {
    if (_isUpdatingRoute) {
      print('⏸️ SAHAr Route recalculation already in progress');
      return;
    }

    final ride = currentRide.value;
    if (ride == null) return;

    try {
      _isUpdatingRoute = true;
      
      // Reset route update tracking so it updates immediately
      _lastRouteUpdatePosition = null;
      _lastRouteUpdateTime = null;

      // Trigger route update based on current ride status
      if (ride.status == 'Waiting') {
        await _showRouteToPickup(ride);
      } else if (ride.status == 'In-Progress') {
        await _showRouteToAllStops(ride);
      }

      print('✅ SAHAr Route recalculated after internet restoration');
    } catch (e) {
      print('❌ SAHAr Error recalculating route: $e');
    } finally {
      _isUpdatingRoute = false;
    }
  }

  /// Load custom marker icons
  Future<void> _loadCustomMarkers() async {
    try {
      // Note: Taxi marker is handled by MapService, we only load point markers here
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

      print('✅ SAHAr Custom point markers loaded');
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

  /// Initialize SignalR connection with JWT authentication
  Future<void> _initializeConnection() async {
    try {
      // Get JWT token from GlobalVariables
      final jwtToken = GlobalVariables.instance.userToken;

      if (jwtToken.isEmpty) {
        print('⚠️ SAHAr No JWT token available for SignalR connection');
        connectionStatus.value = 'No token available';
        throw Exception('JWT token is required for SignalR connection');
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
      rethrow; // Propagate the error so startBackgroundService can handle it
    }
  }

  /// Resume an active ride with the provided ride data
  /// First connects all services, then resumes the ride
  Future<void> resumeActiveRide(RideAssignment activeRide) async {
    try {
      print('🔄 SAHAr Resuming active ride: ${activeRide.rideId}');
      print('🔄 SAHAr Step 1: Connecting services first...');

      // ============================================================
      // STEP 1: Connect all services FIRST (SignalR, Tracking, etc.)
      // ============================================================
      
      // 1. Start location tracking if not already running
      if (!isRunning.value) {
        print('🔄 SAHAr Starting background tracking service...');
        await startTracking();
        print('✅ SAHAr Background tracking service started');
      } else {
        print('✅ SAHAr Background tracking already running');
      }

      // 2. Connect to SignalR if not connected
      if (!isConnected.value) {
        print('🔄 SAHAr Connecting to SignalR hub...');
        await connectToHub();
        
        // Wait a bit for connection to stabilize
        int retries = 0;
        while (!isConnected.value && retries < 5) {
          await Future.delayed(const Duration(milliseconds: 500));
          retries++;
        }
        
        if (isConnected.value) {
          print('✅ SAHAr Connected to SignalR hub');
        } else {
          print('⚠️ SAHAr SignalR connection pending, continuing anyway');
        }
      } else {
        print('✅ SAHAr SignalR already connected');
      }

      // 3. Wait for location service to be ready
      if (_locationService != null) {
        print('🔄 SAHAr Getting current location...');
        await _locationService!.getCurrentLocation();
        
        // Wait for location to be available
        int retries = 0;
        while (_locationService!.currentLatLng.value == null && retries < 5) {
          await Future.delayed(const Duration(milliseconds: 500));
          await _locationService!.getCurrentLocation();
          retries++;
        }
        
        if (_locationService!.currentLatLng.value != null) {
          print('✅ SAHAr Current location obtained');
        } else {
          print('⚠️ SAHAr Location not available yet, continuing anyway');
        }
      }

      print('✅ SAHAr All services connected!');
      print('🔄 SAHAr Step 2: Setting up ride data...');

      // ============================================================
      // STEP 2: Now set up the ride data (after everything is connected)
      // ============================================================
      
      // Set current ride information
      currentRideId.value = activeRide.rideId;
      // Set rideStatus to actual status (not "Resuming...") so route drawing works
      rideStatus.value = activeRide.status;

      // Create RideAssignment from DriverLastRideModel
      final rideAssignment = RideAssignment(
        rideId: activeRide.rideId,
        rideType: activeRide.rideType,
        fareEstimate: activeRide.fareEstimate,
        fareFinal: activeRide.fareFinal,
        createdAt: activeRide.createdAt,
        status: activeRide.status,
        passengerId: activeRide.passengerId,
        passengerName: activeRide.passengerName,
        passengerPhone: activeRide.passengerPhone,
        pickupLocation: activeRide.pickupLocation,
        pickUpLat: activeRide.pickUpLat,
        pickUpLon: activeRide.pickUpLon,
        dropoffLocation: activeRide.dropoffLocation,
        dropoffLat: activeRide.dropoffLat,
        dropoffLon: activeRide.dropoffLon,
        stops: activeRide.stops.map((rs) => RideStop(
          stopOrder: rs.stopOrder,
          location: rs.location,
          latitude: rs.latitude,
          longitude: rs.longitude,  
        )).toList(),
        passengerCount: activeRide.passengerCount,
        payment: activeRide.payment,
        tip: activeRide.tip,
      );

      currentRide.value = rideAssignment;

      // Update markers
      _updateMarkersForActiveRide(activeRide);

      // Draw route based on ride status (this will show polylines)
      print('🔄 SAHAr Step 3: Drawing route...');
      _updateUIForRideStatus(rideAssignment);

      print('✅ SAHAr Active ride resumed successfully - All services connected and ride set up!');
      
    } catch (e, stackTrace) {
      // Log critical errors
      print('❌ SAHAr Critical error resuming active ride: $e');
      print('❌ SAHAr Stack trace: $stackTrace');
      // Re-throw so controller can handle it
      rethrow;
    }
  }

  /// Update markers for the active ride
  void _updateMarkersForActiveRide(RideAssignment activeRide) {
    try {
      Set<Marker> markers = {};

      // Add pickup marker if available
      if (activeRide.stops.isNotEmpty) {
        final pickup = activeRide.stops.first;
        markers.add(
          Marker(
            markerId: const MarkerId('pickup'),
            position: LatLng(pickup.latitude, pickup.longitude),
            icon: _pickupIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            infoWindow: InfoWindow(
              title: 'Pickup Location',
              snippet: pickup.location,
            ),
          ),
        );
      }

      // Add destination marker if available
      if (activeRide.stops.length > 1) {
        final destination = activeRide.stops.last;
        markers.add(
          Marker(
            markerId: const MarkerId('destination'),
            position: LatLng(destination.latitude, destination.longitude),
            icon: _destinationIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
            infoWindow: InfoWindow(
              title: 'Destination',
              snippet: destination.location,
            ),
          ),
        );
      }

      // Add intermediate stops if any
      for (int i = 1; i < activeRide.stops.length - 1; i++) {
        final stop = activeRide.stops[i];
        markers.add(
          Marker(
            markerId: MarkerId('stop_$i'),
            position: LatLng(stop.latitude, stop.longitude),
            icon: _stopIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
            infoWindow: InfoWindow(
              title: 'Stop $i',
              snippet: stop.location,
            ),
          ),
        );
      }

      rideMarkers.assignAll(markers);
      print('✅ SAHAr Updated markers for active ride: ${markers.length} markers');
    } catch (e) {
      print('❌ SAHAr Error updating markers for active ride: $e');
    }
  }

  void showPaymentSuccessPopup({required double fareFinal, required double tip}) {
    final bool hasTip = tip > 0;
    final double total = fareFinal + tip;

    Get.dialog(
      PopScope(
        canPop: false,
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Success Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha:0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    size: 50,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  'Payment Received!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: MColor.primaryNavy,
                  ),
                ),
                const SizedBox(height: 8),

                // Subtitle
                Text(
                  'Payment has been successfully completed',
                  style: TextStyle(
                    fontSize: 14,
                    color: MColor.primaryNavy.withValues(alpha:0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Payment Details
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: MColor.primaryNavy.withValues(alpha:0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: MColor.primaryNavy.withValues(alpha:0.1),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Fare
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Ride Fare',
                            style: TextStyle(
                              fontSize: 14,
                              color: MColor.primaryNavy.withValues(alpha:0.7),
                            ),
                          ),
                          Text(
                            '\$${fareFinal.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: MColor.primaryNavy,
                            ),
                          ),
                        ],
                      ),

                      // Tip (if exists)
                      if (hasTip) ...[
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.star,
                                  size: 16,
                                  color: Colors.amber.shade700,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Tip',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: MColor.primaryNavy.withValues(alpha:0.7),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '\$${tip.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Divider(
                          color: MColor.primaryNavy.withValues(alpha:0.1),
                          height: 1,
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Total
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Earning',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: MColor.primaryNavy,
                            ),
                          ),
                          Text(
                            '\$${total.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: MColor.primaryNavy,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    // OK Button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Get.back(); // Close popup
                          _resetRide(); // Clear everything
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MColor.primaryNavy,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'OK',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // View Earnings Button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Get.back(); // Close popup
                          _resetRide(); // Clear everything
                          Get.toNamed(AppRoutes.EarningSCREEN); // Navigate to earnings
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MColor.primaryNavy,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'View Earnings',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      barrierDismissible: false,
    );
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

      // Initialize ActiveRideController after successful reconnection
      _initializeActiveRideController();

      // Sync offline data after reconnection
      _syncOfflineData();

      // Re-subscribe to ride assignments (idempotent unified flow)
      if (_driverId != null) {
        _ensureConnectedAndSubscribed();
      }
    });

    // ===== RIDE ASSIGNMENT EVENTS =====
    _hubConnection!.on('NewRideAssigned', (List<Object?>? arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        try {
          print('🚕 SAHAr New ride assigned!');
          final rideData = arguments[0] as Map<String, dynamic>;
          _playNotificationSound();
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
          _playNotificationSound();
        }
      }
    });
// Update the PaymentCompleted handler in BackgroundTrackingService
// Replace the existing handler with this:

    _hubConnection!.on('PaymentCompleted', (List<Object?>? arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        try {
          final paymentData = arguments[0] as Map<String, dynamic>;
          String rideId = paymentData['rideId']?.toString() ?? '';

          print('💰 SAHAr Payment data received: $paymentData'); 

          // Update the current ride with payment info
          if (currentRide.value != null && currentRide.value!.rideId == rideId) {
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
              'fareEstimate': currentRide.value!.fareEstimate,
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

            // Update ride with payment info
            currentRide.value = RideAssignment.fromJson(updatedRideData);
            paymentCompleted.value = true;
            isWaitingForPayment.value = false;

            print('💰 SAHAr ✅ Ride updated successfully!');
            print('   - Payment: ${currentRide.value!.payment}');
            print('   - Tip: \$${currentRide.value!.tip?.toStringAsFixed(2) ?? "0.00"}');
            print('   - FareFinal: \$${currentRide.value!.fareFinal.toStringAsFixed(2)}');

            // Clear all UI elements before showing payment popup
            _clearAllUIBeforePaymentPopup();

            // Show payment success popup after clearing UI
            Future.delayed(const Duration(milliseconds: 300), () {
              showPaymentSuccessPopup(
                fareFinal: currentRide.value!.fareFinal,
                tip: currentRide.value!.tip ?? 0,
              );
            });

            print('💰 SAHAr Payment popup shown');
          } else {
            print('⚠️ SAHAr Cannot update payment - no current ride or ride ID mismatch');
          }
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


  /// Initialize ActiveRideController after successful connection
  void _initializeActiveRideController() {
    try {
      // Check if ActiveRideController is already registered
      if (!Get.isRegistered<ActiveRideController>()) {
        print('🎯 SAHAr Initializing ActiveRideController after connection');
        Get.put(ActiveRideController(), permanent: true);
        print('✅ SAHAr ActiveRideController initialized successfully');
      } else {
        print('ℹ️ SAHAr ActiveRideController already registered');
      }
    } catch (e) {
      print('❌ SAHAr Error initializing ActiveRideController: $e');
    }
  }

  /// Start reconnection timer
  void _startReconnectionTimer() {
    _stopReconnectionTimer();
    _reconnectionTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!isConnected.value) {
        print('🔄 SAHAr Attempting reconnection...');
        // Use unified connection/subscription flow so we don't create
        // duplicate connections or subscriptions.
        _ensureConnectedAndSubscribed();
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
    // Prevent overlapping connect attempts
    if (_isConnecting) {
      print('⏳ SAHAr Connect requested while another connect is in progress. Skipping.');
      return false;
    }

    _isConnecting = true;
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

    if (_hubConnection == null) {
      _isConnecting = false;
      return false;
    }

    try {
      // Log current internet connectivity alongside hub state
      bool internetOk = true;
      String connectionType = 'unknown';
      if (Get.isRegistered<InternetConnectivityService>()) {
        final svc = InternetConnectivityService.to;
        internetOk = svc.isConnected.value;
        connectionType = svc.connectionType.value;
      }
      print('🌐 SAHAr Attempting hub start - internetOk=$internetOk, type=$connectionType');

      connectionStatus.value = 'Connecting...';
      await _hubConnection!.start();
      isConnected.value = true;
      connectionStatus.value = 'Connected';
      print('✅ SAHAr Connected to hub');

      // Initialize ActiveRideController after successful connection
      _initializeActiveRideController();

      // Sync offline data after successful connection
      _syncOfflineData();

      return true;
    } catch (e) {
      print('❌ SAHAr Connection failed: $e');
      connectionStatus.value = 'Failed';
      _hubConnection = null;
      return false;
    } finally {
      _isConnecting = false;
    }
  }

  /// Auto-subscribe helper (expects connection to be ready).
  /// This no longer manages its own long-running retry timers; callers
  /// should use [_ensureConnectedAndSubscribed] for a full flow.
  Future<void> _autoSubscribe() async {
    if (_driverId == null || _driverId!.isEmpty) {
      print('❌ SAHAr Cannot auto-subscribe: Driver ID not available');
      return;
    }

    if (!isConnected.value || _hubConnection == null) {
      print('⚠️ SAHAr Auto-subscribe skipped: hub not connected');
      return;
    }

    if (isSubscribed.value) {
      print('ℹ️ SAHAr Auto-subscribe skipped: already subscribed');
      return;
    }

    await _subscribeToRideAssignments();
  }

  /// Subscribe to ride assignments
  Future<void> _subscribeToRideAssignments() async {
    if (_hubConnection == null || _driverId == null) {
      print('⚠️ SAHAr Cannot subscribe: hubConnection or driverId is null');
      return;
    }

    if (isSubscribed.value) {
      print('ℹ️ SAHAr Already subscribed, skipping SubscribeDriver invoke');
      return;
    }

    if (_isSubscribing) {
      print('⏳ SAHAr Subscription already in progress, skipping new request');
      return;
    }

    _isSubscribing = true;
    try {
      print('🔔 SAHAr Invoking SubscribeDriver for driverId=$_driverId');
      await _hubConnection!.invoke('SubscribeDriver', args: [_driverId]);
      isSubscribed.value = true;
      print('✅ SAHAr Subscribed to rides for: $_driverId');
    } catch (e) {
      print('❌ SAHAr Subscription error: $e');
    } finally {
      _isSubscribing = false;
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

  /// Ensure that the hub is connected and the driver is subscribed.
  /// This method is idempotent and guarded against concurrent executions.
  Future<void> _ensureConnectedAndSubscribed() async {
    // Make sure we have a driverId
    if (_driverId == null || _driverId!.isEmpty) {
      print('⚠️ SAHAr _ensureConnectedAndSubscribed: driverId missing, reloading...');
      await _loadDriverInfo();
      if (_driverId == null || _driverId!.isEmpty) {
        print('❌ SAHAr _ensureConnectedAndSubscribed: driverId still missing, aborting');
        return;
      }
    }

    // Avoid overlapping flows
    if (_isConnecting || _isSubscribing) {
      print('⏳ SAHAr _ensureConnectedAndSubscribed already in progress, skipping');
      return;
    }

    // STEP 1: Ensure connection
    if (!isConnected.value || _hubConnection == null || _hubConnection!.state == HubConnectionState.disconnected) {
      final connected = await _connect();
      if (!connected) {
        print('❌ SAHAr _ensureConnectedAndSubscribed: connect() failed');
        return;
      }
    } else {
      print('ℹ️ SAHAr _ensureConnectedAndSubscribed: hub already connected');
    }

    // STEP 2: Ensure subscription
    if (!isSubscribed.value) {
      await _autoSubscribe();
    } else {
      print('ℹ️ SAHAr _ensureConnectedAndSubscribed: already subscribed');
    }
  }

  /// Handle new ride assignment
  void _handleNewRideAssignment(Map<String, dynamic> rideData) {
    try {
      final ride = RideAssignment.fromJson(rideData);
      currentRide.value = ride;
      rideStatus.value = ride.status;
      currentRideId.value = ride.rideId;

      //_showRideNotification(ride);
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

      // Check if this is a payment completion update
      final wasWaitingForPayment = isWaitingForPayment.value;
      final hasPaymentCompleted = ride.payment == 'Successful' && ride.status == 'Completed';

      print('🔄 SAHAr Status update received:');
      print('   - Status: ${ride.status}');
      print('   - Payment: ${ride.payment}');
      print('   - Was waiting: $wasWaitingForPayment');
      print('   - Payment completed: $hasPaymentCompleted');

      // Update current ride
      currentRide.value = ride;
      rideStatus.value = ride.status;
      currentRideId.value = ride.rideId;

      // If payment just completed while we were waiting
      if (wasWaitingForPayment && hasPaymentCompleted && showPaymentDialog.value) {
        print('💰 SAHAr Payment completed! Showing popup...');

        // Update payment flags
        paymentCompleted.value = true;
        isWaitingForPayment.value = false;

        // Close the bottom sheet first
        Get.back();

        // Show payment success popup
        showPaymentSuccessPopup(
          fareFinal: ride.fareFinal,
          tip: ride.tip ?? 0,
        );

        return; // Don't update UI for ride status
      }

      // Normal status update (not payment completion)
      _updateUIForRideStatus(ride);

      print('🔄 SAHAr Ride status: ${ride.status}');
    } catch (e) {
      print('❌ SAHAr Error handling status: $e');
    }
  }

  // void _showRideNotification(RideAssignment ride) {
  //   // Don't show notification if we're already handling payment completion
  //   if (ride.status == 'Completed' && ride.payment == 'Successful' && paymentCompleted.value) {
  //     print('🔕 SAHAr Skipping notification - payment already completed');
  //     return;
  //   }
  //
  //   String title = '';
  //   String message = '';
  //   Color bgColor = Colors.blue.shade100;
  //   Color textColor = Colors.blue.shade800;
  //   IconData icon = Icons.directions_car;
  //
  //   switch (ride.status) {
  //     case 'Waiting':
  //       title = 'New Ride Request!';
  //       message = 'Pickup: ${ride.pickupLocation}';
  //       bgColor = Colors.orange.shade100;
  //       textColor = Colors.orange.shade800;
  //       icon = Icons.schedule;
  //       break;
  //     case 'In-Progress':
  //       title = 'Ride Started';
  //       message = 'Heading to: ${ride.dropoffLocation}';
  //       bgColor = Colors.blue.shade100;
  //       textColor = Colors.blue.shade800;
  //       icon = Icons.directions_car;
  //       break;
  //     case 'Completed':
  //       // Only show notification if payment is not yet successful
  //       if (ride.payment != 'Successful') {
  //         title = 'Ride Completed';
  //         message = 'Waiting for payment...';
  //         bgColor = Colors.green.shade100;
  //         textColor = Colors.green.shade800;
  //         icon = Icons.check_circle;
  //       } else {
  //         // Payment is successful, don't show notification as popup will handle it
  //         return;
  //       }
  //       break;
  //   }
  //
  //   Get.snackbar(
  //     title,
  //     message,
  //     backgroundColor: bgColor,
  //     colorText: textColor,
  //     duration: const Duration(seconds: 5),
  //     icon: Icon(icon, color: textColor),
  //   );
  // }

  /// Update UI for ride status and trigger notifications
  void _updateUIForRideStatus(RideAssignment ride) {
    // Trigger notification based on status
    _triggerRideNotification(ride);

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

  /// Trigger notification with vibration and sound based on ride status
  void _triggerRideNotification(RideAssignment ride) {
    if (_rideNotificationService == null) {
      print('⚠️ SAHAr Ride notification service not available');
      return;
    }

    try {
      switch (ride.status) {
        case 'Waiting':
          _rideNotificationService?.notifyNewRide(
            rideId: ride.rideId,
            pickupLocation: ride.pickupLocation,
            passengerName: ride.passengerName,
          );
          break;
        case 'In-Progress':
          _rideNotificationService?.notifyRideInProgress(
            rideId: ride.rideId,
            destination: ride.dropoffLocation,
          );
          break;
        case 'Completed':
          _rideNotificationService?.notifyRideCompleted(
            rideId: ride.rideId,
            fare: ride.fareFinal,
          );
          break;
      }
    } catch (e) {
      print('❌ SAHAr Error triggering notification: $e');
    }
  }

  /// Show route to pickup with custom markers
  Future<void> _showRouteToPickup(RideAssignment ride) async {
    // Prevent concurrent updates
    if (_isUpdatingRoute) {
      print('⏸️ SAHAr Route update already in progress, skipping...');
      return;
    }
    
    _isUpdatingRoute = true;
    try {
      if (_locationService == null) {
        print('⚠️ SAHAr Location service is null, cannot show route to pickup');
        // Retry after a delay
        Future.delayed(const Duration(seconds: 2), () {
          if (_locationService != null) {
            _showRouteToPickup(ride);
          }
        });
        _isUpdatingRoute = false;
        return;
      }
      
      // Try to get current location with retries
      int retries = 3;
      while (retries > 0) {
        await _locationService!.getCurrentLocation();
        if (_locationService!.currentLatLng.value != null) {
          break;
        }
        retries--;
        if (retries > 0) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
      
      if (_locationService!.currentLatLng.value == null) {
        print('⚠️ SAHAr Current location is null after retries, cannot show route to pickup');
        return;
      }

      final origin = _locationService!.currentLatLng.value!;
      final pickup = LatLng(ride.pickUpLat, ride.pickUpLon);

      // ✅ Draw route from driver to pickup (only 1 polyline)
      // NOTE: useStraightLineOnError=false so that on API failure we keep the
      // existing polyline instead of replacing it with a synthetic straight line.
      final points = await GoogleDirectionsService.getRoutePoints(
        origin: origin,
        destination: pickup,
        useStraightLineOnError: false,
      );

      _setPolyline(points, Colors.orange);

      // ✅ Show only pickup marker (driver marker handled by MapService)
      final markers = <Marker>{
        Marker(
          markerId: const MarkerId('pickup'),
          position: pickup,
          infoWindow: InfoWindow(title: 'Pickup Location', snippet: ride.pickupLocation),
          icon: _pickupIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      };

      rideMarkers.assignAll(markers);
      
      print('✅ SAHAr Route to pickup displayed - Driver → Pickup (1 polyline)');
    } catch (e) {
      print('❌ SAHAr Error showing pickup route: $e');
    } finally {
      _isUpdatingRoute = false;
    }
  }

  /// Show route to next stop only (not all stops)
  Future<void> _showRouteToAllStops(RideAssignment ride) async {
    // Prevent concurrent updates
    if (_isUpdatingRoute) {
      print('⏸️ SAHAr Route update already in progress, skipping...');
      return;
    }
    
    _isUpdatingRoute = true;
    try {
      if (_locationService == null) {
        print('⚠️ SAHAr Location service is null, cannot show route to stops');
        // Retry after a delay
        Future.delayed(const Duration(seconds: 2), () {
          if (_locationService != null) {
            _showRouteToAllStops(ride);
          }
        });
        _isUpdatingRoute = false;
        return;
      }
      
      // Try to get current location with retries
      int retries = 3;
      while (retries > 0) {
        await _locationService!.getCurrentLocation();
        if (_locationService!.currentLatLng.value != null) {
          break;
        }
        retries--;
        if (retries > 0) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
      
      if (_locationService!.currentLatLng.value == null) {
        print('⚠️ SAHAr Current location is null after retries, cannot show route to stops');
        return;
      }

      final origin = _locationService!.currentLatLng.value!;
      final allStops = ride.stops
          .map((stop) => LatLng(stop.latitude, stop.longitude))
          .toList();

      if (allStops.isEmpty) return;

      // ✅ Only draw route to NEXT stop (first stop in list)
      // This is the immediate destination, not all stops
      final nextStop = allStops.first;

      // Get route from driver to next stop only (NO waypoints)
      // NOTE: useStraightLineOnError=false so that on API failure we keep the
      // existing polyline instead of replacing it with a synthetic straight line.
      final points = await GoogleDirectionsService.getRoutePoints(
        origin: origin,
        destination: nextStop,
        // No waypoints - direct route to next stop only
        useStraightLineOnError: false,
      );

      // Draw single polyline from driver to next stop
      _setPolyline(points, MColor.primaryNavy);

      // ✅ Show markers for all stops (for visual reference)
      final markers = <Marker>{};

      for (var stop in ride.stops) {
        final isDestination = stop.stopOrder == ride.stops.length - 1;
        final isNextStop = stop.stopOrder == 0; // First stop is next
        
        markers.add(
          Marker(
            markerId: MarkerId('stop_${stop.stopOrder}'),
            position: LatLng(stop.latitude, stop.longitude),
            infoWindow: InfoWindow(
              title: isDestination 
                  ? 'Final Destination' 
                  : isNextStop 
                      ? 'Next Stop' 
                      : 'Stop ${stop.stopOrder + 1}',
              snippet: stop.location,
            ),
            icon: isDestination
                ? (_destinationIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet))
                : (_stopIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan)),
          ),
        );
      }

      rideMarkers.assignAll(markers);
      
      print('✅ SAHAr Route to NEXT stop displayed - Driver → Next Stop (1 polyline)');
    } catch (e) {
      print('❌ SAHAr Error showing route: $e');
    } finally {
      _isUpdatingRoute = false;
    }
  }

  void _showCompletedRide(RideAssignment ride) {
    // ✅ Clear route using MapService
    if (Get.isRegistered<MapService>()) {
      MapService.to.polylines.clear();
    }
    rideMarkers.clear();

    print('💰 SAHAr _showCompletedRide called for ride: ${ride.rideId}');
    print('💰 SAHAr Current state: payment=${ride.payment}, showPaymentDialog=${showPaymentDialog.value}, paymentCompleted=${paymentCompleted.value}');

    // Check if payment is already successful (in case we receive Completed with payment in one go)
    final hasPayment = ride.payment == 'Successful';

    if (hasPayment) {
      // Payment already completed, show popup directly
      print('💰 SAHAr Payment already completed, showing popup directly');

      // Set completion flags
      paymentCompleted.value = true;
      isWaitingForPayment.value = false;

      // Clear all UI elements before showing payment popup
      _clearAllUIBeforePaymentPopup();

      // Show popup after comprehensive UI cleanup
      Future.delayed(const Duration(milliseconds: 300), () {
        showPaymentSuccessPopup(
          fareFinal: ride.fareFinal,
          tip: ride.tip ?? 0,
        );
      });

      return;
    }

    // Only show bottom sheet if we haven't shown anything yet AND no payment
    if (!showPaymentDialog.value && !paymentCompleted.value && !hasPayment) {
      // Reset all payment-related flags first
      isWaitingForPayment.value = false;
      paymentCompleted.value = false;

      // Set waiting for payment state
      isWaitingForPayment.value = true;
      showPaymentDialog.value = true;

      print('💰 SAHAr Showing payment bottom sheet for ride: ${ride.rideId}');
      print('💰 SAHAr Ride status: ${ride.status}, Payment: ${ride.payment}');

      // Show the waiting bottom sheet
      Get.bottomSheet(
        ModernPaymentBottomSheet(
          onDismiss: () {
            print('💰 SAHAr Payment bottom sheet dismissed');
            _resetRide();
          },
        ),
        isDismissible: false,
        enableDrag: false,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
      );
    } else {
      print('💰 SAHAr Skipping bottom sheet - showPaymentDialog=${showPaymentDialog.value}, paymentCompleted=${paymentCompleted.value}, hasPayment=$hasPayment');
    }
  }

  /// Reset ride state
  void _resetRide() {
    currentRide.value = null;
    rideStatus.value = 'No Active Ride';
    // ✅ Clear route using MapService
    if (Get.isRegistered<MapService>()) {
      MapService.to.polylines.clear();
    }
    rideMarkers.clear();
    currentRideId.value = '';
    isWaitingForPayment.value = false;
    paymentCompleted.value = false;
    showPaymentDialog.value = false;
  }

  /// Public method to start tracking (called by ActiveRideController)
  Future<void> startTracking() async {
    await startBackgroundService();
  }

  /// Public method to connect to hub (called by ActiveRideController)
  Future<void> connectToHub() async {
    await _ensureConnectedAndSubscribed();
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

    await _ensureConnectedAndSubscribed();

    if (isConnected.value && isSubscribed.value) {

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
    print('📤 SAHAr sendLocationUpdate called: $latitude, $longitude');
    
    if (_driverId == null || _driverName == null || _driverId!.isEmpty || _driverName!.isEmpty) {
      print('❌ SAHAr Driver info missing, attempting to reload...');
      await _loadDriverInfo();

      if (_driverId == null || _driverName == null || _driverId!.isEmpty || _driverName!.isEmpty) {
        print('❌ SAHAr Driver info still missing after reload - cannot send location');
        return false;
      }
    }

    final String rideId = currentRideId.value.isEmpty ? _emptyGuid : currentRideId.value;
    print('📤 SAHAr Sending location - RideId: $rideId, DriverId: $_driverId');

    // Try to send directly if connected
    if (isConnected.value && _hubConnection != null) {
      try {
        print('📡 SAHAr Invoking UpdateLocation on SignalR...');
        await _hubConnection!.invoke(
          'UpdateLocation',
          args: [rideId, _driverId, latitude, longitude],
        );

        locationUpdateCount.value++;
        print('✅ SAHAr Location sent successfully! Count: ${locationUpdateCount.value}');

        // Try to sync any offline buffered locations
        _syncOfflineData();

        return true;
      } catch (e) {
        print('❌ SAHAr Location send error (online): $e');
        // Fall through to offline save
      }
    } else {
      print('⚠️ SAHAr Not connected to SignalR - isConnected: ${isConnected.value}, hubConnection: ${_hubConnection != null}');
      print('❌ SAHAr Cannot send location: not connected, saving offline');
    }

    // If we reach here, save location offline
    await _saveOfflineLocation(latitude, longitude, rideId);
    return false;
  }

  Future<void> _saveOfflineLocation(
    double latitude,
    double longitude,
    String rideId,
  ) async {
    try {
      if (Get.isRegistered<DatabaseHelper>()) {
        await DatabaseHelper.to.insertLocation(latitude, longitude, rideId);
        print('💾 SAHAr Location buffered offline for ride: $rideId');
      } else {
        print('⚠️ SAHAr DatabaseHelper not registered, cannot buffer location');
      }
    } catch (e) {
      print('❌ SAHAr Error saving offline location: $e');
    }
  }

  Future<void> _syncOfflineData() async {
    if (!isConnected.value || _hubConnection == null) return;

    if (!Get.isRegistered<DatabaseHelper>()) {
      print('⚠️ SAHAr DatabaseHelper not available for sync');
      return;
    }

    try {
      final helper = DatabaseHelper.to;
      final unsynced = await helper.getUnsyncedLocations(limit: 50);

      if (unsynced.isEmpty) {
        return;
      }

      print('🔄 SAHAr Syncing ${unsynced.length} offline locations...');

      final List<int> syncedIds = [];

      for (final row in unsynced) {
        try {
          final int id = row['id'] as int;
          final double lat = (row['lat'] as num).toDouble();
          final double lng = (row['lng'] as num).toDouble();
          final String rideId = row['ride_id']?.toString() ?? _emptyGuid;

          await _hubConnection!.invoke(
            'UpdateLocation',
            args: [rideId, _driverId, lat, lng],
          );

          syncedIds.add(id);
        } catch (e) {
          print('❌ SAHAr Error syncing offline location row: $e');
          // Stop on first failure to avoid hammering server
          break;
        }
      }

      if (syncedIds.isNotEmpty) {
        await helper.markLocationsAsSynced(syncedIds);
        await helper.deleteSyncedLocations();
        print('✅ SAHAr Offline locations synced & cleaned: ${syncedIds.length}');
      }
    } catch (e) {
      print('❌ SAHAr Error during offline sync: $e');
    }
  }

  /// Check if location update should be sent
  bool _shouldSendLocationUpdate(Position newPosition) {
    // Always send first location
    if (lastSentLocation.value == null) {
      print('📍 SAHAr First location - will send to server');
      return true;
    }
    
    if (_locationService == null) return true;

    // Calculate distance from last sent position
    double distance = _locationService!.calculateDistance(
      LatLng(lastSentLocation.value!.latitude, lastSentLocation.value!.longitude),
      LatLng(newPosition.latitude, newPosition.longitude),
    );

    bool shouldSend = distance >= _minimumDistanceFilter;
    
    if (shouldSend) {
      print('📍 SAHAr Distance threshold met: ${distance.toStringAsFixed(1)}m - sending to server');
    }
    
    return shouldSend;
  }

  /// Check if route should be updated (throttled to save API costs)
  bool _shouldUpdateRoute(Position position) {
    if (_lastRouteUpdatePosition == null || _lastRouteUpdateTime == null) {
      return true; // First update
    }

    if (_locationService == null) return false;

    // Check distance threshold (50 meters)
    double distance = _locationService!.calculateDistance(
      LatLng(_lastRouteUpdatePosition!.latitude, _lastRouteUpdatePosition!.longitude),
      LatLng(position.latitude, position.longitude),
    );

    if (distance >= _routeUpdateDistanceThreshold) {
      return true; // Driver moved >50m from last route update
    }

    // Check time threshold (45 seconds)
    Duration timeSinceLastUpdate = DateTime.now().difference(_lastRouteUpdateTime!);
    if (timeSinceLastUpdate >= _routeUpdateTimeThreshold) {
      return true; // 45 seconds passed since last update
    }

    return false; // No update needed
  }

  /// Start location updates
  Future<void> _startLocationUpdates() async {
    if (isLocationSending.value) return;

    if (_locationService == null) {
      print('❌ SAHAr LocationService not available');
      return;
    }

    // Stream Setup
    _positionStream = _locationService!.getLocationStream(
      iOSPlatform: Platform.isIOS,
    ).listen(
      (Position position) async {
        print('📍 SAHAr Location received: ${position.latitude}, ${position.longitude}');

        // ---------------------------------------------------------
        // 1. Server ko location bhejein (SignalR) - FIRST PRIORITY
        // ---------------------------------------------------------
        if (_shouldSendLocationUpdate(position)) {
          bool success = await sendLocationUpdate(
            position.latitude,
            position.longitude,
          );
          if (success) {
            lastSentLocation.value = position;
            print('✅ SAHAr Location sent to server successfully');
          } else {
            print('❌ SAHAr Location send failed (buffered offline)');
          }
        }

        // ---------------------------------------------------------
        // 2. Update MapService for Animation & Rotation (Debounced)
        // ---------------------------------------------------------
        _debouncedMarkerUpdate(position);

        // ---------------------------------------------------------
        // 3. Route Update (Dynamic - Like Uber) ✅
        // ---------------------------------------------------------
        // Check karein ke ride chal rahi hai ya nahi
        if (currentRide.value != null && !_isUpdatingRoute) {
          // Update route every 10 seconds OR 50 meters (whichever comes first)
          if (_shouldUpdateRoute(position)) {
            // Prevent concurrent updates
            if (_isUpdatingRoute) return;
            _isUpdatingRoute = true;
            
            try {
              // ✅ Driver ki CURRENT location (from taxi marker)
              LatLng driverKiJaga = LatLng(position.latitude, position.longitude);
              LatLng manzil; // Kahan jana hai
              Color routeColor;

              if (rideStatus.value == 'Waiting') {
                // Agar passenger ko lene ja raha hai
                manzil = LatLng(currentRide.value!.pickUpLat, currentRide.value!.pickUpLon);
                routeColor = Colors.orange;
              } else if (rideStatus.value == 'In-Progress') {
                // ✅ Sirf NEXT stop tak route (first stop in list)
                if (currentRide.value!.stops.isNotEmpty) {
                  final nextStop = currentRide.value!.stops.first; // Next immediate stop
                  manzil = LatLng(nextStop.latitude, nextStop.longitude);
                } else {
                  manzil = LatLng(currentRide.value!.dropoffLat, currentRide.value!.dropoffLon);
                }
                routeColor = MColor.primaryNavy;
              } else {
                // Ride status not active, skip route update
                _isUpdatingRoute = false;
                return;
              }

              print('🔄 SAHAr Fetching new route from taxi position to destination...');

              // ✅ Direct route from CURRENT taxi position to next destination
              // This creates fresh polyline every 10 seconds from taxi marker
              // NOTE: useStraightLineOnError=false so that on API failure we keep
              // the existing polyline (no sudden straight-line artifact).
              final points = await GoogleDirectionsService.getRoutePoints(
                origin: driverKiJaga,
                destination: manzil,
                // No waypoints - direct route only
                useStraightLineOnError: false,
              );

              // ✅ CENTRALIZED: Remove old polyline and draw new one
              _setPolyline(points, routeColor);

              // Update throttling variables after successful route update
              _lastRouteUpdateTime = DateTime.now();
              _lastRouteUpdatePosition = driverKiJaga;

              print('✅ SAHAr Route updated from taxi marker (${points.length} points)');
              print('🔄 SAHAr Next update in 10 seconds or 50 meters');
            } catch (e) {
              print('❌ SAHAr Error updating route: $e');
            } finally {
              _isUpdatingRoute = false;
            }
          }
        }
      },
      onError: (error) => print('❌ SAHAr Position stream error: $error'),
    );

    isLocationSending.value = true;
  }

  /// Stop location updates
  void _stopLocationUpdates() {
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
        var batteryStatus = await Permission.ignoreBatteryOptimizations.request();
        if (batteryStatus.isDenied || batteryStatus.isPermanentlyDenied) {
          Get.snackbar(
            'Battery Optimization',
            'Please allow battery optimization to keep the app running in background',
            backgroundColor: Colors.orange.shade100,
            colorText: Colors.orange.shade800,
            duration: const Duration(seconds: 5),
          );
        }
      } catch (e) {
        print('⚠️ SAHAr Battery optimization permission not available');
      }

      return notificationStatus.isGranted;
    } catch (e) {
      print('❌ SAHAr Permission error: $e');
      return false;
    }
  }

  /// Enable WakeLock to keep screen/CPU active
  Future<void> _enableWakeLock() async {
    try {
      if (!_isWakeLockEnabled) {
        await WakelockPlus.enable();
        _isWakeLockEnabled = true;
        print('✅ SAHAr WakeLock enabled');
      }
    } catch (e) {
      print('❌ SAHAr Error enabling WakeLock: $e');
    }
  }

  /// Disable WakeLock
  Future<void> _disableWakeLock() async {
    try {
      if (_isWakeLockEnabled) {
        await WakelockPlus.disable();
        _isWakeLockEnabled = false;
        print('✅ SAHAr WakeLock disabled');
      }
    } catch (e) {
      print('❌ SAHAr Error disabling WakeLock: $e');
    }
  }

  /// Start background service
  Future<bool> startBackgroundService() async {
    if (isRunning.value) {
      print('⚠️ SAHAr Service already running');
      return true;
    }

    try {
      // Request location permissions via LocationService
      if (_locationService != null) {
        await _locationService!.requestBackgroundPermissions();
      }

      // Request notification and battery permissions
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

      // Connect to SignalR and subscribe in a single idempotent flow
      await _ensureConnectedAndSubscribed();
      if (!isConnected.value) {
        throw Exception('Failed to connect to server');
      }

      // Start location updates
      await _startLocationUpdates();

      // Start foreground service
      await FlutterForegroundTask.startService(
        notificationTitle: 'PickuRides',
        notificationText: "You're online and available for rides",
      );

      // Enable WakeLock to keep app running
      await _enableWakeLock();

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
      
      // Disable WakeLock
      await _disableWakeLock();
      
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

  /// Convenience helper for debugging: logs the current service info
  /// in a single, structured line so it can be inspected easily from
  /// the console or logcat while testing.
  void debugPrintServiceInfo() {
    final info = getServiceInfo();
    print('🧩 SAHAr BackgroundTrackingService state: $info');
  }

  @override
  void onClose() {
    _markerUpdateDebounce?.cancel();
    _connectivitySubscription?.cancel();
    stopBackgroundService();
    _stopReconnectionTimer();
    super.onClose();
  }

  /// Clear all UI elements before showing payment popup
  void _clearAllUIBeforePaymentPopup() {
    print('🧹 SAHAr Clearing all UI elements before payment popup');

    // Close any open bottom sheets
    if (Get.isBottomSheetOpen ?? false) {
      Get.back();
      print('💰 SAHAr Bottom sheet closed');
    }

    // Close any open dialogs (except the payment popup we're about to show)
    while (Get.isDialogOpen ?? false) {
      Get.back();
      print('💰 SAHAr Dialog closed');
    }

    // Clear ride-related UI elements
    // ✅ Clear route using MapService
    if (Get.isRegistered<MapService>()) {
      MapService.to.polylines.clear();
    }
    rideMarkers.clear();

    // Reset ride widget state by clearing current ride temporarily
    final tempRide = currentRide.value;
    currentRide.value = null;
    rideStatus.value = 'Payment Processing...';

    // Small delay to ensure UI updates, then restore ride for payment popup
    Future.delayed(const Duration(milliseconds: 50), () {
      currentRide.value = tempRide;
    });

    print('🧹 SAHAr All UI elements cleared');
  }

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

  /// ✅ CENTRALIZED FUNCTION: Sirf ye function route draw karega
  /// All route drawing MUST go through this function to avoid duplicates
  void _setPolyline(List<LatLng> points, Color color) {
    if (points.isEmpty) {
      print('⚠️ SAHAr _setPolyline: Empty points, skipping');
      return;
    }

    if (!Get.isRegistered<MapService>()) {
      print('⚠️ SAHAr MapService not registered, cannot draw route');
      return;
    }

    // ✅ Use MapService as Single Source of Truth
    MapService.to.updateRoutePolyline(points, color: color);
    
    print('✅ SAHAr Route Updated via Centralized Function (${points.length} points, color: $color)');
  }

  /// Debounced marker update to prevent excessive map rebuilds
  void _debouncedMarkerUpdate(Position position) {
    // Store the latest position
    _pendingMarkerUpdate = position;

    // Cancel previous timer
    _markerUpdateDebounce?.cancel();

    // Only update after 500ms of no new positions
    _markerUpdateDebounce = Timer(const Duration(milliseconds: 500), () {
      if (_pendingMarkerUpdate != null) {
        try {
          if (Get.isRegistered<MapService>()) {
            // MapService handles the driver marker with animation & rotation
            MapService.to.updateDriverMarker(
              _pendingMarkerUpdate!.latitude,
              _pendingMarkerUpdate!.longitude,
            );
            // Only print occasionally to reduce log spam
            if (DateTime.now().millisecond % 10 == 0) {
              print('🚗 SAHAr Driver marker updated via MapService (debounced)');
            }
          }
        } catch (e) {
          print('❌ SAHAr Error updating map service: $e');
        }
        _pendingMarkerUpdate = null;
      }
    });
  }

}
