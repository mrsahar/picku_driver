import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DriverService extends GetxService {
  static DriverService get to => Get.find();

  // Reactive variables
  var driverId = RxnString();
  var driverName = RxnString();
  var rideStatus = RxnString();
  var isLoggedIn = false.obs;

  // SharedPreferences keys
  static const String _driverIdKey = 'driver_id';
  static const String _driverNameKey = 'driver_name';
  static const String _rideStatusKey = 'ride_status';
  static const String _isLoggedInKey = 'is_logged_in';

  @override
  Future<void> onInit() async {
    super.onInit();
    await _loadDriverData();
  }

  // Load driver data from SharedPreferences
  Future<void> _loadDriverData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      driverId.value = prefs.getString(_driverIdKey);
      driverName.value = prefs.getString(_driverNameKey);
      rideStatus.value = prefs.getString(_rideStatusKey);
      isLoggedIn.value = prefs.getBool(_isLoggedInKey) ?? false;

      print(' SAHAr Driver data loaded: ID=${driverId.value}, Name=${driverName.value}, RideStatus=${rideStatus.value}');
    } catch (e) {
      print(' SAHAr Error loading driver data: $e');
    }
  }

  // Save driver login data
  Future<bool> saveDriverLogin({
    required String id,
    required String name,
    String? rideStatus,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(_driverIdKey, id);
      await prefs.setString(_driverNameKey, name);
      await prefs.setBool(_isLoggedInKey, true);

      if (rideStatus != null) {
        await prefs.setString(_rideStatusKey, rideStatus);
      }

      // Update reactive variables
      driverId.value = id;
      driverName.value = name;
      this.rideStatus.value = rideStatus;
      isLoggedIn.value = true;

      print(' SAHAr Driver login saved: ID=$id, Name=$name, RideStatus=$rideStatus');
      return true;
    } catch (e) {
      print(' SAHAr Error saving driver login: $e');
      return false;
    }
  }

  // Clear driver data (logout)
  Future<bool> clearDriverData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.remove(_driverIdKey);
      await prefs.remove(_driverNameKey);
      await prefs.remove(_rideStatusKey);
      await prefs.setBool(_isLoggedInKey, false);

      // Clear reactive variables
      driverId.value = null;
      driverName.value = null;
      rideStatus.value = null;
      isLoggedIn.value = false;

      print(' SAHAr Driver data cleared');
      return true;
    } catch (e) {
      print(' SAHAr Error clearing driver data: $e');
      return false;
    }
  }

  // Get driver ID (for backward compatibility)
  String? getDriverID() {
    return driverId.value;
  }

  // Check if driver is logged in
  bool get hasValidDriver => driverId.value != null && driverId.value!.isNotEmpty;

  // Update driver name only
  Future<bool> updateDriverName(String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_driverNameKey, name);

      driverName.value = name;
      return true;
    } catch (e) {
      print(' SAHAr Error updating driver name: $e');
      return false;
    }
  }

  // Update ride status only
  Future<bool> updateRideStatus(String status) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_rideStatusKey, status);

      rideStatus.value = status;
      print(' SAHAr Ride status updated: $status');
      return true;
    } catch (e) {
      print(' SAHAr Error updating ride status: $e');
      return false;
    }
  }
}
