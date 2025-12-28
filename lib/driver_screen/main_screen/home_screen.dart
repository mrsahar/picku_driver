import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pick_u_driver/controllers/ride_controller.dart';
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

  // Map and UI state
  static const CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(31.8329711, 70.9028416),
    zoom: 16,
  );

  // Track if user moved away from their location
  final RxBool _showCenterButton = false.obs;
  LatLng? _userLocation;

  // Track if initial location has been set
  bool _hasInitialLocationBeenSet = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
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
      await Future.delayed(const Duration(seconds: 1));
      print('✅ SAHAr Controllers initialized');
    } catch (e) {
      print('❌ SAHAr Error initializing controllers: $e');
    }
  }

  /// Show current location on map
  Future<void> _showCurrentLocationOnMap() async {
    try {
      await _locationService.getCurrentLocation();

      if (_locationService.currentLatLng.value != null) {
        LatLng currentLocation = _locationService.currentLatLng.value!;
        _userLocation = currentLocation;

        _mapService.updateUserLocationMarker(
          currentLocation.latitude,
          currentLocation.longitude,
          title: 'My Location',
        );

        // Center map on first location
        if (!_hasInitialLocationBeenSet) {
          await _centerMapToLocation(currentLocation, zoom: 17.0);
          _hasInitialLocationBeenSet = true;
          print('✅ SAHAr First location set and map centered');
        }

        setState(() {});
      }
    } catch (e) {
      print('❌ SAHAr Error showing current location: $e');
    }
  }

  /// Setup location listener for continuous updates
  void _setupLocationListener() {
    // Listen to location changes
    ever(_locationService.currentLatLng, (LatLng? newLocation) {
      if (newLocation != null) {
        print('📍 SAHAr Location updated: $newLocation');

        // Update user location marker with smooth animation
        _mapService.updateUserLocationMarker(
          newLocation.latitude,
          newLocation.longitude,
          title: 'My Location',
          centerMap: false, // Don't auto-center after first time
        );

        // Update stored location
        _userLocation = newLocation;

        // Center map only on first location update
        if (!_hasInitialLocationBeenSet) {
          _centerMapToLocation(newLocation, zoom: 17.0);
          _hasInitialLocationBeenSet = true;
          print('✅ SAHAr First location set via listener');
        }
      }
    });

    // Check if location is already available (in case listener misses initial update)
    if (_locationService.currentLatLng.value != null && !_hasInitialLocationBeenSet) {
      LatLng currentLocation = _locationService.currentLatLng.value!;
      print('📍 SAHAr Location already available: $currentLocation');

      _mapService.updateUserLocationMarker(
        currentLocation.latitude,
        currentLocation.longitude,
        title: 'My Location',
      );

      _userLocation = currentLocation;
      _centerMapToLocation(currentLocation, zoom: 17.0);
      _hasInitialLocationBeenSet = true;
      print('✅ SAHAr Initial location already available and set');
    }
  }

  /// Center map to specific location
  Future<void> _centerMapToLocation(LatLng location, {double zoom = 16.0}) async {
    await _mapService.animateToLocation(location, zoom: zoom);
    print('🎯 SAHAr Map centered to: $location with zoom: $zoom');
  }

  /// Check if camera moved away from user location
  void _onCameraMove(CameraPosition position) {
    if (_userLocation == null) return;

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
            zoom: 16.5,
          ),
        ),
      );

      _showCenterButton.value = false;
    } catch (e) {
      print('❌ SAHAr Error centering to location: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    Get.put(RideController());
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
        // Google Map
        Obx(
              () {
             return GoogleMap(
              mapType: MapType.normal,
              style: (isDarkMode) ? darkMapTheme : lightMapTheme,
              initialCameraPosition: _kGooglePlex,
              myLocationButtonEnabled: false,
              myLocationEnabled: false,
              zoomControlsEnabled: false,
              markers: {
                ..._mapService.markers.toSet(),
                ..._backgroundService.rideMarkers,
              },
              polylines: {
                ..._backgroundService.routePolylines,
              },
              onMapCreated: (GoogleMapController controller) {
                _mapService.setMapController(controller);
                print('✅ SAHAr Map controller set');
              },
              onCameraMove: _onCameraMove,
            );
          },
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

  @override
  void dispose() {
    _driverStatusController.dispose();
    super.dispose();
  }
}
