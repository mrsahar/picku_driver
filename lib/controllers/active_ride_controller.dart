import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pick_u_driver/core/background_tracking_service.dart';
import 'package:pick_u_driver/core/sharePref.dart';
import 'package:pick_u_driver/models/ride_assignment_model.dart';
import 'package:pick_u_driver/providers/api_provider.dart';
import 'package:pick_u_driver/routes/app_routes.dart';
import 'package:pick_u_driver/utils/theme/mcolors.dart';

class ActiveRideController extends GetxController {
  static ActiveRideController get to => Get.find();
  final ApiProvider _apiProvider = Get.find<ApiProvider>();
  final BackgroundTrackingService _backgroundService = BackgroundTrackingService.to;

  var isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    // Check for active rides when controller initializes
    checkForActiveRide();
  }

  /// Check for active rides and show popup if necessary
  Future<void> checkForActiveRide() async {
    try {
      isLoading.value = true;

      // Get driver ID from shared preferences (await the Future)
      final driverId = await SharedPrefsService.getUserId();
      if (driverId == null || driverId.isEmpty) {
        print(' SAHAr ActiveRideController: Driver ID is empty');
        return;
      }

      print(' SAHAr ActiveRideController: Checking for active rides for driver: $driverId');

      // Get driver's last ride from API
      final rides = await getDriverLastRide(driverId);

      if (rides != null && rides.isNotEmpty) {
        final lastRide = rides.first;

        print(' SAHAr ActiveRideController: Last ride found - Status: ${lastRide.status}, CreatedAt: ${lastRide.createdAt}');

        // Check if the ride is active and recent (created today and within last 5 hours)
        final now = DateTime.now();
        final rideCreatedAt = lastRide.createdAt;
        final today = DateTime(now.year, now.month, now.day);
        final rideDate = DateTime(rideCreatedAt.year, rideCreatedAt.month, rideCreatedAt.day);
        final timeDifferenceInMinutes = now.difference(rideCreatedAt).inMinutes;
        final timeDifferenceInHours = now.difference(rideCreatedAt).inHours;

        print(' SAHAr ActiveRideController: Current time: $now');
        print(' SAHAr ActiveRideController: Ride created at: $rideCreatedAt');
        print(' SAHAr ActiveRideController: Time difference: $timeDifferenceInHours hours ($timeDifferenceInMinutes minutes)');
        print(' SAHAr ActiveRideController: Is same date: ${rideDate.isAtSameMomentAs(today)}');
        print(' SAHAr ActiveRideController: Status check: ${lastRide.status}');

        // Check conditions individually for debugging
        bool isSameDate = rideDate.isAtSameMomentAs(today);
        bool isWithinTimeLimit = timeDifferenceInHours <= 23;
        bool isActiveStatus = lastRide.status != 'Completed';

        print(' SAHAr ActiveRideController: --- Condition Details ---');
        print(' SAHAr ActiveRideController: Same date: $isSameDate');
        print(' SAHAr ActiveRideController: Within 5 hours: $isWithinTimeLimit');
        print(' SAHAr ActiveRideController: Active status (not completed): $isActiveStatus');

        bool isActiveAndRecent = isSameDate && isWithinTimeLimit && isActiveStatus;

        print(' SAHAr ActiveRideController: Final result - isActiveAndRecent: $isActiveAndRecent');

        if (isActiveAndRecent) {
          print(' SAHAr ActiveRideController: ✅ Active ride detected, showing popup');
          _showActiveRideDialog(lastRide);
          return; // Don't navigate, let user handle dialog
        } else {
          print(' SAHAr ActiveRideController: ❌ Ride conditions not met');
          if (!isSameDate) {
            print(' SAHAr ActiveRideController: - Ride is not from today');
          }
          if (!isWithinTimeLimit) {
            print(' SAHAr ActiveRideController: - Ride is older than 5 hours');
          }
          if (!isActiveStatus) {
            print(' SAHAr ActiveRideController: - Ride status is Completed');
          }
        }
      }

      print(' SAHAr ActiveRideController: No active rides found, proceeding to home');
      // No active ride found, proceed to home screen normally
      // Only navigate if we're not already on home screen (e.g., from splash screen)
      _navigateToHomeIfNeeded();

    } catch (e) {
      print(' SAHAr ActiveRideController: Error checking for active ride: $e');
      // On error, proceed to home screen normally
      _navigateToHomeIfNeeded();
    } finally {
      isLoading.value = false;
    }
  }

  /// Show dialog asking user if they want to continue with active ride
  void _showActiveRideDialog(RideAssignment activeRide) {
    Get.dialog(
      AlertDialog(
        title: Text(
          'Active Ride Detected',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: MColor.primaryNavy,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are already in a ride. Do you want to continue?',
              style: TextStyle(
                fontSize: 16,
                color: MColor.primaryNavy,
              ),
            ),
            const SizedBox(height: 16),
            _buildRideInfo('Passenger:', activeRide.passengerName),
            _buildRideInfo('Ride Type:', activeRide.rideType.toUpperCase()),
            _buildRideInfo('Status:', activeRide.status),
            _buildRideInfo('Fare:', '\$${activeRide.displayFare.toStringAsFixed(2)}'),
            if (activeRide.stops.isNotEmpty)
              _buildRideInfo('Pickup:', activeRide.stops.first.location),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () {
              Get.back();
              _handleRideRejection();
            },
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: MColor.primaryNavy),
              foregroundColor: MColor.primaryNavy,
            ),
            child: const Text(
              'No',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              _handleRideContinuation(activeRide);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: MColor.primaryNavy,
              foregroundColor: Colors.white,
            ),
            child: const Text(
              'Yes, Continue',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  /// Build ride information row
  Widget _buildRideInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Handle when user chooses to continue with the active ride
  Future<void> _handleRideContinuation(RideAssignment activeRide) async {
    try {
      print(' SAHAr ActiveRideController: User chose to continue with active ride');

      // Show loading indicator
      Get.dialog(
        const Center(
          child: CircularProgressIndicator(),
        ),
        barrierDismissible: false,
      );

      // Pass ride data to BackgroundTrackingService
      // This will first connect all services, then resume the ride
      await _backgroundService.resumeActiveRide(activeRide);

      // Close loading dialog
      Get.back();

      // Show success message
      Get.snackbar(
        'Success',
        'Active ride resumed successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );

      // Don't navigate - just stay on current screen to avoid map refresh
      // The ride is already resumed in background, polyline will be drawn on existing map
      print(' SAHAr ActiveRideController: Ride resumed without navigation to preserve map state');

    } catch (e, stackTrace) {
      // Close loading dialog if still open
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      print(' SAHAr ActiveRideController: Error handling ride continuation: $e');
      print(' SAHAr ActiveRideController: Stack trace: $stackTrace');
      
      // Show error message
      Get.snackbar(
        'Error',
        'Failed to resume active ride. Please try again.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    }
  }

  /// Handle when user chooses not to continue with the active ride
  void _handleRideRejection() {
    print(' SAHAr ActiveRideController: User chose not to continue with active ride');

    // Just show info message, don't navigate to avoid map refresh
    // User can start a new ride from current screen
    Get.snackbar(
      'Info',
      'You can start a new ride session.',
      backgroundColor: Colors.blue,
      colorText: Colors.white,
    );
  }

  /// Navigate to home screen only if not already there
  void _navigateToHomeIfNeeded() {
    // Check if we're already on the home screen
    final currentRoute = Get.currentRoute;
    print('🧭 SAHAr Current screen: $currentRoute');

    // ✅ FIX: Check for BOTH route variations (/main and /mainmap)
    // This prevents unnecessary navigation when already on home screen
    if (currentRoute != AppRoutes.mainMap &&
        currentRoute != AppRoutes.MainMap &&
        currentRoute != '/main' &&
        currentRoute != '/mainmap') {
      print('➡️ SAHAr Navigating to home screen from: $currentRoute');
      // Use offAllNamed to clear the navigation stack (typically from splash screen)
      Get.offAllNamed(AppRoutes.mainMap);
    } else {
      print('✅ SAHAr Already on home screen ($currentRoute), skipping navigation');
    }
  }
  // Get Driver's Last Ride
  Future<List<RideAssignment>?> getDriverLastRide(String driverId) async {
    try {
      final endpoint = '/api/Ride/get-driver-last-ride?driverId=$driverId';

      print(' SAHAr : endpoint = $endpoint');
      print(' SAHAr : full URL = ${_apiProvider.httpClient.baseUrl}$endpoint');
      print(' SAHAr SAHAr: Getting driver last ride for ID: $driverId');
      final response = await _apiProvider.postData(endpoint, {});

      if (response.isOk && response.body != null) {
        print(' SAHAr SAHAr: Driver last ride response successful');
        print(' SAHAr SAHAr: Response body: ${response.body}');

        // The API returns a single ride object, not a list
        if (response.body is Map<String, dynamic>) {
          try {
            // Map the API response fields to RideAssignment model fields
            final rideData = response.body as Map<String, dynamic>;

            // Convert rideStops to stops format expected by RideStop model
            List<Map<String, dynamic>> stopsList = [];
            if (rideData['rideStops'] != null && rideData['rideStops'] is List) {
              stopsList = (rideData['rideStops'] as List)
                  .map((stop) => <String, dynamic>{
                        'stopOrder': stop['stopOrder'] ?? 0,
                        'location': stop['location'] ?? '',
                        'latitude': stop['latitude'] ?? 0.0,
                        'longitude': stop['longitude'] ?? 0.0,
                      })
                  .toList();
            }

            // Create a properly mapped ride object
            final mappedRide = {
              'rideId': rideData['rideId']?.toString() ?? 'Unknown',
              'rideType': rideData['rideType']?.toString() ?? 'standard',
              'fareEstimate': rideData['fareEstimate'] != null
                  ? (rideData['fareEstimate'] is num
                      ? (rideData['fareEstimate'] as num).toDouble()
                      : double.tryParse(rideData['fareEstimate'].toString()) ?? 0.0)
                  : null,
              'fareFinal': rideData['fareFinal'] != null
                  ? (rideData['fareFinal'] is num
                      ? (rideData['fareFinal'] as num).toDouble()
                      : double.tryParse(rideData['fareFinal'].toString()) ?? 0.0)
                  : (rideData['fareEstimate'] != null
                      ? (rideData['fareEstimate'] is num
                          ? (rideData['fareEstimate'] as num).toDouble()
                          : double.tryParse(rideData['fareEstimate'].toString()) ?? 0.0)
                      : 0.0),
              'createdAt': rideData['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
              'status': rideData['status']?.toString() ?? 'Unknown',
              'passengerId': rideData['passengerId']?.toString() ?? '',
              'passengerName': rideData['passengerName']?.toString() ?? 'Unknown',
              'passengerPhone': rideData['passengerPhone']?.toString() ?? '',
              'pickupLocation': rideData['pickupLocation']?.toString() ?? '',
              'pickUpLat': rideData['pickupLat'] != null
                  ? (rideData['pickupLat'] is num
                      ? (rideData['pickupLat'] as num).toDouble()
                      : double.tryParse(rideData['pickupLat'].toString()) ?? 0.0)
                  : 0.0,
              'pickUpLon': rideData['pickupLng'] != null
                  ? (rideData['pickupLng'] is num
                      ? (rideData['pickupLng'] as num).toDouble()
                      : double.tryParse(rideData['pickupLng'].toString()) ?? 0.0)
                  : 0.0,
              'dropoffLocation': rideData['dropOffLocation']?.toString() ?? '',
              'dropoffLat': rideData['dropOffLat'] != null
                  ? (rideData['dropOffLat'] is num
                      ? (rideData['dropOffLat'] as num).toDouble()
                      : double.tryParse(rideData['dropOffLat'].toString()) ?? 0.0)
                  : 0.0,
              'dropoffLon': rideData['dropOffLng'] != null
                  ? (rideData['dropOffLng'] is num
                      ? (rideData['dropOffLng'] as num).toDouble()
                      : double.tryParse(rideData['dropOffLng'].toString()) ?? 0.0)
                  : 0.0,
              'stops': stopsList,
              'passengerCount': rideData['passengerCount'] != null
                  ? (rideData['passengerCount'] is int
                      ? rideData['passengerCount'] as int
                      : int.tryParse(rideData['passengerCount'].toString()) ?? 1)
                  : 1,
              'payment': rideData['payment']?.toString(),
              'tip': rideData['tip'] != null
                  ? (rideData['tip'] is num
                      ? (rideData['tip'] as num).toDouble()
                      : double.tryParse(rideData['tip'].toString()))
                  : null,
            };

            print(' SAHAr SAHAr: Mapped ride data: $mappedRide');
            final rideAssignment = RideAssignment.fromJson(mappedRide);
            print(' SAHAr SAHAr: Successfully mapped single ride from API response');
            return [rideAssignment];
          } catch (e, stackTrace) {
            print(' SAHAr SAHAr: Error mapping ride data: $e');
            print(' SAHAr SAHAr: Stack trace: $stackTrace');
            return null;
          }
        } else if (response.body is List) {
          // Handle list response (fallback)
          final rideList = (response.body as List)
              .map((ride) => RideAssignment.fromJson(ride))
              .toList();
          print(' SAHAr SAHAr: Parsed ${rideList.length} rides from list');
          return rideList;
        }
      } else {
        print(' SAHAr SAHAr: Driver last ride API failed with status: ${response.statusCode}');
        print(' SAHAr SAHAr: Error message: ${response.statusText}');
      }

      return null;
    } catch (e) {
      print(' SAHAr SAHAr: Exception in getDriverLastRide: $e');
      print(' SAHAr SAHAr: Exception type: ${e.runtimeType}');
      return null;
    }
  }
}
