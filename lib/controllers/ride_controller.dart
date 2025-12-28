import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pick_u_driver/providers/api_provider.dart';
import 'package:pick_u_driver/utils/theme/mcolors.dart';

class RideController extends GetxController {
  final ApiProvider _apiProvider = Get.find<ApiProvider>();

  // Observable variables
  var isOnStop = false.obs;
  var currentTimerSeconds = 0.obs;
  var totalWaitingTimeSeconds = 0.obs;
  var isProcessingRequest = false.obs;

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

  // Reset all timers (call this when ride ends)
  void resetTimers() {
    _timer?.cancel();
    currentTimerSeconds.value = 0;
    totalWaitingTimeSeconds.value = 0;
    isOnStop.value = false;
  }
}