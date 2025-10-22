import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pick_u_driver/core/google_directions_service.dart';
import 'package:pick_u_driver/models/location_model.dart';
import 'package:pick_u_driver/utils/theme/mcolors.dart';

class MapService extends GetxService {
  static MapService get to => Get.find();

  // Observable variables
  var markers = <Marker>{}.obs;
  var polylines = <Polyline>{}.obs;
  var isLoadingRoute = false.obs;
  var routeDistance = ''.obs;
  var routeDuration = ''.obs;
  final List<LatLng> _interpolationPoints = [];
  int _interpolationIndex = 0;

  GoogleMapController? mapController;

  // Custom marker icons
  BitmapDescriptor? _userMarkerIcon;
  BitmapDescriptor? driverMarkerIcon;
  BitmapDescriptor? _pointsMarkerIcon;

  // Driver animation variables with route following
  List<LatLng> _currentRoutePolyline = [];
  int currentPolylineIndex = 0;
  LatLng? previousDriverLocation;
  Timer? _animationTimer;
  final int animationSteps = 120;
  int currentAnimationStep = 0;
  bool isAnimating = false;

  // User location animation variables
  LatLng? _previousUserLocation;
  Timer? _userAnimationTimer;
  final int _userAnimationSteps = 120;
  int _currentUserAnimationStep = 0;
  bool _isUserAnimating = false;
  final List<LatLng> _userInterpolationPoints = [];

  @override
  void onInit() {
    super.onInit();
    _initializeCustomMarkers();
  }

  /// Initialize custom marker icons
  Future<void> _initializeCustomMarkers() async {
    try {
      print('🚗 SAHAr Loading custom marker icons...');

      // Use taxi.png for user location marker
      _userMarkerIcon = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(30, 58)),
        'assets/img/taxi.png',
      );
      print('✅ SAHAr User marker icon loaded successfully');

      driverMarkerIcon = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(30, 58)),
        'assets/img/taxi.png',
      );
      print('✅ SAHAr Driver marker icon loaded successfully');

      _pointsMarkerIcon = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/img/points.png',
      );
      print('✅ SAHAr Points marker icon loaded successfully');
    } catch (e) {
      print('❌ SAHAr Error loading custom marker icons: $e');
      print('⚠️ SAHAr Will use default markers as fallback');
    }
  }

  void setMapController(GoogleMapController controller) {
    mapController = controller;
  }

  /// Create route markers and polylines
  Future<void> createRouteMarkersAndPolylines({
    required LocationData? pickupLocation,
    required LocationData? dropoffLocation,
    required List<LocationData> additionalStops,
  }) async {
    if (_pointsMarkerIcon == null) {
      await _initializeCustomMarkers();
    }

    markers.clear();
    polylines.clear();
    isLoadingRoute.value = true;

    try {
      List<LatLng> routePoints = [];
      List<LatLng> waypoints = [];

      // Pickup marker
      if (pickupLocation != null) {
        LatLng pickupLatLng = LatLng(pickupLocation.latitude, pickupLocation.longitude);
        markers.add(Marker(
          markerId: const MarkerId('pickup'),
          position: pickupLatLng,
          icon: _pointsMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(230.0),
          infoWindow: InfoWindow(title: 'Pickup Location', snippet: pickupLocation.address),
        ));
        routePoints.add(pickupLatLng);
      }

      // Stops
      for (int i = 0; i < additionalStops.length; i++) {
        final stop = additionalStops[i];
        if (stop.address.isNotEmpty && stop.latitude != 0 && stop.longitude != 0) {
          LatLng stopLatLng = LatLng(stop.latitude, stop.longitude);
          markers.add(Marker(
            markerId: MarkerId('stop_$i'),
            position: stopLatLng,
            icon: _pointsMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(230.0),
            infoWindow: InfoWindow(title: 'Stop ${i + 1}', snippet: stop.address),
          ));
          waypoints.add(stopLatLng);
          routePoints.add(stopLatLng);
        }
      }

      // Dropoff
      LatLng? dropoffLatLng;
      if (dropoffLocation != null) {
        dropoffLatLng = LatLng(dropoffLocation.latitude, dropoffLocation.longitude);
        markers.add(Marker(
          markerId: const MarkerId('dropoff'),
          position: dropoffLatLng,
          icon: _pointsMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(230.0),
          infoWindow: InfoWindow(title: 'Dropoff Location', snippet: dropoffLocation.address),
        ));
        routePoints.add(dropoffLatLng);
      }

      if (routePoints.length >= 2 && dropoffLatLng != null) {
        await _createRoutePolylines(routePoints, waypoints, dropoffLatLng);
      }
    } catch (e) {
      print('❌ SAHAr Error creating route markers and polylines: $e');
      Get.snackbar('Route Error', 'Failed to create route visualization');
    } finally {
      isLoadingRoute.value = false;
    }
  }

  /// Create route polylines using Directions API
  Future<void> _createRoutePolylines(
      List<LatLng> routePoints, List<LatLng> waypoints, LatLng destination) async {
    try {
      LatLng origin = routePoints.first;
      List<LatLng> routeCoordinates = await GoogleDirectionsService.getRoutePoints(
        origin: origin,
        destination: destination,
        waypoints: waypoints,
      );

      _currentRoutePolyline = routeCoordinates;
      currentPolylineIndex = 0;

      Map<String, dynamic> routeInfo = await GoogleDirectionsService.getRouteInfo(
        origin: origin,
        destination: destination,
        waypoints: waypoints,
      );

      routeDistance.value = routeInfo['distance'];
      routeDuration.value = routeInfo['duration'];

      if (routeInfo['status'] == 'OK') {
        polylines.add(Polyline(
          polylineId: const PolylineId('main_route'),
          points: routeCoordinates,
          color: MColor.primaryNavy,
          width: 5,
        ));
      } else {
        await _createSegmentRoutes(routePoints);
      }
    } catch (e) {
      print('❌ SAHAr Error creating route polylines: $e');
      await _createFallbackPolylines(routePoints);
    }
  }

  /// Create segment-by-segment routes as fallback
  Future<void> _createSegmentRoutes(List<LatLng> routePoints) async {
    for (int i = 0; i < routePoints.length - 1; i++) {
      try {
        List<LatLng> segmentPoints = await GoogleDirectionsService.getRoutePoints(
          origin: routePoints[i],
          destination: routePoints[i + 1],
        );

        Color segmentColor = i == 0 ? MColor.primaryNavy : MColor.primaryNavy.withValues(alpha: 0.7);
        List<PatternItem> patterns = i == 0 ? [] : [PatternItem.dash(10), PatternItem.gap(5)];

        polylines.add(Polyline(
          polylineId: PolylineId('segment_$i'),
          points: segmentPoints,
          color: segmentColor,
          width: 4,
          patterns: patterns,
        ));
      } catch (e) {
        print('❌ SAHAr Error creating segment $i: $e');
        _createFallbackSegment(routePoints[i], routePoints[i + 1], i);
      }
    }
  }

  /// Create fallback straight line polylines
  Future<void> _createFallbackPolylines(List<LatLng> routePoints) async {
    for (int i = 0; i < routePoints.length - 1; i++) {
      _createFallbackSegment(routePoints[i], routePoints[i + 1], i);
    }
    routeDistance.value = 'Estimated';
    routeDuration.value = 'N/A';
  }

  /// Create a straight line segment as fallback
  void _createFallbackSegment(LatLng start, LatLng end, int index) {
    List<LatLng> segmentPoints = [];
    int segments = 20;

    for (int j = 0; j <= segments; j++) {
      double ratio = j / segments;
      double lat = start.latitude + (end.latitude - start.latitude) * ratio;
      double lng = start.longitude + (end.longitude - start.longitude) * ratio;
      segmentPoints.add(LatLng(lat, lng));
    }

    Color segmentColor = index == 0 ? Colors.blue : Colors.orange;

    polylines.add(Polyline(
      polylineId: PolylineId('fallback_segment_$index'),
      points: segmentPoints,
      color: segmentColor,
      width: 4,
      patterns: index == 0 ? [] : [PatternItem.dash(10), PatternItem.gap(5)],
    ));
  }

  /// Update user location marker with smooth animation and rotation
  void updateUserLocationMarker(double lat, double lng, {String title = 'Your Location', bool centerMap = false}) {
    final newLocation = LatLng(lat, lng);

    print('📍 SAHAr Updating user location: $lat, $lng');
    print('🚗 SAHAr User marker icon available: ${_userMarkerIcon != null}');

    // Always create/update the marker immediately for first location
    if (_previousUserLocation == null) {
      double bearing = _getBearingForLocation(newLocation);
      _createUserMarker(newLocation, title, bearing);
      _previousUserLocation = newLocation;

      // Center map on first user location if requested
      if (centerMap) {
        Future.delayed(const Duration(milliseconds: 500), () {
          animateToLocation(newLocation, zoom: 16.0);
        });
      }

      print('✅ SAHAr First user marker created at: $lat, $lng');
      return;
    }

    // For subsequent updates, animate if location changed
    if (_previousUserLocation != newLocation) {
      if (centerMap) {
        animateToLocation(newLocation, zoom: 16.0);
      }

      // Use route-following animation for movement
      _startUserAnimationWithRouteFollowing(_previousUserLocation!, newLocation, title);
      _previousUserLocation = newLocation;
    } else {
      // Same location, just ensure marker exists
      double bearing = _getBearingForLocation(newLocation);
      _createUserMarker(newLocation, title, bearing);
    }
  }

  /// Start smooth animation for user marker with route-following rotation
  void _startUserAnimationWithRouteFollowing(LatLng fromLocation, LatLng toLocation, String title) {
    if (_userAnimationTimer?.isActive ?? false) {
      _userAnimationTimer?.cancel();
    }

    _isUserAnimating = true;
    _currentUserAnimationStep = 0;

    // Create interpolation points for ultra-smooth movement
    _createUserInterpolationPoints(fromLocation, toLocation);

    // Higher frequency timer for smoother animation (16ms ≈ 60fps)
    _userAnimationTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      _currentUserAnimationStep++;

      double progress = _currentUserAnimationStep / _userAnimationSteps;
      double easedProgress = _easeInOutQuint(progress);

      LatLng currentPosition = _getUserInterpolatedPosition(easedProgress);
      double bearing = _getSmoothUserBearing(fromLocation, toLocation, easedProgress);

      _createUserMarkerWithRotation(currentPosition, title, bearing);

      if (_currentUserAnimationStep >= _userAnimationSteps) {
        timer.cancel();
        _isUserAnimating = false;

        double finalBearing = _getBearingForLocation(toLocation);
        _createUserMarkerWithRotation(toLocation, title, finalBearing);

        print('✅ SAHAr Ultra-smooth user animation completed');
      }
    });
  }

  /// Create interpolation points for user marker
  void _createUserInterpolationPoints(LatLng from, LatLng to) {
    _userInterpolationPoints.clear();

    int numPoints = 100;

    for (int i = 0; i <= numPoints; i++) {
      double t = i / numPoints;
      double smoothT = _smoothStep(t);

      double lat = from.latitude + (to.latitude - from.latitude) * smoothT;
      double lng = from.longitude + (to.longitude - from.longitude) * smoothT;

      _userInterpolationPoints.add(LatLng(lat, lng));
    }
  }

  /// Get interpolated position for user marker
  LatLng _getUserInterpolatedPosition(double progress) {
    if (_userInterpolationPoints.isEmpty) {
      return _previousUserLocation ?? LatLng(0, 0);
    }

    int index = (progress * (_userInterpolationPoints.length - 1)).round();
    index = index.clamp(0, _userInterpolationPoints.length - 1);

    return _userInterpolationPoints[index];
  }

  /// Get smooth bearing for user marker
  double _getSmoothUserBearing(LatLng from, LatLng to, double progress) {
    if (_currentRoutePolyline.isNotEmpty) {
      LatLng currentPos = _getUserInterpolatedPosition(progress);
      return _getBearingForLocation(currentPos);
    }

    return _calculateBearingBetweenPoints(from, to);
  }

  /// Get bearing for a location based on the route polyline
  double _getBearingForLocation(LatLng location) {
    if (_currentRoutePolyline.isEmpty) {
      return 0.0; // Default bearing (north)
    }

    // Find the closest point on the route polyline
    int closestIndex = _findClosestPolylineIndex(location);

    // Get bearing from the road direction at this point
    return _getRoadBearingAtIndex(closestIndex);
  }

  /// Find the closest point on the route polyline
  int _findClosestPolylineIndex(LatLng location) {
    if (_currentRoutePolyline.isEmpty) return 0;

    double minDistance = double.infinity;
    int closestIndex = 0;

    for (int i = 0; i < _currentRoutePolyline.length; i++) {
      double distance = _calculateDistanceBetweenPoints(location, _currentRoutePolyline[i]);
      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
      }
    }

    return closestIndex;
  }

  /// Get road bearing at a specific polyline index
  double _getRoadBearingAtIndex(int index) {
    if (_currentRoutePolyline.length < 2) return 0.0;

    // Use next point for forward direction, or previous point if at end
    LatLng currentPoint = _currentRoutePolyline[index];
    LatLng targetPoint;

    if (index < _currentRoutePolyline.length - 1) {
      // Look ahead
      targetPoint = _currentRoutePolyline[index + 1];
    } else if (index > 0) {
      // Look back (we're at the end)
      LatLng previousPoint = _currentRoutePolyline[index - 1];
      targetPoint = currentPoint;
      currentPoint = previousPoint;
    } else {
      return 0.0;
    }

    return _calculateBearingBetweenPoints(currentPoint, targetPoint);
  }

  /// Calculate bearing between two points
  double _calculateBearingBetweenPoints(LatLng start, LatLng end) {
    double lat1Rad = start.latitude * (math.pi / 180);
    double lat2Rad = end.latitude * (math.pi / 180);
    double deltaLonRad = (end.longitude - start.longitude) * (math.pi / 180);

    double y = math.sin(deltaLonRad) * math.cos(lat2Rad);
    double x = math.cos(lat1Rad) * math.sin(lat2Rad) -
        math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(deltaLonRad);

    double bearingRad = math.atan2(y, x);
    double bearingDeg = bearingRad * (180 / math.pi);

    // Normalize to 0-360 degrees
    return (bearingDeg + 360) % 360;
  }

  /// Calculate distance between two points in meters
  double _calculateDistanceBetweenPoints(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // Earth's radius in meters

    double lat1Rad = point1.latitude * (math.pi / 180);
    double lat2Rad = point2.latitude * (math.pi / 180);
    double deltaLatRad = (point2.latitude - point1.latitude) * (math.pi / 180);
    double deltaLonRad = (point2.longitude - point1.longitude) * (math.pi / 180);

    double a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
            math.sin(deltaLonRad / 2) * math.sin(deltaLonRad / 2);
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  /// Easing function for smooth animation
  double _easeInOutQuint(double t) {
    return t < 0.5
        ? 16 * t * t * t * t * t
        : 1 - math.pow(-2 * t + 2, 5) / 2;
  }

  /// Smooth step function
  double _smoothStep(double t) {
    return t * t * (3.0 - 2.0 * t);
  }

  /// Create user marker with rotation
  void _createUserMarkerWithRotation(LatLng position, String title, double rotation) {
    final userMarker = Marker(
      markerId: const MarkerId('user_location'),
      position: position,
      rotation: rotation,
      infoWindow: InfoWindow(
        title: title,
        snippet: 'Current location',
      ),
      icon: _userMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      anchor: const Offset(0.5, 0.5), // Center the rotation
    );

    // Remove existing user marker and add new one
    markers.removeWhere((marker) => marker.markerId.value == 'user_location');
    markers.add(userMarker);
  }

  /// Create simple user marker without animation
  void _createUserMarker(LatLng position, String title, double bearing) {
    final userMarker = Marker(
      markerId: const MarkerId('user_location'),
      position: position,
      rotation: bearing,
      infoWindow: InfoWindow(
        title: title,
        snippet: 'Current location',
      ),
      icon: _userMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      anchor: const Offset(0.5, 0.5),
    );

    markers.removeWhere((marker) => marker.markerId.value == 'user_location');
    markers.add(userMarker);
  }

  /// Animate camera to specific location
  Future<void> animateToLocation(LatLng location, {double zoom = 16.0}) async {
    if (mapController == null) return;

    try {
      await mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: location, zoom: zoom),
        ),
      );
    } catch (e) {
      print('❌ SAHAr Error animating to location: $e');
    }
  }

  /// Simplified: Clear map
  void clearMap() {
    _animationTimer?.cancel();
    _userAnimationTimer?.cancel();
    isAnimating = false;
    _isUserAnimating = false;
    previousDriverLocation = null;
    _previousUserLocation = null;
    currentAnimationStep = 0;
    _currentUserAnimationStep = 0;
    driverMarkerIcon = null;
    _pointsMarkerIcon = null;
    _interpolationPoints.clear();
    _userInterpolationPoints.clear();
    _interpolationIndex = 0;
    _currentRoutePolyline.clear();
    currentPolylineIndex = 0;
    markers.clear();
    polylines.clear();
    routeDistance.value = '';
    routeDuration.value = '';
  }

  @override
  void onClose() {
    _animationTimer?.cancel();
    _userAnimationTimer?.cancel();
    super.onClose();
  }
}

