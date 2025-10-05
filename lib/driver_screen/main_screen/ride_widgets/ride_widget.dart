import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pick_u_driver/controllers/chat_controller.dart';
import 'package:pick_u_driver/controllers/ride_controller.dart';
import 'package:pick_u_driver/routes/app_routes.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/ride_assignment_model.dart';

class RideWidget extends StatelessWidget {
  final RideAssignment ride;

  const RideWidget({Key? key, required this.ride}) : super(key: key);

  static const Color primaryNavy = Color(0xFF1A2A44);

  @override
  Widget build(BuildContext context) {
    bool statusStatus = ride.status == "In-Progress";
    final RideController rideController = Get.put(RideController());

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        border: Border.all(color: primaryNavy.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: primaryNavy.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
          ),

          // Passenger row
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: primaryNavy.withOpacity(0.1),
                child: Text(
                  ride.passengerName.isNotEmpty
                      ? ride.passengerName[0].toUpperCase()
                      : "P",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: primaryNavy,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ride.passengerName.isNotEmpty
                          ? ride.passengerName
                          : "Passenger",
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: primaryNavy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "${ride.passengerCount} Passenger${ride.passengerCount > 1 ? "s" : ""}",
                      style: TextStyle(
                        fontSize: 12,
                        color: primaryNavy.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  _actionButton(Icons.message_outlined, () => _messagePassenger()),
                  const SizedBox(width: 8),
                  _actionButton(Icons.call_outlined, () => _callPassenger()),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          _journeyCard(
            pickup: ride.pickupLocation ?? "Pickup location",
            dropoff: ride.dropoffLocation ?? "Drop-off location",
          ),

          const SizedBox(height: 14),

          // Waiting time display (show when on stop)
          Obx(() {
            if (rideController.isOnStop.value) {
              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.timer, color: Colors.orange[700], size: 18),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Waiting Time",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.orange[700],
                          ),
                        ),
                        Text(
                          rideController.currentTimerFormatted,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[700],
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (rideController.totalWaitingTimeSeconds.value > 0)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "Total",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.orange[700],
                            ),
                          ),
                          Text(
                            rideController.totalWaitingTimeFormatted,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange[700],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          }),

          // Fare + Stop/Resume button row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.money_outlined,
                      size: 16,
                      color: primaryNavy,
                    ),
                    Text(
                      "\$${(ride.fareEstimate ?? 0).toStringAsFixed(2)} (Estimated)",
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: primaryNavy,
                      ),
                    ),
                  ],
                ),
              ),
              if (rideController.isOnStop.value || statusStatus)
                Obx(() => SizedBox(
                  height: 36,
                  child: ElevatedButton.icon(
                    onPressed: rideController.isProcessingRequest.value
                        ? null
                        : () => rideController.toggleRideStatus(ride.rideId ?? ''),
                    icon: rideController.isProcessingRequest.value
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : Icon(
                        rideController.isOnStop.value
                            ? Icons.play_circle_filled
                            : Icons.pause_circle_filled,
                        size: 18
                    ),
                    label: Text(
                        rideController.isOnStop.value ? "Resume Ride" : "Request Stop"
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: rideController.isOnStop.value
                          ? Colors.green
                          : primaryNavy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                )),
            ],
          ),
        ],
      ),
    );
  }

  // Action buttons (call/message)
  Widget _actionButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: primaryNavy.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: primaryNavy),
      ),
    );
  }

  // Journey card (pickup + dropoff inside one)
  Widget _journeyCard({
    required String pickup,
    required String dropoff,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: primaryNavy.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryNavy.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.circle, size: 12, color: primaryNavy),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pickup,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: primaryNavy,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on, size: 14, color: primaryNavy),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  dropoff,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: primaryNavy,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _messagePassenger() {
    ChatController? existingChatController;
    try {
      existingChatController = Get.find<ChatController>();
    } catch (e) {
      existingChatController = null;
    }

    if (existingChatController != null) {
      existingChatController.updateRideInfo(
        rideId: ride.rideId ?? '',
        driverId: ride.passengerId,
        driverName: ride.passengerName,
      );

      if (Get.currentRoute != AppRoutes.chatScreen) {
        Get.toNamed(AppRoutes.chatScreen);
      }
    } else {
      Get.toNamed(
        AppRoutes.chatScreen,
        arguments: {
          'rideId': ride.rideId ?? '',
          'driverId': ride.passengerId,
          'driverName': ride.passengerName,
        },
      );
    }
  }

  void _callPassenger() {
    if (ride.passengerPhone.isNotEmpty) {
      // Launch phone dialer with passenger's phone number
      final Uri phoneUri = Uri(
        scheme: 'tel',
        path: ride.passengerPhone,
      );
      launchUrl(phoneUri);
    } else {
      Get.snackbar(
        "Call Passenger",
        "Phone number not available",
        backgroundColor: primaryNavy.withOpacity(0.1),
        colorText: primaryNavy,
        icon: const Icon(Icons.phone, color: primaryNavy)
      );
    }
  }
}
