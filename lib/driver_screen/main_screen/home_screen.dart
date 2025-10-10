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
import 'package:pick_u_driver/driver_screen/main_screen/ride_widgets/status_badge.dart';
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
  late DriverStatusController _driverStatusController;

  // Map and UI state
  static const CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(31.8329711, 70.9028416),
    zoom: 16,
  );

  // Track if user moved away from their location
  final RxBool _showCenterButton = false.obs;
  LatLng? _userLocation;

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
      }
    } catch (e) {
      print('❌ SAHAr Error initializing app: $e');
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

        // Start pulsing animation for user marker
        _mapService.startPulsingUserMarker();

        setState(() {
          // markers = _mapService.markers.toSet();
        });
      }
    } catch (e) {
      print('❌ SAHAr Error showing current location: $e');
    }
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
    // Distance > 0.0005 is roughly ~50 meters
    // Or if zoom level is not between 15 and 17.5
    bool movedAway = distance > 0.0005;
    bool zoomedAway = position.zoom < 15.0 || position.zoom > 17.5;

    if (movedAway || zoomedAway) {
      if (!_showCenterButton.value) {
        _showCenterButton.value = true;
        print('🎯 SAHAr Showing center button - Distance: $distance, Zoom: ${position.zoom}');
      }
    } else {
      if (_showCenterButton.value) {
        _showCenterButton.value = false;
        print('🎯 SAHAr Hiding center button');
      }
    }
  }

  /// Calculate simple distance between two coordinates
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    double dLat = (lat2 - lat1).abs();
    double dLon = (lon2 - lon1).abs();
    return dLat + dLon; // Simple approximation
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

      // Hide the button
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
              () => GoogleMap(
            mapType: MapType.normal,
            style: (isDarkMode) ? darkMapTheme : lightMapTheme,
            initialCameraPosition: _kGooglePlex,
            myLocationButtonEnabled: true,
            myLocationEnabled: false,
            zoomControlsEnabled: false,
            markers: {
              ..._mapService.markers.toSet(), // Reactive markers from map service (includes pulsing animation)
              ..._backgroundService.rideMarkers, // Ride markers from background service
            },
            polylines: {
              ..._backgroundService.routePolylines, // Route polylines from background service
            },
            onMapCreated: (GoogleMapController controller) {
              _mapService.setMapController(controller);
            },
            onCameraMove: _onCameraMove,
          ),
        ),

        // Center to Marker Button (Shows when user moves away)
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.my_location,
                            color: const Color(0xFF1A2A44),
                            size: 24,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            : const SizedBox.shrink()),

        // Ride Status Badge (Center Top)
        Positioned(
          top: 100,
          left: 0,
          right: 0,
          child: Obx(() {
            final ride = _backgroundService.currentRide.value;
            if (ride == null) return const SizedBox.shrink();

            Color statusColor;
            IconData statusIcon;

            switch (ride.status) {
              case 'Waiting':
                statusColor = Colors.orange;
                statusIcon = Icons.schedule;
                break;
              case 'In-Progress':
                statusColor = Colors.blue;
                statusIcon = Icons.directions_car;
                break;
              case 'Completed':
                statusColor = Colors.green;
                statusIcon = Icons.check_circle;
                break;
              default:
                statusColor = Colors.grey;
                statusIcon = Icons.info;
            }

            return Center(
              child: RippleStatusBadge(
                status: ride.status,
                statusColor: statusColor,
                statusIcon: statusIcon,
              ),
            );
          }),
        ),

        // Enhanced Driver Status Toggle Button (Top Right)
        Positioned(
          top: 40,
          right: 0,
          child: DriverStatusToggle(),
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
