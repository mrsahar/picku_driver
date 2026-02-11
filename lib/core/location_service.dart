import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:get/get.dart';
import 'package:pick_u_driver/models/location_model.dart';


class LocationService extends GetxService {
  static LocationService get to => Get.find();

  // Observable variables for reactive updates
  var currentPosition = Rx<Position?>(null);
  var currentLatLng = Rx<LatLng?>(null);
  var currentAddress = ''.obs;
  var isLocationLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    await getCurrentLocation();
  }

  Future<bool> requestLocationPermission() async {
    var status = await Permission.location.request();
    return status == PermissionStatus.granted;
  }

  Future<Position?> getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        Get.snackbar('Error', 'Location services are disabled');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          Get.snackbar('Error', 'Location permission denied');
          return null;
        }
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      Get.snackbar('Error', 'Failed to get location: $e');
      return null;
    }
  }

  /// Get current location and update reactive variables
  Future<void> getCurrentLocation() async {
    isLocationLoading.value = true;
    try {
      bool hasPermission = await requestLocationPermission();
      if (!hasPermission) {
        Get.snackbar('Permission Required', 'Location permission is required');
        return;
      }

      Position? position = await getCurrentPosition();
      if (position != null) {
        currentPosition.value = position;
        currentLatLng.value = LatLng(position.latitude, position.longitude);

        String address = await getAddressFromCoordinates(
          position.latitude,
          position.longitude,
        );
        currentAddress.value = address;
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to get current location: $e');
    } finally {
      isLocationLoading.value = false;
    }
  }

  /// Get LocationData object for current location
  LocationData? getCurrentLocationData() {
    if (currentPosition.value == null || currentAddress.value.isEmpty) {
      return null;
    }

    return LocationData(
      address: currentAddress.value,
      latitude: currentPosition.value!.latitude,
      longitude: currentPosition.value!.longitude,
      stopOrder: 0,
    );
  }

  Future<String> getAddressFromCoordinates(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];

        // Build address step by step, ensuring we always have something
        String street = place.street ?? place.thoroughfare ?? place.name ?? '';
        String locality = place.locality ?? place.subLocality ?? '';
        String area = place.administrativeArea ?? place.subAdministrativeArea ?? place.country ?? '';

        // Remove empty parts and join
        List<String> addressParts = [street, locality, area]
            .where((part) => part.isNotEmpty)
            .toList();

        if (addressParts.isNotEmpty) {
          return addressParts.join(', ');
        }
      }
    } catch (e) {
      print(' SAHAr Error getting address: $e');
    }

    // Instead of "Unknown location", return formatted coordinates
    return 'Location: ${lat.toStringAsFixed(4)}°, ${lng.toStringAsFixed(4)}°';
  }

  Future<List<Location>> searchPlaces(String query) async {
    try {
      return await locationFromAddress(query);
    } catch (e) {
      print(' SAHAr Error searching places: $e');
      return [];
    }
  }

  /// Convert Position to LatLng
  LatLng? positionToLatLng(Position? position) {
    if (position == null) return null;
    return LatLng(position.latitude, position.longitude);
  }

  /// Calculate distance between two points
  double calculateDistance(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }

  /// Calculate bearing between two points (for rotation)
  double getBearing(LatLng start, LatLng end) {
    return Geolocator.bearingBetween(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );
  }

  /// Get location stream with optimal settings for background tracking
  Stream<Position> getLocationStream({bool iOSPlatform = false}) {
    // ✅ FIXED: Changed from 0 to 5 meters to prevent excessive updates
    // This prevents map rebuilds every ~16ms when stationary
    final LocationSettings settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 5, // Minimum 5 meters movement required for update
    );

    return Geolocator.getPositionStream(
      locationSettings: settings,
    );
  }

  /// Request background location permissions
  Future<bool> requestBackgroundPermissions() async {
    try {
      // Request location permission first
      var locationStatus = await Permission.location.request();
      if (locationStatus != PermissionStatus.granted) {
        Get.snackbar('Permission Required', 'Location permission is required for tracking');
        return false;
      }

      // Request background location permission (Android 10+)
      if (await Permission.locationAlways.isRestricted ||
          await Permission.locationAlways.isDenied) {
        var backgroundStatus = await Permission.locationAlways.request();
        if (backgroundStatus != PermissionStatus.granted) {
          Get.snackbar('Background Permission',
              'Background location permission helps track rides accurately');
        }
      }

      return true;
    } catch (e) {
      print('❌ Error requesting background permissions: $e');
      return false;
    }
  }

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Get location permission status
  Future<LocationPermission> getPermissionStatus() async {
    return await Geolocator.checkPermission();
  }
}