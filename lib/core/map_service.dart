import 'dart:async';
import 'dart:math' as math;
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pick_u_driver/core/background_tracking_service.dart';
import 'package:pick_u_driver/core/google_directions_service.dart';
import 'package:pick_u_driver/models/location_model.dart';
import 'package:pick_u_driver/utils/theme/mcolors.dart';

class MapService extends GetxService with WidgetsBindingObserver {
  static MapService get to => Get.find();

  // Observables
  var markers = <Marker>{}.obs;
  var polylines = <Polyline>{}.obs;
  var isLoadingRoute = false.obs;
  var routeDistance = ''.obs;
  var routeDuration = ''.obs;

  GoogleMapController? mapController;

  // Icons
  BitmapDescriptor? _driverIcon;
  BitmapDescriptor? _pointsIcon;

  // Animation Variables
  LatLng? _lastPosition;
  Timer? _animationTimer;
  final int _animationSteps = 60; // 60 steps for 1 second @ 60fps approx
  bool _isAppInForeground = true;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _loadCustomMarkers();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasInForeground = _isAppInForeground;
    _isAppInForeground = state == AppLifecycleState.resumed;
    
    if (!_isAppInForeground && wasInForeground) {
      // App going to background - stop animation
      _animationTimer?.cancel();
      print('🛑 MapService: Animation stopped (app in background)');
    } else if (_isAppInForeground && !wasInForeground) {
      // App returning to foreground
      print('▶️ MapService: App returned to foreground');

      // When app returns to foreground, ensure BackgroundTrackingService
      // connection + subscription are restored (helps after screen lock).
      try {
        if (Get.isRegistered<BackgroundTrackingService>()) {
          final bg = BackgroundTrackingService.to;
          if (bg.isRunning.value &&
              (!bg.isConnected.value || !bg.isSubscribed.value)) {
            print('🔄 MapService: Background service running but connection/subscription not healthy. Triggering manualReconnect().');
            bg.manualReconnect();
          }
        }
      } catch (e) {
        print('⚠️ MapService: Error checking BackgroundTrackingService on resume: $e');
      }
    }
  }

  void setMapController(GoogleMapController controller) {
    mapController = controller;
  }

  Future<void> _loadCustomMarkers() async {
    try {
      _driverIcon = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(30, 58)),
        'assets/img/taxi.png',
      );
      _pointsIcon = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/img/points.png',
      );
    } catch (e) {
      print('⚠️ Icons load error: $e');
    }
  }

  /// 1. Create Route with Multiple Stops & Auto-Fit Camera
  Future<void> createRouteWithStops({
    required LocationData? pickup,
    required LocationData? dropoff,
    required List<LocationData> additionalStops,
  }) async {
    if (pickup == null || dropoff == null) return;

    isLoadingRoute.value = true;
    markers.clear();
    polylines.clear();

    try {
      List<LatLng> waypoints = [];
      LatLng origin = LatLng(pickup.latitude, pickup.longitude);
      LatLng destination = LatLng(dropoff.latitude, dropoff.longitude);

      _addPointMarker('pickup', origin, 'Pickup', pickup.address);

      for (int i = 0; i < additionalStops.length; i++) {
        final stop = additionalStops[i];
        if (stop.latitude != 0) {
          LatLng stopPos = LatLng(stop.latitude, stop.longitude);
          waypoints.add(stopPos);
          _addPointMarker('stop_$i', stopPos, 'Stop ${i + 1}', stop.address);
        }
      }

      _addPointMarker('dropoff', destination, 'Dropoff', dropoff.address);

      // Directions API Call
      List<LatLng> routePoints = await GoogleDirectionsService.getRoutePoints(
        origin: origin,
        destination: destination,
        waypoints: waypoints,
        // For initial route planning we prefer a straight line over nothing
        // if Directions API fails (no prior polyline exists yet).
        useStraightLineOnError: true,
      );

      Map<String, dynamic> routeInfo = await GoogleDirectionsService.getRouteInfo(
        origin: origin,
        destination: destination,
        waypoints: waypoints,
      );

      routeDistance.value = routeInfo['distance'] ?? '';
      routeDuration.value = routeInfo['duration'] ?? '';

      // ✅ Use assignAll to ensure only ONE polyline exists
      polylines.assignAll({
        Polyline(
          polylineId: const PolylineId('main_route'),
          points: routePoints,
          color: MColor.primaryNavy,
          width: 5,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          geodesic: true,
        ),
      });

      // ✨ Auto-Fit Camera to show full route
      _fitRouteToBounds(routePoints);

    } catch (e) {
      print('❌ Route Error: $e');
    } finally {
      isLoadingRoute.value = false;
      if (_lastPosition != null) _updateMarkerInternal(_lastPosition!, 0);
    }
  }

  // Last bearing to prevent excessive rotation updates
  double? _lastBearing;
  static const double _minBearingChange = 5.0; // Only update if bearing changed >5 degrees

  /// 2. Update Driver with 60FPS Smooth Animation
  void updateDriverMarker(double lat, double lng) {
    final newPosition = LatLng(lat, lng);

    if (_lastPosition == null) {
      _lastPosition = newPosition;
      _lastBearing = 0;
      _updateMarkerInternal(newPosition, 0);
      animateToLocation(newPosition); // Initial camera move
      return;
    }

    if (_lastPosition == newPosition) return;

    double rotation = _calculateBearing(_lastPosition!, newPosition);

    // ✅ Check if app is in background - if so, snap immediately without animation
    if (!_isAppInForeground) {
      _lastBearing = rotation;
      _lastPosition = newPosition;
      _updateMarkerInternal(newPosition, rotation);
      return;
    }

    // ✅ Only update rotation if bearing changed significantly (>5 degrees)
    // This prevents flickering when stationary or moving slowly
    if (_lastBearing == null || (rotation - _lastBearing!).abs() > _minBearingChange) {
      _lastBearing = rotation;
      // ✨ Animation Start (only if app is in foreground)
      _animateMarker(_lastPosition!, newPosition, rotation);
    } else {
      // Position changed but bearing didn't change much - just update position without animation
      _updateMarkerInternal(newPosition, _lastBearing!);
    }

    _lastPosition = newPosition;
  }

  void _animateMarker(LatLng start, LatLng end, double rotation) {
    _animationTimer?.cancel();
    int step = 0;

    // 16ms = ~60 frames per second
    _animationTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      step++;
      double t = step / _animationSteps;

      // Linear interpolation (Lerp)
      double lat = start.latitude + (end.latitude - start.latitude) * t;
      double lng = start.longitude + (end.longitude - start.longitude) * t;

      LatLng currentPos = LatLng(lat, lng);
      _updateMarkerInternal(currentPos, rotation);

      // Har step par camera move karne ki zaroorat nahi (performance issue)
      // Sirf end par ya har 10th step par move kar sakte hain
      if (step % 20 == 0) {
        _moveCameraSmoothly(currentPos, rotation);
      }

      if (step >= _animationSteps) {
        timer.cancel();
      }
    });
  }

  void _updateMarkerInternal(LatLng pos, double rotation) {
    final driver = Marker(
      markerId: const MarkerId('current_location'),
      position: pos,
      rotation: rotation,
      icon: _driverIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      anchor: const Offset(0.5, 0.5),
      zIndexInt: 10,
      flat: true, // Makes the car look 2D on the road
    );

    var updatedSet = Set<Marker>.from(markers);
    updatedSet.removeWhere((m) => m.markerId.value == 'current_location');
    updatedSet.add(driver);
    markers.assignAll(updatedSet);
  }

  /// Camera ko route ke mutabiq fit karna
  void _fitRouteToBounds(List<LatLng> points) {
    if (mapController == null || points.isEmpty) return;

    double minLat = points.map((p) => p.latitude).reduce(math.min);
    double maxLat = points.map((p) => p.latitude).reduce(math.max);
    double minLng = points.map((p) => p.longitude).reduce(math.min);
    double maxLng = points.map((p) => p.longitude).reduce(math.max);

    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  /// Driver ki movement ke saath camera follow
  void _moveCameraSmoothly(LatLng pos, double bearing) {
    mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: pos, zoom: 17, bearing: bearing, tilt: 0), // ✅ Tilt 0 = No 3D view
      ),
    );
  }

  void _addPointMarker(String id, LatLng pos, String title, String snippet) {
    markers.add(Marker(
      markerId: MarkerId(id),
      position: pos,
      icon: _pointsIcon ?? BitmapDescriptor.defaultMarkerWithHue(210.0),
      infoWindow: InfoWindow(title: title, snippet: snippet),
    ));
  }

  double _calculateBearing(LatLng start, LatLng end) {
    double lat1 = start.latitude * math.pi / 180;
    double lng1 = start.longitude * math.pi / 180;
    double lat2 = end.latitude * math.pi / 180;
    double lng2 = end.longitude * math.pi / 180;
    double dLng = lng2 - lng1;
    double y = math.sin(dLng) * math.cos(lat2);
    double x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  Future<void> animateToLocation(LatLng location, {double zoom = 17.0}) async {
    if (mapController == null) return;
    mapController!.animateCamera(CameraUpdate.newLatLng(location));
  }

  /// 3. Dynamically Update Route Polyline Only (Call from Background Service)
  void updateRoutePolyline(List<LatLng> points, {Color? color}) {
    final routeColor = color ?? MColor.primaryNavy;
    if (points.isEmpty) {
      print('⚠️ MapService: Empty points, skipping route update');
      return;
    }

    final polyline = Polyline(
      polylineId: const PolylineId('main_route'), // FIXED ID use karein
      points: points,
      color: routeColor,
      width: 5,
      jointType: JointType.round,
      startCap: Cap.roundCap,
      endCap: Cap.roundCap,
      geodesic: true,
    );

    // ✅ CRITICAL FIX: Use assignAll with single polyline to replace ALL old polylines
    // This ensures only ONE polyline exists at a time
    polylines.assignAll({polyline});
    
    print('✅ MapService: Route polyline updated - ${points.length} points, color: $routeColor');
    print('🧪 MapService: Total Polylines: ${polylines.length} (should be 1)');
    if (polylines.length > 1) {
      print('⚠️ MapService: WARNING - Multiple polylines detected! IDs: ${polylines.map((p) => p.polylineId.value).toList()}');
    }
  }

  void clearMap() {
    _animationTimer?.cancel();
    polylines.clear();
    final driver = markers.firstWhereOrNull((m) => m.markerId.value == 'current_location');
    markers.clear();
    if (driver != null) markers.add(driver);
  }

  @override
  void onClose() {
    _animationTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }
}



