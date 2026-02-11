import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_polyline_algorithm/google_polyline_algorithm.dart';
import 'package:http/http.dart' as http;

class GoogleDirectionsService {
  static const String _apiKey =
      'AIzaSyBrRRqr91A35j6PxUhjNRn4UucULfwMOiQ'; // Replace with your actual API key
  static const String _baseUrl =
      'https://maps.googleapis.com/maps/api/directions/json';

  /// Get route points between origin and destination using Google Directions API
  ///
  /// [useStraightLineOnError]:
  /// - true  => returns a synthetic straight-line polyline between origin/destination when
  ///            the Directions API fails (useful for initial route planning when no prior
  ///            route exists).
  /// - false => returns an empty list on error so callers can decide whether to keep the
  ///            existing polyline (recommended for live route updates from BackgroundTrackingService).
  static Future<List<LatLng>> getRoutePoints({
    required LatLng origin,
    required LatLng destination,
    List<LatLng>? waypoints,
    bool useStraightLineOnError = false,
  }) async {
    try {
      // ✅ CHANGE: Added 'alternatives=false' to ensure only ONE route is returned
      String url =
          '$_baseUrl?origin=${origin.latitude},${origin.longitude}'
          '&destination=${destination.latitude},${destination.longitude}'
          '&alternatives=false'
          '&mode=driving'
          '&key=$_apiKey';

      // Add waypoints if provided (with optimization for shortest route)
      if (waypoints != null && waypoints.isNotEmpty) {
        String waypointsStr = waypoints
            .map((point) => '${point.latitude},${point.longitude}')
            .join('|');
        // optimize:true tells Google to find the shortest route through all waypoints
        url += '&waypoints=optimize:true|$waypointsStr';
      }

      print('🚗 SAHAr Directions API URL: $url');

      final response = await http.get(Uri.parse(url));
      print('🔍 SAHAr Response Status Code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        final status = data['status']?.toString() ?? 'UNKNOWN';
        final routes = data['routes'] as List? ?? [];

        print('🛰️ SAHAr Directions API status: $status, routes count: ${routes.length}');

        if (status == 'OK' && routes.isNotEmpty) {
          // ✅ We select ONLY the first route (index 0) which is the best/shortest
          final route = routes[0];
          final polylinePoints = route['overview_polyline']['points'];

          print(
            '✅ Polyline points received: ${polylinePoints.substring(0, 50)}...',
          );

          // Decode the polyline points
          List<List<num>> decodedPoints = decodePolyline(polylinePoints);
          print('📊 SAHAr Decoded ${decodedPoints.length} route points');

          // Guard against invalid/too-short polylines
          if (decodedPoints.length < 2) {
            print('⚠️ SAHAr Decoded polyline has less than 2 points. Treating as invalid.');
            if (useStraightLineOnError) {
              print('📐 SAHAr Using straight-line fallback due to invalid polyline.');
              return _createStraightLine(origin, destination);
            }
            return [];
          }

          List<LatLng> routeCoordinates = decodedPoints
              .map((point) => LatLng(point[0].toDouble(), point[1].toDouble()))
              .toList();

          print('🗺️ SAHAr First point: ${routeCoordinates.first}');
          print('🏁 SAHAr Last point: ${routeCoordinates.last}');

          print('🛰️ SAHAr Accepted route with ${routeCoordinates.length} points');
          return routeCoordinates;
        } else {
          print('❌ SAHAr Directions API Error: $status');
          if (data['error_message'] != null) {
            print('❌ SAHAr Error message: ${data['error_message']}');
          }
          if (routes.isEmpty) {
            print('❌ SAHAr No routes returned from Directions API.');
          }
        }
      } else {
        print('❌ SAHAr HTTP Error: ${response.statusCode}');
        print('❌ SAHAr Response body: ${response.body}');
      }

      if (useStraightLineOnError) {
        print('⚠️ SAHAr Falling back to straight line (useStraightLineOnError=true)');
        // Fallback to straight line if API fails
        return _createStraightLine(origin, destination);
      }

      print('⚠️ SAHAr Returning empty route (no polyline will be updated).');
      return [];
    } catch (e) {
      print('💥 SAHAr Exception in getRoutePoints: $e');
      if (useStraightLineOnError) {
        print('📐 SAHAr Using straight-line fallback due to exception.');
        // Fallback to straight line
        return _createStraightLine(origin, destination);
      }
      print('⚠️ SAHAr Returning empty route due to exception (no polyline will be updated).');
      return [];
    }
  }

  /// Get route information (distance, duration, etc.)
  static Future<Map<String, dynamic>> getRouteInfo({
    required LatLng origin,
    required LatLng destination,
    List<LatLng>? waypoints,
  }) async {
    try {
      // ✅ CHANGE: Added 'alternatives=false' here too for consistency
      String url =
          '$_baseUrl?origin=${origin.latitude},${origin.longitude}'
          '&destination=${destination.latitude},${destination.longitude}'
          '&alternatives=false'
          '&mode=driving'
          '&key=$_apiKey';

      if (waypoints != null && waypoints.isNotEmpty) {
        String waypointsStr = waypoints
            .map((point) => '${point.latitude},${point.longitude}')
            .join('|');
        url += '&waypoints=optimize:true|$waypointsStr';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];

          // Calculate total distance and duration
          int totalDistance = 0;
          int totalDuration = 0;

          for (var leg in route['legs']) {
            totalDistance += leg['distance']['value'] as int;
            totalDuration += leg['duration']['value'] as int;
          }

          return {
            'distance': '${(totalDistance / 1000).toStringAsFixed(1)} km',
            'duration': '${(totalDuration / 60).round()} min',
            'distanceValue': totalDistance, // in meters
            'durationValue': totalDuration, // in seconds
            'status': 'OK',
          };
        }
      }

      return {
        'distance': 'Unknown',
        'duration': 'Unknown',
        'distanceValue': 0,
        'durationValue': 0,
        'status': 'ERROR',
      };
    } catch (e) {
      print('❌ SAHAr Error getting route info: $e');
      return {
        'distance': 'Unknown',
        'duration': 'Unknown',
        'distanceValue': 0,
        'durationValue': 0,
        'status': 'ERROR',
      };
    }
  }

  /// Create a simple straight line between two points as fallback
  static List<LatLng> _createStraightLine(LatLng start, LatLng end) {
    print('📐 SAHAr Creating straight line fallback');
    List<LatLng> points = [];

    // Add intermediate points for a smooth line
    int segments = 20;
    for (int i = 0; i <= segments; i++) {
      double ratio = i / segments;
      double lat = start.latitude + (end.latitude - start.latitude) * ratio;
      double lng = start.longitude + (end.longitude - start.longitude) * ratio;
      points.add(LatLng(lat, lng));
    }

    return points;
  }
}
