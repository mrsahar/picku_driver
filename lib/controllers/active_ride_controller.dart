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
          return;
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
      _navigateToHome();

    } catch (e) {
      print(' SAHAr ActiveRideController: Error checking for active ride: $e');
      // On error, proceed to home screen normally
      _navigateToHome();
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
  void _handleRideContinuation(RideAssignment activeRide) {
    try {
      print(' SAHAr ActiveRideController: User chose to continue with active ride');

      // Pass ride data to BackgroundTrackingService
      _backgroundService.resumeActiveRide(activeRide);

      // Navigate to home screen
      _navigateToHome();

    } catch (e) {
      print(' SAHAr ActiveRideController: Error handling ride continuation: $e');
      Get.snackbar(
        'Error',
        'Failed to resume active ride. Please try again.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// Handle when user chooses not to continue with the active ride
  void _handleRideRejection() {
    print(' SAHAr ActiveRideController: User chose not to continue with active ride');

    // Navigate to home screen without resuming ride
    _navigateToHome();

    Get.snackbar(
      'Info',
      'You can start a new ride session.',
      backgroundColor: Colors.blue,
      colorText: Colors.white,
    );
  }

  /// Navigate to home screen
  void _navigateToHome() {
    Get.offAllNamed(AppRoutes.HOME);
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

            // Create a properly mapped ride object
            final mappedRide = {
              'rideId': rideData['rideId'] ?? 'Unknown',
              'rideType': rideData['rideType'] ?? 'standard',
              'fareEstimate': rideData['fareEstimate'],
              'fareFinal': rideData['fareFinal'] ?? rideData['fareEstimate'] ?? 0.0,
              'createdAt': rideData['createdAt'] ?? DateTime.now().toIso8601String(),
              'status': rideData['status'] ?? 'Unknown',
              'passengerId': rideData['passengerId'] ?? '',
              'passengerName': rideData['passengerName'] ?? 'Unknown', // This might be missing from API
              'passengerPhone': rideData['passengerPhone'] ?? '',
              'pickupLocation': rideData['pickupLocation'] ?? '',
              'pickUpLat': rideData['pickupLat'] ?? 0.0,
              'pickUpLon': rideData['pickupLng'] ?? 0.0, // Note: API uses 'pickupLng'
              'dropoffLocation': rideData['dropOffLocation'] ?? '',
              'dropoffLat': rideData['dropOffLat'] ?? 0.0,
              'dropoffLon': rideData['dropOffLng'] ?? 0.0, // Note: API uses 'dropOffLng'
              'stops': rideData['rideStops'] ?? [], // Note: API uses 'rideStops'
              'passengerCount': rideData['passengerCount'] ?? 1,
              'payment': rideData['payment'],
              'tip': rideData['tip'],
            };

            final rideAssignment = RideAssignment.fromJson(mappedRide);
            print(' SAHAr SAHAr: Successfully mapped single ride from API response');
            return [rideAssignment];
          } catch (e) {
            print(' SAHAr SAHAr: Error mapping ride data: $e');
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
