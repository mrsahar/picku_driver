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
import 'package:pick_u_driver/core/chat_notification_service.dart';
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

  // Get chat notification service
  ChatNotificationService? get _chatNotificationService {
    try {
      return Get.isRegistered<ChatNotificationService>()
          ? ChatNotificationService.to
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

  // Route update throttling — DISABLED (Step 3 comment out hai, ye variables ab use nahi)
  // DateTime? _lastRouteUpdateTime;
  // LatLng? _lastRouteUpdatePosition;
  // static const double _routeUpdateDistanceThreshold = 50.0; // meters
  // static const Duration _routeUpdateTimeThreshold = Duration(seconds: 10);

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

  // ✅ Prevent double-tap on reset buttons
  bool _isResetting = false;

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
      print('🔄 SAHAr [BG] Internet restored, reconnecting silently...');

      // ✅ OPTIMIZATION: Batch all updates to prevent multiple UI rebuilds
      // Ensure SignalR connection + subscription in a single idempotent flow
      await _ensureConnectedAndSubscribed();

      // ✅ Run background tasks asynchronously without blocking
      Future.microtask(() async {
        try {
          // Resume location updates if active
          if (isLocationSending.value) {
            _resumeLocationUpdates();
          }

          // Recalculate route if we have an active ride (in background)
          if (currentRide.value != null && _locationService?.currentLatLng.value != null) {
            print('🗺️ SAHAr [BG] Recalculating route after internet restoration');
            await _recalculateRoute();
          }

          // Sync any offline data (in background)
          _syncOfflineData();
        } catch (e) {
          print('❌ SAHAr [BG] Error in background restoration tasks: $e');
        }
      });

      print('✅ SAHAr [BG] Internet restoration complete');
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

      // Route update tracking variables disabled (Step 3 comment out hai)

      // ✅ OPTIMIZATION: Debounce route updates to prevent rapid rebuilds
      await Future.delayed(const Duration(milliseconds: 300));

      // Trigger route update based on current ride status
      // Note: _isUpdatingRoute guard is managed inside each function
      if (ride.status == 'Waiting' || ride.status == 'Arrived') {
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
                          // ✅ Ensure driver is back in ride assignment queue
                          _ensureConnectedAndSubscribed();
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
                          // ✅ Ensure driver is back in ride assignment queue
                          _ensureConnectedAndSubscribed();
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
    if (_hubConnection == null) {
      print('❌ SAHAr [BG] Cannot setup handlers - _hubConnection is null');
      return;
    }

    print('🔧 SAHAr [BG] Setting up SignalR connection handlers...');

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
      print('🟢 SAHAr Driver is Back Online'); // ✅ Log as 'Back Online'
      isConnected.value = true;
      connectionStatus.value = 'Online'; // ✅ Changed from 'Connected' to 'Online'
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
      print('🚨🚨🚨 SAHAr [BG][SignalR] >>>>>> NewRideAssigned TRIGGERED <<<<<<');
      print('🚨 SAHAr [BG][SignalR] NewRideAssigned RAW arguments: $arguments');
      print('🚨 SAHAr [BG][SignalR] arguments type: ${arguments.runtimeType}');
      print('🚨 SAHAr [BG][SignalR] arguments length: ${arguments?.length ?? 0}');
      if (arguments != null && arguments.isNotEmpty) {
        print('🚨 SAHAr [BG][SignalR] arg[0] type: ${arguments[0].runtimeType}');
        print('🚨 SAHAr [BG][SignalR] arg[0] value: ${arguments[0]}');
        try {
          print('🚕 SAHAr New ride assigned!');
          final rideData = arguments[0] as Map<String, dynamic>;
          print('🚨 SAHAr [BG][SignalR] Parsed rideData keys: ${rideData.keys.toList()}');
          print('🚨 SAHAr [BG][SignalR] Full rideData: $rideData');
          _playNotificationSound();
          _handleNewRideAssignment(rideData);
        } catch (e) {
          print('❌ SAHAr Error parsing ride: $e');
          print('❌ SAHAr Stack trace: ${StackTrace.current}');
        }
      } else {
        print('⚠️ SAHAr [BG][SignalR] NewRideAssigned: arguments is null or empty');
      }
    });

    _hubConnection!.on('RideStatusUpdate', (List<Object?>? arguments) {
      print('🚨🚨🚨 SAHAr [BG][SignalR] >>>>>> RideStatusUpdate TRIGGERED <<<<<<');
      print('🚨 SAHAr [BG][SignalR] RideStatusUpdate RAW arguments: $arguments');
      print('🚨 SAHAr [BG][SignalR] arguments type: ${arguments.runtimeType}');
      print('🚨 SAHAr [BG][SignalR] arguments length: ${arguments?.length ?? 0}');
      if (arguments != null && arguments.isNotEmpty) {
        print('🚨 SAHAr [BG][SignalR] arg[0] type: ${arguments[0].runtimeType}');
        print('🚨 SAHAr [BG][SignalR] arg[0] value: ${arguments[0]}');
        try {
          final statusUpdate = arguments[0] as Map<String, dynamic>;
          print('🚨 SAHAr [BG][SignalR] Parsed statusUpdate keys: ${statusUpdate.keys.toList()}');
          print('🚨 SAHAr [BG][SignalR] Full statusUpdate: $statusUpdate');
          _handleRideStatusUpdate(statusUpdate);
        } catch (e) {
          print('❌ SAHAr Error parsing status: $e');
          print('❌ SAHAr Stack trace: ${StackTrace.current}');
        }
      } else {
        print('⚠️ SAHAr [BG][SignalR] RideStatusUpdate: arguments is null or empty');
      }
    });

    // ===== LOCATION TRACKING EVENTS =====
    _hubConnection!.on('LocationReceived', (List<Object?>? arguments) {
      print('🚨 SAHAr [BG][SignalR] LocationReceived RAW: $arguments');
      print('📍 SAHAr Location acknowledged by server');
    });

    _hubConnection!.on('RideCompleted', (List<Object?>? arguments) {
      print('🚨🚨🚨 SAHAr [BG][SignalR] >>>>>> RideCompleted TRIGGERED <<<<<<');
      print('🚨 SAHAr [BG][SignalR] RideCompleted RAW arguments: $arguments');
      print('🚨 SAHAr [BG][SignalR] arguments type: ${arguments.runtimeType}');
      print('🚨 SAHAr [BG][SignalR] arguments length: ${arguments?.length ?? 0}');
      if (arguments != null && arguments.isNotEmpty) {
        print('🚨 SAHAr [BG][SignalR] arg[0] type: ${arguments[0].runtimeType}');
        print('🚨 SAHAr [BG][SignalR] arg[0] value: ${arguments[0]}');
        String completedRideId = arguments[0].toString();
        if (currentRideId.value == completedRideId) {
          print('✅ SAHAr Ride completed: $completedRideId');
          currentRideId.value = '';
          _playNotificationSound();
        } else {
          print('⚠️ SAHAr [BG][SignalR] RideCompleted ID mismatch - current: ${currentRideId.value}, received: $completedRideId');
        }
      } else {
        print('⚠️ SAHAr [BG][SignalR] RideCompleted: arguments is null or empty');
      }
    });
// Update the PaymentCompleted handler in BackgroundTrackingService
// Replace the existing handler with this:

    _hubConnection!.on('PaymentCompleted', (List<Object?>? arguments) {
      print('🚨🚨🚨 SAHAr [BG][SignalR] >>>>>> PaymentCompleted TRIGGERED <<<<<<');
      print('🚨 SAHAr [BG][SignalR] PaymentCompleted RAW arguments: $arguments');
      print('🚨 SAHAr [BG][SignalR] arguments type: ${arguments.runtimeType}');
      print('🚨 SAHAr [BG][SignalR] arguments length: ${arguments?.length ?? 0}');
      if (arguments != null && arguments.isNotEmpty) {
        print('🚨 SAHAr [BG][SignalR] arg[0] type: ${arguments[0].runtimeType}');
        print('🚨 SAHAr [BG][SignalR] arg[0] value: ${arguments[0]}');
        try {
          final paymentData = arguments[0] as Map<String, dynamic>;
          print('🚨 SAHAr [BG][SignalR] Parsed paymentData keys: ${paymentData.keys.toList()}');
          print('🚨 SAHAr [BG][SignalR] Full paymentData: $paymentData');
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
      print('🚨🚨🚨 SAHAr [BG][SignalR] >>>>>> DriverStatusChanged TRIGGERED <<<<<<');
      print('🚨 SAHAr [BG][SignalR] DriverStatusChanged RAW arguments: $arguments');
      print('🚨 SAHAr [BG][SignalR] arguments type: ${arguments.runtimeType}');
      print('🚨 SAHAr [BG][SignalR] arguments length: ${arguments?.length ?? 0}');
      if (arguments != null && arguments.length >= 2) {
        print('🚨 SAHAr [BG][SignalR] arg[0] type: ${arguments[0].runtimeType}');
        print('🚨 SAHAr [BG][SignalR] arg[0] value (driverId): ${arguments[0]}');
        print('🚨 SAHAr [BG][SignalR] arg[1] type: ${arguments[1].runtimeType}');
        print('🚨 SAHAr [BG][SignalR] arg[1] value (isOnline): ${arguments[1]}');
        try {
          String driverId = arguments[0].toString();
          bool isOnline = arguments[1] as bool;

          print('🚨 SAHAr [BG][SignalR] Current driver ID: $_driverId');
          print('🚨 SAHAr [BG][SignalR] Received driver ID: $driverId');
          print('🚨 SAHAr [BG][SignalR] Is Online: $isOnline');

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
          } else {
            print('⚠️ SAHAr [BG][SignalR] DriverStatusChanged: driver ID mismatch');
          }
        } catch (e) {
          print('❌ SAHAr Error parsing driver status change: $e');
          print('❌ SAHAr Stack trace: ${StackTrace.current}');
        }
      } else {
        print('⚠️ SAHAr [BG][SignalR] DriverStatusChanged: insufficient arguments');
      }
    });

    // ===== CHAT MESSAGE EVENTS =====
    _hubConnection!.on('ReceiveRideChatMessage', (List<Object?>? arguments) {
      print('💬💬💬 SAHAr [BG][SignalR] >>>>>> ReceiveRideChatMessage TRIGGERED <<<<<<');
      print('💬 SAHAr [BG][SignalR] ReceiveRideChatMessage RAW arguments: $arguments');
      if (arguments != null && arguments.isNotEmpty) {
        try {
          final messageData = arguments[0] as Map<String, dynamic>;
          print('💬 SAHAr [BG][SignalR] Message data: $messageData');

          // Extract message details
          final String senderId = messageData['senderId']?.toString() ?? '';
          final String senderRole = messageData['senderRole']?.toString() ?? '';
          final String message = messageData['message']?.toString() ?? '';
          final String rideId = messageData['rideId']?.toString() ?? currentRideId.value;

          print('💬 SAHAr [BG] New chat message received:');
          print('   - Sender ID: $senderId');
          print('   - Sender Role: $senderRole');
          print('   - Message: $message');
          print('   - Ride ID: $rideId');
          print('   - Current Driver ID: $_driverId');

          // Only show notification if message is from passenger (Rider)
          // Check: senderRole is Rider AND senderId is NOT the current driver
          final isFromPassenger = senderRole.toLowerCase() == 'rider';
          final isNotFromMe = senderId != _driverId;

          print('💬 SAHAr [BG] Message filtering:');
          print('   - Is from passenger (Rider): $isFromPassenger');
          print('   - Is not from me: $isNotFromMe');
          print('   - Chat notification service available: ${_chatNotificationService != null}');

          if (isFromPassenger && isNotFromMe) {
            // Show notification using ChatNotificationService
            if (_chatNotificationService != null) {
              print('💬 SAHAr [BG] Showing chat notification...');
              _chatNotificationService!.showChatMessageNotification(
                senderName: 'Passenger',
                message: message,
                rideId: rideId,
              );
              print('✅ SAHAr [BG] Chat notification shown for passenger message');
            } else {
              print('❌ SAHAr [BG] ChatNotificationService not available - cannot show notification');
            }
          } else {
            print('⏭️ SAHAr [BG] Skipping notification (not from passenger or from self)');
          }
        } catch (e) {
          print('❌ SAHAr [BG] Error handling chat message: $e');
          print('❌ SAHAr Stack trace: ${StackTrace.current}');
        }
      } else {
        print('⚠️ SAHAr [BG][SignalR] ReceiveRideChatMessage: no arguments');
      }
    });

    print('✅✅✅ SAHAr [BG] ALL SIGNALR HANDLERS REGISTERED SUCCESSFULLY ✅✅✅');
    print('✅ SAHAr [BG] Listening for SignalR events:');
    print('   - NewRideAssigned');
    print('   - RideStatusUpdate');
    print('   - LocationReceived');
    print('   - RideCompleted');
    print('   - PaymentCompleted');
    print('   - DriverStatusChanged');
    print('   - ReceiveRideChatMessage');
  }


  /// Initialize ActiveRideController after successful connection
  /// ✅ NOTE: This is now mostly a no-op since ActiveRideController is initialized
  /// in InitialBinding at app startup to prevent navigation issues
  void _initializeActiveRideController() {
    try {
      // Check if ActiveRideController is already registered
      if (!Get.isRegistered<ActiveRideController>()) {
        print('🎯 SAHAr Initializing ActiveRideController (fallback - should be initialized at startup)');
        Get.put(ActiveRideController(), permanent: true);
        print('✅ SAHAr ActiveRideController initialized successfully');
      } else {
        print('ℹ️ SAHAr ActiveRideController already registered (initialized at startup)');
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

      // ✅ OPTIMIZATION: Only update status if it actually changed
      if (connectionStatus.value != 'Connecting...') {
        connectionStatus.value = 'Connecting...';
      }

      await _hubConnection!.start();

      // ✅ Batch observable updates together
      if (!isConnected.value || connectionStatus.value != 'Online') {
        isConnected.value = true;
        connectionStatus.value = 'Online'; // ✅ Changed from 'Connected' to 'Online'
      }

      print('✅ SAHAr Connected to hub');

      // ✅ Run initialization tasks asynchronously to avoid blocking
      Future.microtask(() {
        _initializeActiveRideController();
        _syncOfflineData();
      });

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
      // ✅ CHECK: If this is a "Payment Received" status, handle it specially
      if (rideData['status'] == 'Payment Received') {
        print('💰💰💰 SAHAr PAYMENT RECEIVED in NewRideAssigned!');

        // Get current ride data for payment info
        double fareFinal = 0.0;
        double tip = 0.0;

        // Try to get fare from currentRide if available
        if (currentRide.value != null) {
          fareFinal = currentRide.value!.fareFinal;
          tip = currentRide.value!.tip ?? 0.0;
        }

        // Parse fareFinal from rideData if available
        if (rideData['fareFinal'] != null) {
          if (rideData['fareFinal'] is num) {
            fareFinal = (rideData['fareFinal'] as num).toDouble();
          } else {
            fareFinal = double.tryParse(rideData['fareFinal'].toString()) ?? fareFinal;
          }
        } else if (rideData['fareEstimate'] != null) {
          if (rideData['fareEstimate'] is num) {
            fareFinal = (rideData['fareEstimate'] as num).toDouble();
          } else {
            fareFinal = double.tryParse(rideData['fareEstimate'].toString()) ?? fareFinal;
          }
        }

        // Parse tip from rideData if available
        if (rideData['tip'] != null) {
          if (rideData['tip'] is num) {
            tip = (rideData['tip'] as num).toDouble();
          } else {
            tip = double.tryParse(rideData['tip'].toString()) ?? tip;
          }
        }

        print('💰 SAHAr Payment Received - Fare: \$${fareFinal.toStringAsFixed(2)}, Tip: \$${tip.toStringAsFixed(2)}');

        // Update flags
        paymentCompleted.value = true;
        isWaitingForPayment.value = false;

        // Close any open dialogs/bottom sheets
        if (showPaymentDialog.value || Get.isBottomSheetOpen == true) {
          Get.back();
        }

        // Clear all UI elements before showing payment popup
        _clearAllUIBeforePaymentPopup();

        // Show payment success popup after a short delay
        Future.delayed(const Duration(milliseconds: 300), () {
          showPaymentSuccessPopup(
            fareFinal: fareFinal,
            tip: tip,
          );
        });

        return; // Exit early, don't process as normal ride assignment
      }

      // ✅ Regular ride assignment processing
      final ride = RideAssignment.fromJson(rideData);
      currentRide.value = ride;
      rideStatus.value = ride.status;
      currentRideId.value = ride.rideId;

      // ✅ Auto-subscribe to ride chat for notifications
      _subscribeToRideChat(ride.rideId);

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
      print('🔄 SAHAr Status update received:');
      print('   - Raw status data: $statusData');

      // Check for "Payment Received" status directly
      if (statusData['status'] == 'Payment Received') {
        print('💰💰💰 SAHAr PAYMENT RECEIVED STATUS DETECTED!');

        // Get payment details from statusData
        double fareFinal = 0.0;
        double tip = 0.0;

        // Parse fareFinal
        if (statusData['fareFinal'] != null) {
          if (statusData['fareFinal'] is num) {
            fareFinal = (statusData['fareFinal'] as num).toDouble();
          } else {
            fareFinal = double.tryParse(statusData['fareFinal'].toString()) ?? 0.0;
          }
        } else if (statusData['fareEstimate'] != null) {
          if (statusData['fareEstimate'] is num) {
            fareFinal = (statusData['fareEstimate'] as num).toDouble();
          } else {
            fareFinal = double.tryParse(statusData['fareEstimate'].toString()) ?? 0.0;
          }
        }

        // Parse tip
        if (statusData['tip'] != null) {
          if (statusData['tip'] is num) {
            tip = (statusData['tip'] as num).toDouble();
          } else {
            tip = double.tryParse(statusData['tip'].toString()) ?? 0.0;
          }
        }

        print('💰 SAHAr Payment Received - Fare: \$${fareFinal.toStringAsFixed(2)}, Tip: \$${tip.toStringAsFixed(2)}');

        // Update flags
        paymentCompleted.value = true;
        isWaitingForPayment.value = false;

        // Close any open dialogs/bottom sheets
        if (showPaymentDialog.value) {
          Get.back();
        }

        // Clear all UI elements before showing payment popup
        _clearAllUIBeforePaymentPopup();

        // Show payment success popup after a short delay
        Future.delayed(const Duration(milliseconds: 300), () {
          showPaymentSuccessPopup(
            fareFinal: fareFinal,
            tip: tip,
          );
        });

        return; // Exit early, don't process as normal status update
      }

      // Regular status update processing
      final ride = RideAssignment.fromJson(statusData);

      // Check if this is a payment completion update
      final wasWaitingForPayment = isWaitingForPayment.value;
      final hasPaymentCompleted = ride.payment == 'Successful' && ride.status == 'Completed';

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
      _updateUIForRideStatus(ride);

      print('🔄 SAHAr Ride status: ${ride.status}');
    } catch (e) {
      print('❌ SAHAr Error handling status: $e');
    }
  }
  /// Update UI for ride status and trigger notifications
  void _updateUIForRideStatus(RideAssignment ride) {
    // Trigger notification based on status
    _triggerRideNotification(ride);

    switch (ride.status) {
      case 'Waiting':
      case 'Pending':
        _showRouteToPickup(ride);
        break;
      case 'Arrived':
        // Driver has arrived at pickup, keep showing the route but prepare for ride start
        _showRouteToPickup(ride);
        print('✅ SAHAr Driver has arrived at pickup location');
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
        case 'Pending':
          _rideNotificationService?.notifyNewRide(
            rideId: ride.rideId,
            pickupLocation: ride.pickupLocation,
            passengerName: ride.passengerName,
          );
          break;
        case 'Arrived':
          // Notify that driver has arrived at pickup
          print('📍 SAHAr Notifying arrival at pickup location');
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
  Future<void> _showRouteToPickup(RideAssignment ride, {int retryCount = 0}) async {
    // Prevent concurrent updates
    if (_isUpdatingRoute) {
      print('⏸️ SAHAr Route update already in progress, skipping...');
      return;
    }
    
    _isUpdatingRoute = true;
    try {
      if (_locationService == null) {
        print('⚠️ SAHAr Location service is null, cannot show route to pickup');
        _isUpdatingRoute = false;
        // Retry after a delay (max 5 retries)
        if (retryCount < 5) {
          Future.delayed(const Duration(seconds: 2), () {
            _showRouteToPickup(ride, retryCount: retryCount + 1);
          });
        }
        return;
      }
      
      // Try to get current location with retries
      int locRetries = 5;
      while (locRetries > 0) {
        await _locationService!.getCurrentLocation();
        if (_locationService!.currentLatLng.value != null) {
          break;
        }
        locRetries--;
        if (locRetries > 0) {
          await Future.delayed(const Duration(milliseconds: 800));
        }
      }
      
      if (_locationService!.currentLatLng.value == null) {
        print('⚠️ SAHAr Current location is null after retries, scheduling retry for route to pickup (attempt ${retryCount + 1})');
        _isUpdatingRoute = false;
        // Schedule a retry after 3 seconds (max 5 retries)
        if (retryCount < 5) {
          Future.delayed(const Duration(seconds: 3), () {
            _showRouteToPickup(ride, retryCount: retryCount + 1);
          });
        }
        return;
      }

      final origin = _locationService!.currentLatLng.value!;
      final pickup = LatLng(ride.pickUpLat, ride.pickUpLon);

      // ✅ Draw route from driver to pickup (only 1 polyline)
      // NOTE: useStraightLineOnError=true so that even if Directions API fails
      // on first ride assignment, a straight-line fallback polyline is shown.
      final points = await GoogleDirectionsService.getRoutePoints(
        origin: origin,
        destination: pickup,
        useStraightLineOnError: true,
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

  /// Show route to final destination passing through ALL remaining stops as waypoints (like Uber/Careem)
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
      int retries = 5;
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

      // ✅ UBER/CAREEM BEHAVIOR: Sort stops by stopOrder to ensure correct sequence
      final sortedStops = List<RideStop>.from(ride.stops)
        ..sort((a, b) => a.stopOrder.compareTo(b.stopOrder));

      if (sortedStops.isEmpty) {
        print('⚠️ SAHAr No stops available, cannot draw route');
        return;
      }

      // ✅ CRITICAL CHANGE: Route from Driver → Final Destination, passing through ALL remaining stops
      // Final destination is the LAST stop in the sorted list
      final finalDestination = LatLng(
        sortedStops.last.latitude,
        sortedStops.last.longitude,
      );

      // All stops EXCEPT the last one are waypoints (intermediate stops)
      final waypoints = sortedStops.length > 1
          ? sortedStops
              .sublist(0, sortedStops.length - 1) // All stops except the last
              .map((stop) => LatLng(stop.latitude, stop.longitude))
              .toList()
          : <LatLng>[]; // No waypoints if only one stop (direct to destination)

      print('🗺️ SAHAr Drawing route with ${waypoints.length} waypoints to final destination');
      print('   Origin: Driver at ${origin.latitude}, ${origin.longitude}');
      print('   Waypoints: ${waypoints.length} stops');
      print('   Destination: ${finalDestination.latitude}, ${finalDestination.longitude}');

      // ✅ Get route from driver to final destination passing through ALL remaining stops as waypoints
      // NOTE: useStraightLineOnError=false so that on API failure we keep the
      // existing polyline instead of replacing it with a synthetic straight line.
      final points = await GoogleDirectionsService.getRoutePoints(
        origin: origin,
        destination: finalDestination,
        waypoints: waypoints.isNotEmpty ? waypoints : null,
        useStraightLineOnError: true,
      );

      // Draw single polyline showing complete route through all stops
      _setPolyline(points, MColor.primaryNavy);

      // ✅ Show markers for ALL remaining stops (NO pickup marker in In-Progress phase)
      final markers = <Marker>{};

      for (var stop in sortedStops) {
        final isDestination = stop.stopOrder == sortedStops.length - 1;
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
      
      print('✅ SAHAr Route to ALL stops displayed - Driver → Waypoints → Final Destination (1 polyline, ${waypoints.length} waypoints)');
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
    // ✅ Prevent double-tap - if already resetting, skip
    if (_isResetting) {
      print('⚠️ SAHAr Reset already in progress, ignoring duplicate call');
      return;
    }

    _isResetting = true;

    currentRide.value = null;
    rideStatus.value = 'Online'; // ✅ Changed from 'No Active Ride' to 'Online' for Uber-like experience

    // ✅ Clear route and markers (moved from _clearAllUIBeforePaymentPopup)
    if (Get.isRegistered<MapService>()) {
      MapService.to.polylines.clear();
    }
    rideMarkers.clear();

    currentRideId.value = '';
    isWaitingForPayment.value = false;
    paymentCompleted.value = false;
    showPaymentDialog.value = false;

    // ✅ Background tracking and SignalR connection remain active - driver stays ready for next request
    // No need to stop tracking or disconnect - this is key for seamless Uber-like experience

    // ✅ Animate camera back to driver's current position with bearing reset to North (0)
    if (lastSentLocation.value != null && Get.isRegistered<MapService>()) {
      MapService.to.animateToLocation(
        LatLng(lastSentLocation.value!.latitude, lastSentLocation.value!.longitude),
        zoom: 17.0,
        bearing: 0.0, // ✅ Reset to North for better orientation
      );
      print('📍 SAHAr Camera animated back to driver position (bearing reset to North)');
    }

    // Reset the double-tap prevention flag after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      _isResetting = false;
    });
  }

  /// Subscribe to ride chat to receive chat notifications
  Future<void> _subscribeToRideChat(String rideId) async {
    if (_hubConnection == null || rideId.isEmpty) {
      print('⚠️ SAHAr Cannot subscribe to chat: hubConnection is null or rideId is empty');
      return;
    }

    try {
      print('💬 SAHAr [BG] Subscribing to ride chat: $rideId');

      // ✅ Ensure chat notification service is available and has permission
      if (_chatNotificationService != null) {
        // Check if permission is already granted
        final hasPermission = await _chatNotificationService!.checkNotificationPermission();

        if (!hasPermission) {
          print('⚠️ SAHAr [BG] Chat notification permission not granted, requesting...');
          // Request permission
          final granted = await _chatNotificationService!.requestNotificationPermission();
          if (granted) {
            print('✅ SAHAr [BG] Chat notification permission granted');
          } else {
            print('❌ SAHAr [BG] Chat notification permission denied - notifications will not work');
          }
        } else {
          print('✅ SAHAr [BG] Chat notification permission already granted');
        }
      } else {
        print('⚠️ SAHAr [BG] ChatNotificationService not available');
      }

      // Join the ride chat room via SignalR
      await _hubConnection!.invoke('JoinRideChat', args: [rideId]);

      print('✅ SAHAr [BG] Subscribed to ride chat for: $rideId');

      // Request chat history to show any existing messages
      await _hubConnection!.invoke('GetRideChatHistory', args: [rideId]);

      print('💬 SAHAr [BG] Chat history requested for: $rideId');
    } catch (e) {
      print('❌ SAHAr [BG] Error subscribing to chat: $e');
    }
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

  // ℹ️ DISABLED: _shouldUpdateRoute ab use nahi ho rahi kyunke
  // Step 3 (periodic API route update) comment out kar diya gaya hai.
  // Polyline trimming ab map_service.dart mein mathematically ho rahi hai.
  //
  // bool _shouldUpdateRoute(Position position) {
  //   if (_lastRouteUpdatePosition == null || _lastRouteUpdateTime == null) {
  //     return true;
  //   }
  //   if (_locationService == null) return false;
  //   double distance = _locationService!.calculateDistance(
  //     LatLng(_lastRouteUpdatePosition!.latitude, _lastRouteUpdatePosition!.longitude),
  //     LatLng(position.latitude, position.longitude),
  //   );
  //   if (distance >= _routeUpdateDistanceThreshold) return true;
  //   Duration timeSinceLastUpdate = DateTime.now().difference(_lastRouteUpdateTime!);
  //   if (timeSinceLastUpdate >= _routeUpdateTimeThreshold) return true;
  //   return false;
  // }

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
        // ℹ️  DISABLED: Ab har 10 seconds baad Google Directions API call nahi hogi.
        // Polyline ko mathematically trim karne ka kaam map_service.dart ke
        // _trimPolyline() function mein ho raha hai (Haversine formula se).
        // Naya route sirf tab mangwaya jaye ga jab ride status change ho —
        // jo ke _updateUIForRideStatus() mein handle ho raha hai.
        // Is se Google Directions API quota protect hoga aur bill control mein rahega.

        // if (currentRide.value != null && !_isUpdatingRoute) {
        //   if (_shouldUpdateRoute(position)) {
        //     if (_isUpdatingRoute) return;
        //     _isUpdatingRoute = true;
        //     try {
        //       ... route update API logic ...
        //     } catch (e) {
        //       print('❌ SAHAr Error updating route: $e');
        //     } finally {
        //       _isUpdatingRoute = false;
        //     }
        //   }
        // }
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

    // ✅ DO NOT clear polylines or markers here - driver should see final route during payment popup
    // Polylines and markers will be cleared only when driver clicks OK/View Earnings in _resetRide()

    // Reset ride widget state by clearing current ride temporarily
    final tempRide = currentRide.value;
    currentRide.value = null;
    rideStatus.value = 'Payment Processing...';

    // Small delay to ensure UI updates, then restore ride for payment popup
    Future.delayed(const Duration(milliseconds: 50), () {
      currentRide.value = tempRide;
    });

    print('🧹 SAHAr UI elements cleared (route remains visible)');
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
