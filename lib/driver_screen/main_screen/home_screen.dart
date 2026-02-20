import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pick_u_driver/controllers/ride_controller.dart';
import 'package:pick_u_driver/controllers/ride_status_controller.dart';
import 'package:pick_u_driver/core/background_tracking_service.dart';
import 'package:pick_u_driver/controllers/driver_status_controller.dart';
import 'package:pick_u_driver/core/location_service.dart';
import 'package:pick_u_driver/core/map_service.dart';
import 'package:pick_u_driver/core/permission_service.dart';
import 'package:pick_u_driver/core/chat_notification_service.dart';
import 'package:pick_u_driver/core/ride_notification_service.dart';
import 'package:pick_u_driver/utils/map_theme/dark_map_theme.dart';
import 'package:pick_u_driver/utils/map_theme/light_map_theme.dart';
import 'ride_widgets/ride_widget.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late GoogleMap googleMap;

  // Services and controllers
  final BackgroundTrackingService _backgroundService = BackgroundTrackingService.to;
  final LocationService _locationService = LocationService.to;
  final MapService _mapService = MapService.to;
  final PermissionService _permissionService = PermissionService.to;
  final ChatNotificationService _notificationService = ChatNotificationService.to;
  final RideNotificationService _rideNotificationService = RideNotificationService.to;
  late DriverStatusController _driverStatusController;
  RideStatusController? _rideStatusController;

  // Map and UI state
  static const CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(31.8329711, 70.9028416),
    zoom: 17,
  );

  // Track if user moved away from their location
  final RxBool _showCenterButton = false.obs;
  LatLng? _userLocation;

  // Track if initial location has been set
  bool _hasInitialLocationBeenSet = false;

  // ✅ REMOVED: Redundant location stream subscription
  // Location updates are now handled centrally by BackgroundTrackingService
  // StreamSubscription<Position>? _locationStreamSubscription;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  @override
  void dispose() {
    // ✅ Removed: _locationStreamSubscription?.cancel();
    _driverStatusController.dispose();
    _rideStatusController?.dispose();
    super.dispose();
  }

  /// Initialize app
  Future<void> _initializeApp() async {
    try {
      if (_permissionService.isReady) {
        await _initializeControllers();
        await _showCurrentLocationOnMap();
        _setupLocationListener(); // Add location listener

        // Request notification permission after a short delay
        Future.delayed(const Duration(seconds: 2), () {
          _checkNotificationPermission();
        });
      }
    } catch (e) {
      print('❌ SAHAr Error initializing app: $e');
    }
  }

  /// Check and request notification permission
  Future<void> _checkNotificationPermission() async {
    try {
      // Don't show if already requested for both services
      if (_notificationService.hasRequestedPermission.value &&
          _rideNotificationService.hasRequestedPermission.value) {
        return;
      }

      // Check chat notification permission
      final hasChatPermission = await _notificationService.checkNotificationPermission();

      // Check ride notification permission
      final hasRidePermission = await _rideNotificationService.checkNotificationPermission();

      if (!hasChatPermission || !hasRidePermission) {
        // Show ride notification permission dialog first (more important)
        if (!hasRidePermission) {
          await _rideNotificationService.showPermissionRequestDialog();
        }

        // Then show chat notification permission if needed
        if (!hasChatPermission) {
          await _notificationService.showPermissionRequestDialog();
        }
      }
    } catch (e) {
      print('❌ SAHAr Error checking notification permission: $e');
    }
  }

  /// Initialize controllers
  Future<void> _initializeControllers() async {
    try {
      _driverStatusController = Get.put(DriverStatusController());
      _rideStatusController = Get.put(RideStatusController());
      Get.put(RideController()); // ✅ Moved from build method to avoid re-initialization
      await Future.delayed(const Duration(seconds: 1));
      print('✅ SAHAr Controllers initialized');
    } catch (e) {
      print('❌ SAHAr Error initializing controllers: $e');
    }
  }

  /// Show current location on map
  /// Show current location on map
  Future<void> _showCurrentLocationOnMap() async {
    try {
      await _locationService.getCurrentLocation();

      if (_locationService.currentLatLng.value != null) {
        LatLng currentLocation = _locationService.currentLatLng.value!;
        _userLocation = currentLocation;

        // FIXED: New method name, removed 'title'
        _mapService.updateDriverMarker(
          currentLocation.latitude,
          currentLocation.longitude,
        );

        // Center map on first location
        if (!_hasInitialLocationBeenSet) {
          // Ab ye chalega kyunki humne animateToLocation wapis daal diya hai
          await _centerMapToLocation(currentLocation, zoom: 17.0);
          _hasInitialLocationBeenSet = true;
          print('✅ SAHAr First location set and map centered');
        }

        // ✅ REMOVED: setState() - Not needed with GetX observables
        // GetX automatically rebuilds widgets wrapped in Obx() when observables change
      }
    } catch (e) {
      print('❌ SAHAr Error showing current location: $e');
    }
  }

  /// Setup location listener for continuous updates
  void _setupLocationListener() {
    // ✅ OPTIMIZATION: React to LocationService observables instead of creating another stream
    // BackgroundTrackingService handles the actual location stream
    // We just react to the changes here for UI updates

    ever(_locationService.currentLatLng, (LatLng? newLocation) {
      if (newLocation != null) {
        // Update stored location
        _userLocation = newLocation;

        // Center map only on first location update
        if (!_hasInitialLocationBeenSet) {
          _centerMapToLocation(newLocation, zoom: 17.0);
          _hasInitialLocationBeenSet = true;
          print('✅ HomeScreen: First location set and map centered');
        }
      }
    });

    // Check if location is already available
    if (_locationService.currentLatLng.value != null && !_hasInitialLocationBeenSet) {
      LatLng currentLocation = _locationService.currentLatLng.value!;

      _userLocation = currentLocation;
      _centerMapToLocation(currentLocation, zoom: 17.0);
      _hasInitialLocationBeenSet = true;
    }
  }

  /// Center map to specific location
  Future<void> _centerMapToLocation(LatLng location, {double zoom = 17.0}) async {
    // Ye ab error nahi dega
    await _mapService.animateToLocation(location, zoom: zoom);
    print('🎯 SAHAr Map centered to: $location with zoom: $zoom');
  }


  /// Check if camera moved away from user location
  void _onCameraMove(CameraPosition position) {
    if (_userLocation == null) return;

    // ✅ Notify MapService that user has panned the camera
    _mapService.onUserCameraMove();

    // Calculate distance between camera target and user location
    double distance = _calculateDistance(
      position.target.latitude,
      position.target.longitude,
      _userLocation!.latitude,
      _userLocation!.longitude,
    );

    // Show button if moved away from location OR zoomed out/in significantly
    bool movedAway = distance > 0.0005;
    bool zoomedAway = position.zoom < 15.0 || position.zoom > 17.5;

    if (movedAway || zoomedAway) {
      if (!_showCenterButton.value) {
        _showCenterButton.value = true;
      }
    } else {
      if (_showCenterButton.value) {
        _showCenterButton.value = false;
      }
    }
  }

  /// Calculate simple distance between two coordinates
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    double dLat = (lat2 - lat1).abs();
    double dLon = (lon2 - lon1).abs();
    return dLat + dLon;
  }

  /// Get combined markers reactively
  /// ✅ OPTIMIZATION: This method is called by GoogleMap, and GetX will automatically
  /// track the observables accessed here, updating only when they change
  Set<Marker> _getCombinedMarkers() {
    final mapServiceMarkers = _mapService.markers;
    final rideMarkers = _backgroundService.rideMarkers;
    return {...mapServiceMarkers, ...rideMarkers};
  }

  /// Get polylines reactively
  /// ✅ OPTIMIZATION: Same as markers - GetX tracks changes automatically
  Set<Polyline> _getPolylines() {
    return _mapService.polylines;
  }

  /// Center map to user location with zoom animation
  Future<void> _centerToUserLocation() async {
    if (_userLocation == null || _mapService.mapController == null) return;

    try {
      // First zoom out
      await _mapService.mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _userLocation!,
            zoom: 14.0,
          ),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 400));

      // Then zoom in
      await _mapService.mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _userLocation!,
            zoom: 17.0,
          ),
        ),
      );

      _showCenterButton.value = false;
    } catch (e) {
      print('❌ SAHAr Error centering to location: $e');
    }
  }

  /// Build ride status widget with proper Obx usage
  Widget _buildRideStatusWidget() {
    return Obx(() {
      final controller = _rideStatusController;
      if (controller == null) {
        return const SizedBox.shrink();
      }

      final status = controller.rideStatus.value;
      final shouldShowGoLive = controller.shouldShowGoLiveButton.value; // Use .value since it's now an observable

      // Debug logging
      print('🔍 SAHAr Ride Status Widget - Status: "$status", ShowGoLive: $shouldShowGoLive');

      // If nothing to show, return empty widget
      if ((status == null || status.isEmpty) && !shouldShowGoLive) {
        print('⚠️ SAHAr Nothing to show - status is empty and shouldShowGoLive is false');
        return const SizedBox.shrink();
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ride Status Badge (only if status exists)
            if (status != null && status.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: status.toLowerCase() == 'available'
                      ? Colors.green.shade100
                      : Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: status.toLowerCase() == 'available'
                        ? Colors.green.shade300
                        : Colors.orange.shade300,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: status.toLowerCase() == 'available'
                            ? Colors.green
                            : Colors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      status,
                      style: TextStyle(
                        color: status.toLowerCase() == 'available'
                            ? Colors.green.shade900
                            : Colors.orange.shade900,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

            // Spacing between badge and button (only if both exist)
            if (status != null && status.isNotEmpty && shouldShowGoLive)
              const SizedBox(width: 8),

            // Go Live Button (show independently if needed)
            if (shouldShowGoLive)
              _buildGoLiveButton(controller),
          ],
        ),
      );
    });
  }

  /// Build Go Live button with separate Obx for loading state
  Widget _buildGoLiveButton(RideStatusController controller) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () {
          if (!controller.isLoading.value) {
            controller.goLive();
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4CAF50), Color(0xFF45a049)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Obx(() {
            final isLoading = controller.isLoading.value;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else
                  const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 18,
                  ),
                const SizedBox(width: 6),
                const Text(
                  'GO LIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildMainInterface(context),
    );
  }

  /// Build main interface
  Widget _buildMainInterface(BuildContext context) {
    var mediaQuery = MediaQuery.of(context);
    var brightness = mediaQuery.platformBrightness;
    final isDarkMode = brightness == Brightness.dark;

    return Stack(
      children: [
        // Google Map - Optimized to avoid full rebuilds
        // ✅ SUPER OPTIMIZATION: Separate Obx for markers and polylines
        // This prevents rebuild when other observables change
        RepaintBoundary(
          child: Obx(() {
            // ✅ GetX will only rebuild this when markers or polylines change
            final combinedMarkers = _getCombinedMarkers();
            final polylines = _getPolylines();

            return GoogleMap(
              mapType: MapType.normal,
              style: (isDarkMode) ? darkMapTheme : lightMapTheme,
              initialCameraPosition: _kGooglePlex,
              myLocationButtonEnabled: false,
              myLocationEnabled: false,
              zoomControlsEnabled: false,
              markers: combinedMarkers,
              polylines: polylines.toSet(), // .toSet() lagane se UI lazmi update hoga
              onMapCreated: (GoogleMapController controller) {
                _mapService.setMapController(controller);
                print('✅ SAHAr Map controller set');
              },
              onCameraMove: _onCameraMove,
            );
          }),
        ),

        // ✅ Status Bar Color Indicator (Uber-like top bar that changes color)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Obx(() {
            final rideStatus = _backgroundService.rideStatus.value;
            final isOnline = rideStatus.toLowerCase() == 'online';

            // Show colored bar only when Online
            if (!isOnline) {
              return const SizedBox.shrink();
            }

            return Container(
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.green.shade400,
                    Colors.green.shade600,
                    Colors.green.shade400,
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withValues(alpha: 0.3),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            );
          }),
        ),

        // Center to Marker Button
        Obx(() => _showCenterButton.value
            ? Positioned(
          bottom: 100,
          right: 16,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: _centerToUserLocation,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF1A2A44),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.my_location,
                  color: Color(0xFF1A2A44),
                  size: 24,
                ),
              ),
            ),
          ),
        )
            : const SizedBox.shrink()),

        // Driver Status Toggle Button (Top Right)
        Positioned(
          top: 40,
          right: 0,
          child: DriverStatusToggle(),
        ),

        // Loading indicator for location
        Positioned(
          top: 100,
          left: 0,
          right: 0,
          child: Obx(() {
            if (_locationService.isLocationLoading.value &&
                _locationService.currentAddress.value.isEmpty) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Getting your location...',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          }),
        ),

        // Ride Details Bottom Sheet
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Obx(() {
            final ride = _backgroundService.currentRide.value;
            if (ride == null) return const SizedBox.shrink();
            return RideWidget(ride: ride);
          }),
        ),
      ],
    );
  }
}
