import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pick_u_driver/core/background_tracking_service.dart';
import 'package:pick_u_driver/models/ride_assignment_model.dart';
import 'package:pick_u_driver/providers/api_provider.dart';
import 'package:pick_u_driver/utils/theme/mcolors.dart';

class RideController extends GetxController {
  final ApiProvider _apiProvider = Get.find<ApiProvider>();

  // Observable variables
  var isOnStop = false.obs;
  var currentTimerSeconds = 0.obs;
  var totalWaitingTimeSeconds = 0.obs;
  var isProcessingRequest = false.obs;
  var isArriving = false.obs;
  var isStartingRide = false.obs;

  Timer? _timer;

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }

  // Format seconds to MM:SS
  String get currentTimerFormatted {
    int minutes = currentTimerSeconds.value ~/ 60;
    int seconds = currentTimerSeconds.value % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // Format total waiting time to MM:SS
  String get totalWaitingTimeFormatted {
    int minutes = totalWaitingTimeSeconds.value ~/ 60;
    int seconds = totalWaitingTimeSeconds.value % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // Start the timer
  void _startTimer() {
    _timer?.cancel();
    currentTimerSeconds.value = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      currentTimerSeconds.value++;
    });
  }

  // Stop the timer and add to total
  void _stopTimer() {
    _timer?.cancel();
    totalWaitingTimeSeconds.value += currentTimerSeconds.value;
    currentTimerSeconds.value = 0;
  }

// SAHAr - Request stop functionality
  Future<void> requestStop(String rideId) async {
    if (isProcessingRequest.value) return;

    try {
      isProcessingRequest.value = true;

      String waitingTime = isOnStop.value ? totalWaitingTimeFormatted : "00:00";
      String status = "OnStop";

      String endpoint = "/api/Ride/add-ride-waiting-time?rideId=$rideId&waitingTime=$waitingTime&status=$status";
      print("SAHAr - RequestStop: Endpoint => $endpoint");

      final response = await _apiProvider.postData(endpoint, {});
      print("SAHAr - RequestStop: Response => ${response.statusCode} ${response.statusText}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        isOnStop.value = true;
        _startTimer();
        print("SAHAr - RequestStop: Timer started");

        Get.snackbar(
          "Stop Requested",
          "Timer started for waiting time",
          colorText: MColor.primaryNavy,
          icon: Icon(Icons.pause_circle_filled, color: MColor.primaryNavy),
        );
      } else {
        print("SAHAr - RequestStop: Failed => ${response.statusText}");
        Get.snackbar(
          "Error",
          "Failed to request stop: ${response.statusText}",
          backgroundColor: Colors.red.withValues(alpha:0.1),
          colorText: Colors.red,
          icon: const Icon(Icons.error, color: Colors.red),
        );
      }
    } catch (e) {
      print("SAHAr - RequestStop: Exception => $e");
      Get.snackbar(
        "Error",
        "Network error: $e",
        backgroundColor: Colors.red.withValues(alpha:0.1),
        colorText: Colors.red,
        icon: const Icon(Icons.error, color: Colors.red),
      );
    } finally {
      isProcessingRequest.value = false;
      print("SAHAr - RequestStop: Processing flag reset");
    }
  }

// SAHAr - Resume ride functionality
  Future<void> resumeRide(String rideId) async {
    if (isProcessingRequest.value) return;

    try {
      isProcessingRequest.value = true;

      _stopTimer();
      print("SAHAr - ResumeRide: Timer stopped");

      String waitingTime = totalWaitingTimeFormatted;
      String status = "In-Progress";

      String endpoint = "/api/Ride/add-ride-waiting-time?rideId=$rideId&waitingTime=$waitingTime&status=$status";
      print("SAHAr - ResumeRide: Endpoint => $endpoint");

      final response = await _apiProvider.postData(endpoint, {});
      print("SAHAr - ResumeRide: Response => ${response.statusCode} ${response.statusText}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        isOnStop.value = false;
        print("SAHAr - ResumeRide: Ride resumed");

        Get.snackbar(
          "Ride Resumed",
          "Total waiting time: $waitingTime",
          backgroundColor: const Color(0xFF1A2A44).withValues(alpha:0.1),
          colorText: const Color(0xFF1A2A44),
          icon: const Icon(Icons.play_circle_filled, color: Color(0xFF1A2A44)),
        );
      } else {
        _startTimer();
        print("SAHAr - ResumeRide: Failed => ${response.statusText}, Timer restarted");

        Get.snackbar(
          "Error",
          "Failed to resume ride: ${response.statusText}",
          backgroundColor: Colors.red.withValues(alpha:0.1),
          colorText: Colors.red,
          icon: const Icon(Icons.error, color: Colors.red),
        );
      }
    } catch (e) {
      _startTimer();
      print("SAHAr - ResumeRide: Exception => $e, Timer restarted");

      Get.snackbar(
        "Error",
        "Network error: $e",
        backgroundColor: Colors.red.withValues(alpha:0.1),
        colorText: Colors.red,
        icon: const Icon(Icons.error, color: Colors.red),
      );
    } finally {
      isProcessingRequest.value = false;
      print("SAHAr - ResumeRide: Processing flag reset");
    }
  }


  // Toggle between stop and resume
  Future<void> toggleRideStatus(String rideId) async {
    if (isOnStop.value) {
      await resumeRide(rideId);
    } else {
      await requestStop(rideId);
    }
  }

  // Mark driver as arrived at pickup location
  Future<void> markAsArrived(String rideId) async {
    if (isArriving.value) return;

    try {
      isArriving.value = true;

      String endpoint = "/api/Ride/$rideId/arrived";
      print("SAHAr - MarkAsArrived: Endpoint => $endpoint");

      final response = await _apiProvider.postData(endpoint, {});
      print("SAHAr - MarkAsArrived: Response => ${response.statusCode} ${response.statusText}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Trigger haptic feedback
        HapticFeedback.mediumImpact();

        print("SAHAr - MarkAsArrived: Successfully marked as arrived");

        // ✅ Immediately update local ride status to "Arrived"
        try {
          final backgroundService = Get.find<BackgroundTrackingService>();
          if (backgroundService.currentRide.value != null) {
            final updatedRide = RideAssignment(
              rideId: backgroundService.currentRide.value!.rideId,
              rideType: backgroundService.currentRide.value!.rideType,
              fareEstimate: backgroundService.currentRide.value!.fareEstimate,
              fareFinal: backgroundService.currentRide.value!.fareFinal,
              createdAt: backgroundService.currentRide.value!.createdAt,
              status: 'Arrived', // ✅ Update status
              passengerId: backgroundService.currentRide.value!.passengerId,
              passengerName: backgroundService.currentRide.value!.passengerName,
              passengerPhone: backgroundService.currentRide.value!.passengerPhone,
              pickupLocation: backgroundService.currentRide.value!.pickupLocation,
              pickUpLat: backgroundService.currentRide.value!.pickUpLat,
              pickUpLon: backgroundService.currentRide.value!.pickUpLon,
              dropoffLocation: backgroundService.currentRide.value!.dropoffLocation,
              dropoffLat: backgroundService.currentRide.value!.dropoffLat,
              dropoffLon: backgroundService.currentRide.value!.dropoffLon,
              stops: backgroundService.currentRide.value!.stops,
              passengerCount: backgroundService.currentRide.value!.passengerCount,
              payment: backgroundService.currentRide.value!.payment,
              tip: backgroundService.currentRide.value!.tip,
            );
            backgroundService.currentRide.value = updatedRide;
            backgroundService.rideStatus.value = 'Arrived';
            print("SAHAr - MarkAsArrived: Local ride status updated to 'Arrived'");
          }
        } catch (e) {
          print("SAHAr - MarkAsArrived: Failed to update local status: $e");
        }

        Get.snackbar(
          "Arrival Confirmed",
          "You have arrived at the pickup location",
          backgroundColor: MColor.primaryNavy.withValues(alpha:0.1),
          colorText: MColor.primaryNavy,
          icon: Icon(Icons.check_circle, color: MColor.primaryNavy),
          duration: const Duration(seconds: 3),
        );
      } else {
        print("SAHAr - MarkAsArrived: Failed => ${response.statusText}");
        Get.snackbar(
          "Error",
          "Failed to mark arrival: ${response.statusText}",
          backgroundColor: Colors.red.withValues(alpha:0.1),
          colorText: Colors.red,
          icon: const Icon(Icons.error, color: Colors.red),
        );
      }
    } catch (e) {
      print("SAHAr - MarkAsArrived: Exception => $e");
      Get.snackbar(
        "Error",
        "Network error: $e",
        backgroundColor: Colors.red.withValues(alpha:0.1),
        colorText: Colors.red,
        icon: const Icon(Icons.error, color: Colors.red),
      );
    } finally {
      isArriving.value = false;
      print("SAHAr - MarkAsArrived: Processing flag reset");
    }
  }

  // Start the ride after arriving at pickup location
  Future<void> startRide(String rideId) async {
    if (isStartingRide.value) return;

    try {
      isStartingRide.value = true;

      String endpoint = "/api/Ride/$rideId/start";
      print("SAHAr - StartRide: Endpoint => $endpoint");

      final response = await _apiProvider.postData(endpoint, {});
      print("SAHAr - StartRide: Response => ${response.statusCode} ${response.statusText}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Trigger haptic feedback
        HapticFeedback.mediumImpact();

        print("SAHAr - StartRide: Successfully started ride");

        // ✅ Immediately update local ride status to "In-Progress"
        try {
          final backgroundService = Get.find<BackgroundTrackingService>();
          if (backgroundService.currentRide.value != null) {
            final updatedRide = RideAssignment(
              rideId: backgroundService.currentRide.value!.rideId,
              rideType: backgroundService.currentRide.value!.rideType,
              fareEstimate: backgroundService.currentRide.value!.fareEstimate,
              fareFinal: backgroundService.currentRide.value!.fareFinal,
              createdAt: backgroundService.currentRide.value!.createdAt,
              status: 'In-Progress', // ✅ Update status
              passengerId: backgroundService.currentRide.value!.passengerId,
              passengerName: backgroundService.currentRide.value!.passengerName,
              passengerPhone: backgroundService.currentRide.value!.passengerPhone,
              pickupLocation: backgroundService.currentRide.value!.pickupLocation,
              pickUpLat: backgroundService.currentRide.value!.pickUpLat,
              pickUpLon: backgroundService.currentRide.value!.pickUpLon,
              dropoffLocation: backgroundService.currentRide.value!.dropoffLocation,
              dropoffLat: backgroundService.currentRide.value!.dropoffLat,
              dropoffLon: backgroundService.currentRide.value!.dropoffLon,
              stops: backgroundService.currentRide.value!.stops,
              passengerCount: backgroundService.currentRide.value!.passengerCount,
              payment: backgroundService.currentRide.value!.payment,
              tip: backgroundService.currentRide.value!.tip,
            );
            backgroundService.currentRide.value = updatedRide;
            backgroundService.rideStatus.value = 'In-Progress';
            print("SAHAr - StartRide: Local ride status updated to 'In-Progress'");
          }
        } catch (e) {
          print("SAHAr - StartRide: Failed to update local status: $e");
        }

        Get.snackbar(
          "Ride Started",
          "The ride has begun",
          backgroundColor: Colors.green.withValues(alpha:0.1),
          colorText: Colors.green,
          icon: Icon(Icons.check_circle, color: Colors.green),
          duration: const Duration(seconds: 3),
        );
      } else {
        print("SAHAr - StartRide: Failed => ${response.statusText}");
        Get.snackbar(
          "Error",
          "Failed to start ride: ${response.statusText}",
          backgroundColor: Colors.red.withValues(alpha:0.1),
          colorText: Colors.red,
          icon: const Icon(Icons.error, color: Colors.red),
        );
      }
    } catch (e) {
      print("SAHAr - StartRide: Exception => $e");
      Get.snackbar(
        "Error",
        "Network error: $e",
        backgroundColor: Colors.red.withValues(alpha:0.1),
        colorText: Colors.red,
        icon: const Icon(Icons.error, color: Colors.red),
      );
    } finally {
      isStartingRide.value = false;
      print("SAHAr - StartRide: Processing flag reset");
    }
  }

  // Cancel ride (passenger no-show)
  Future<void> cancelRide(String rideId, {String reason = 'Passenger no-show'}) async {
    if (isProcessingRequest.value) return;

    try {
      isProcessingRequest.value = true;
      final endpoint = '/api/Ride/cancel-ride?rideId=$rideId';
      print("SAHAr - CancelRide: Endpoint => $endpoint, Reason: $reason");

      final response = await _apiProvider.postData(endpoint, {'reason': reason});
      print("SAHAr - CancelRide: Response => ${response.statusCode} ${response.statusText}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        HapticFeedback.mediumImpact();
        print("SAHAr - CancelRide: Successfully cancelled ride");

        try {
          final backgroundService = Get.find<BackgroundTrackingService>();
          if (backgroundService.currentRide.value != null) {
            final current = backgroundService.currentRide.value!;
            final updatedRide = RideAssignment(
              rideId: current.rideId,
              rideType: current.rideType,
              fareEstimate: current.fareEstimate,
              fareFinal: current.fareFinal,
              createdAt: current.createdAt,
              status: 'Cancelled',
              passengerId: current.passengerId,
              passengerName: current.passengerName,
              passengerPhone: current.passengerPhone,
              pickupLocation: current.pickupLocation,
              pickUpLat: current.pickUpLat,
              pickUpLon: current.pickUpLon,
              dropoffLocation: current.dropoffLocation,
              dropoffLat: current.dropoffLat,
              dropoffLon: current.dropoffLon,
              stops: current.stops,
              passengerCount: current.passengerCount,
              payment: current.payment,
              tip: current.tip,
            );
            backgroundService.currentRide.value = updatedRide;
            backgroundService.rideStatus.value = 'Cancelled';

            // Reset the ride back to available state
            backgroundService.triggerCancelledFlow();

            print("SAHAr - CancelRide: Local ride status updated to 'Cancelled'");
          }
        } catch (e) {
          print("SAHAr - CancelRide: Failed to update local status: $e");
        }

        resetTimers();

        Get.snackbar(
          "Ride Cancelled",
          "The ride has been cancelled due to passenger no-show",
          backgroundColor: Colors.orange.withValues(alpha: 0.1),
          colorText: Colors.orange.shade800,
          icon: Icon(Icons.cancel_outlined, color: Colors.orange.shade800),
          duration: const Duration(seconds: 4),
        );
      } else {
        print("SAHAr - CancelRide: Failed => ${response.statusText}");
        Get.snackbar(
          "Error",
          "Failed to cancel ride: ${response.statusText}",
          backgroundColor: Colors.red.withValues(alpha: 0.1),
          colorText: Colors.red,
          icon: const Icon(Icons.error, color: Colors.red),
        );
      }
    } catch (e) {
      print("SAHAr - CancelRide: Exception => $e");
      Get.snackbar(
        "Error",
        "Network error: $e",
        backgroundColor: Colors.red.withValues(alpha: 0.1),
        colorText: Colors.red,
        icon: const Icon(Icons.error, color: Colors.red),
      );
    } finally {
      isProcessingRequest.value = false;
      print("SAHAr - CancelRide: Processing flag reset");
    }
  }

  // End the ride after trip completion
  Future<void> endRide(String rideId) async {
    if (isProcessingRequest.value) return;

    try {
      isProcessingRequest.value = true;

      String endpoint = "/api/Ride/$rideId/end";
      print("SAHAr - EndRide: Endpoint => $endpoint");

      final response = await _apiProvider.postData(endpoint, {});
      print("SAHAr - EndRide: Response => ${response.statusCode} ${response.statusText}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        HapticFeedback.mediumImpact();
        print("SAHAr - EndRide: Successfully ended ride");

        // Update local ride status to "Completed" and let BackgroundTrackingService handle payment flow
        try {
          final backgroundService = Get.find<BackgroundTrackingService>();
          if (backgroundService.currentRide.value != null) {
            final current = backgroundService.currentRide.value!;
            final updatedRide = RideAssignment(
              rideId: current.rideId,
              rideType: current.rideType,
              fareEstimate: current.fareEstimate,
              fareFinal: current.fareFinal,
              createdAt: current.createdAt,
              status: 'Completed',
              passengerId: current.passengerId,
              passengerName: current.passengerName,
              passengerPhone: current.passengerPhone,
              pickupLocation: current.pickupLocation,
              pickUpLat: current.pickUpLat,
              pickUpLon: current.pickUpLon,
              dropoffLocation: current.dropoffLocation,
              dropoffLat: current.dropoffLat,
              dropoffLon: current.dropoffLon,
              stops: current.stops,
              passengerCount: current.passengerCount,
              payment: current.payment,
              tip: current.tip,
            );
            backgroundService.currentRide.value = updatedRide;
            backgroundService.rideStatus.value = 'Completed';

            // Trigger the completion flow (payment waiting sheet, etc.)
            backgroundService.triggerCompletedFlow(updatedRide);

            print("SAHAr - EndRide: Local ride status updated to 'Completed'");
          }
        } catch (e) {
          print("SAHAr - EndRide: Failed to update local status: $e");
        }

        // Reset timers
        resetTimers();
      } else {
        print("SAHAr - EndRide: Failed => ${response.statusText}");
        Get.snackbar(
          "Error",
          "Failed to end ride: ${response.statusText}",
          backgroundColor: Colors.red.withValues(alpha: 0.1),
          colorText: Colors.red,
          icon: const Icon(Icons.error, color: Colors.red),
        );
      }
    } catch (e) {
      print("SAHAr - EndRide: Exception => $e");
      Get.snackbar(
        "Error",
        "Network error: $e",
        backgroundColor: Colors.red.withValues(alpha: 0.1),
        colorText: Colors.red,
        icon: const Icon(Icons.error, color: Colors.red),
      );
    } finally {
      isProcessingRequest.value = false;
      print("SAHAr - EndRide: Processing flag reset");
    }
  }

  // Reset all timers (call this when ride ends)
  void resetTimers() {
    _timer?.cancel();
    currentTimerSeconds.value = 0;
    totalWaitingTimeSeconds.value = 0;
    isOnStop.value = false;
  }
}