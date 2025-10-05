import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pick_u_driver/controllers/ride_controller.dart';
import 'package:pick_u_driver/core/driver_status_controller.dart';
import 'package:pick_u_driver/core/location_service.dart';
import 'package:pick_u_driver/core/map_service.dart';
import 'package:pick_u_driver/core/permission_service.dart';
import 'package:pick_u_driver/core/signalr_service.dart';
import 'package:pick_u_driver/driver_screen/main_screen/ride_widgets/status_badge.dart';
import 'package:pick_u_driver/utils/map_theme/dark_map_theme.dart';
import 'package:pick_u_driver/utils/map_theme/light_map_theme.dart';

import '../../core/ride_assignment_service.dart';
import 'ride_widgets/ride_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late GoogleMap googleMap;

  // Services and controllers
  final SignalRService _signalRService = SignalRService.to;
  final LocationService _locationService = LocationService.to;
  final MapService _mapService = MapService.to;
  final PermissionService _permissionService = PermissionService.to;
  late RideAssignmentService
  _rideAssignmentService; // Added RideAssignmentService
  late DriverStatusController _driverStatusController;
  // Map and UI state
  Set<Marker> markers = {};
  Set<Polyline> polylines = {}; // Added polylines for routes
  static const CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(31.8329711, 70.9028416),
    zoom: 16,
  );

  bool isShowingLocationWidget = true;
  int isWidget = 0;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  /// Initialize app - only handles business logic
  Future<void> _initializeApp() async {
    try {
      // Just check if permissions are ready
      if (_permissionService.isReady) {
        await _initializeControllers();
        await _showCurrentLocationOnMap();
      }
    } catch (e) {
      print(' SAHAr Error initializing app: $e');
    }
  }

  /// Initialize controllers and services
  Future<void> _initializeControllers() async {
    try {
      _driverStatusController = Get.put(DriverStatusController());
      _rideAssignmentService = Get.put(
        RideAssignmentService(),
      ); // Initialize RideAssignmentService
      await Future.delayed(const Duration(seconds: 1));
      print(' SAHAr Controllers initialized successfully');
    } catch (e) {
      print(' SAHAr Error initializing controllers: $e');
    }
  }

  /// Show current location on map
  Future<void> _showCurrentLocationOnMap() async {
    try {
      await _locationService.getCurrentLocation();

      if (_locationService.currentLatLng.value != null) {
        LatLng currentLocation = _locationService.currentLatLng.value!;

        _mapService.updateUserLocationMarker(
          currentLocation.latitude,
          currentLocation.longitude,
          title: 'My Location',
        );

        setState(() {
          markers = _mapService.markers.toSet();
        });
      }
    } catch (e) {
      print(' SAHAr Error showing current location: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    Get.put(RideController());
    return Scaffold(body: _buildMainInterface(context));
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
              ...markers,
              ..._rideAssignmentService.rideMarkers, // Add ride markers
            },
            polylines: {
              ...polylines,
              ..._rideAssignmentService.routePolylines, // Add ride polylines
            },
            onMapCreated: (GoogleMapController controller) {
              _mapService.setMapController(controller);
            },
          ),
        ),

        Positioned(bottom: 120, right: 0, child: DriverStatusToggle()),

        // Top Status Bar
        Positioned(
          top: 40,
          right: 10,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  // SignalR Connection Status
                  Obx(() {
                    Color statusColor;
                    IconData statusIcon;

                    switch (_signalRService.connectionStatus.value) {
                      case 'Connected':
                        statusColor = Colors.green;
                        statusIcon = Icons.cloud_done;
                        break;
                      case 'Connecting...':
                      case 'Reconnecting...':
                        statusColor = Colors.orange;
                        statusIcon = Icons.cloud_sync;
                        break;
                      default:
                        statusColor = Colors.red;
                        statusIcon = Icons.cloud_off;
                    }

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, color: statusColor, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            _signalRService.connectionStatus.value,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(width: 8),

                  // Ride Assignment Status
                  Obx(() {
                    Color statusColor;
                    IconData statusIcon;

                    switch (_rideAssignmentService.connectionStatus.value) {
                      case 'Connected':
                        statusColor = Colors.blue;
                        statusIcon = Icons.assignment;
                        break;
                      case 'Connecting...':
                      case 'Reconnecting...':
                        statusColor = Colors.orange;
                        statusIcon = Icons.assignment_late;
                        break;
                      default:
                        statusColor = Colors.red;
                        statusIcon = Icons.assignment_turned_in;
                    }

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, color: statusColor, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            _rideAssignmentService.isSubscribed.value
                                ? 'Rides'
                                : 'No Rides',
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(width: 8),
                ],
              ),
            ],
          ),
        ),

        // Ride Status Indicator (Center Top)
        Positioned(
          top: 70,
          left: 0,
          right: 0,
          child: Obx(() {
            final ride = _rideAssignmentService.currentRide.value;
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
                statusIcon = Icons.check_circle;                break;
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
            ;
          }),
        ),

        // Ride Details Bottom Sheet
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Obx(() {
            final ride = _rideAssignmentService.currentRide.value;
            if (ride == null) return const SizedBox.shrink();
              return RideWidget(ride: ride); // Single widget for all states
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
