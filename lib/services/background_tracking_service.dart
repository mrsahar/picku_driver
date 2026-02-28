import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:get/get.dart';
import 'package:pick_u_driver/core/background_tracking_service.dart' as core;

class RideAssignment {
  final String rideId;
  RideAssignment(this.rideId);
}

void _showCompletedRide(RideAssignment ride) {
  // Implementation for showing completed ride UI
}

/// Resets ride UI state: clears current ride, route, markers, payment flags,
/// and animates camera back to driver position (bearing North).
void _resetRide() {
  if (Get.isRegistered<core.BackgroundTrackingService>()) {
    core.BackgroundTrackingService.to.resetRide();
  }
}

/// Public method to trigger the completed flow from outside
void triggerCompletedFlow(RideAssignment ride) {
  print('🏁 SAHAr [BG] triggerCompletedFlow called for ride: ${ride.rideId}');

  // 1. Tell the background isolate the ride is done
  final service = FlutterBackgroundService();
  service.invoke('stopTracking');

  // 2. Handle the UI logic (Popups, etc.)
  _showCompletedRide(ride);
}

/// Public method to reset ride after a driver-initiated cancellation
void triggerCancelledFlow() {
  print('🚫 SAHAr [BG] triggerCancelledFlow called - resetting ride');

  // 1. Tell the background isolate to clear the current ride ID
  final service = FlutterBackgroundService();
  service.invoke('updateRideId', {'rideId': ''});

  // 2. Reset UI state
  _resetRide();
}
