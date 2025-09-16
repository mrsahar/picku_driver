import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pick_u_driver/core/driver_status_controller.dart';
import 'package:pick_u_driver/core/location_service.dart';
import 'package:pick_u_driver/core/map_service.dart';
import 'package:pick_u_driver/core/permission_service.dart';
import 'package:pick_u_driver/core/signalr_service.dart';
import 'package:pick_u_driver/driver_screen/widget/arrival_destination_widget.dart';
import 'package:pick_u_driver/driver_screen/widget/arriveded_customer_location.dart';
import 'package:pick_u_driver/driver_screen/widget/customer_location.dart';
import 'package:pick_u_driver/driver_screen/widget/finding_job.dart';
import 'package:pick_u_driver/driver_screen/widget/ride_request_sreen.dart';
import 'package:pick_u_driver/utils/map_theme/dark_map_theme.dart';
import 'package:pick_u_driver/utils/map_theme/light_map_theme.dart';

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
  late DriverStatusController _driverStatusController;

  // Map and UI state
  Set<Marker> markers = {};
  static const CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(31.8329711, 70.9028416),
    zoom: 14,
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
      print('SAHArSAHAr Error initializing app: $e');
    }
  }

  /// Initialize controllers and services
  Future<void> _initializeControllers() async {
    try {
      _driverStatusController = Get.put(DriverStatusController());
      await Future.delayed(const Duration(seconds: 1));
      print('SAHArSAHAr Controllers initialized successfully');
    } catch (e) {
      print('SAHArSAHAr Error initializing controllers: $e');
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
            title: 'My Location'
        );

        setState(() {
          markers = _mapService.markers.toSet();
        });
      }
    } catch (e) {
      print('SAHArSAHAr Error showing current location: $e');
    }
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
    final size = MediaQuery.sizeOf(context);
    var brightness = mediaQuery.platformBrightness;
    final isDarkMode = brightness == Brightness.dark;

    final List<Widget> widgets = [
      KeyedSubtree(key: ValueKey(0), child: FindingJob(context)),
      KeyedSubtree(key: ValueKey(1), child: RideRequestScreen(context)),
      KeyedSubtree(key: ValueKey(2), child: CustomerLocation(context)),
      KeyedSubtree(key: ValueKey(3), child: ArrivededCustomerLocation(context)),
      KeyedSubtree(key: ValueKey(4), child: ArrivededDestination(context)),
    ];

    return Stack(
      children: [
        // Google Map
        GoogleMap(
          mapType: MapType.normal,
          style: (isDarkMode) ? darkMapTheme : lightMapTheme,
          initialCameraPosition: _kGooglePlex,
          myLocationButtonEnabled: true,
          myLocationEnabled: false,
          markers: markers,
          onMapCreated: (GoogleMapController controller) {
            _mapService.setMapController(controller);
          },
        ),
        Positioned(
          bottom: 120,
          right: 0,
          child: DriverStatusToggle(),
        ),
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

                  // Toggle Widget Button
                  IconButton(
                    icon: const Icon(Icons.swap_horiz),
                    onPressed: toggleLocationWidget,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.9),
                      foregroundColor: Colors.blue,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Ride Status Indicator (Center Top)
        Positioned(
          top: 90,
          left: 0,
          right: 0,
          child: Obx(() {
            if (_signalRService.currentRideId.value.isEmpty) {
              return const SizedBox.shrink();
            } else {
              String rideId = _signalRService.currentRideId.value;
              String shortRideId = rideId.length > 8 ? rideId.substring(0, 8) : rideId;

              return Container(
                alignment: Alignment.center,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.directions_car,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Active Ride: $shortRideId...',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
          }),
        ),
        // Bottom Sliding Panels
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            transitionBuilder: (child, animation) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 1.0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              );
            },
            child: widgets[isWidget],
          ),
        ),
      ],
    );
  }

  /// Toggle between different UI widgets
  void toggleLocationWidget() {
    setState(() {
      isWidget = (isWidget + 1) % 5;
    });
  }

  @override
  void dispose() {
    _driverStatusController.dispose();
    super.dispose();
  }
}


