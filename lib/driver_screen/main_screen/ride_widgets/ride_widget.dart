import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:action_slider/action_slider.dart';
import 'package:pick_u_driver/controllers/chat_controller.dart';
import 'package:pick_u_driver/controllers/ride_controller.dart';
import 'package:pick_u_driver/routes/app_routes.dart';
import 'package:pick_u_driver/utils/theme/mcolors.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/ride_assignment_model.dart';

class RideWidget extends StatelessWidget {
  final RideAssignment ride;
  const RideWidget({super.key, required this.ride});

  @override
  Widget build(BuildContext context) {
    final RideController rideController = Get.put(RideController());
    final bool isInProgress = ride.status == "In-Progress";

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: MColor.primaryNavy.withValues(alpha:0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
        border: Border.all(
          color: MColor.primaryNavy.withValues(alpha:0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Row (Status + Passenger + Actions)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildStatusBadge(ride.status),
              const Spacer(),
              _buildActionButton(
                icon: Icons.chat_bubble_outline,
                onTap: _messagePassenger,
              ),
              const SizedBox(width: 6),
              _buildActionButton(
                icon: Icons.phone_outlined,
                onTap: _callPassenger,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Passenger Name Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 22,
                child: Text(
                  ride.passengerName.isNotEmpty
                      ? ride.passengerName[0].toUpperCase()
                      : "P",
                  style: TextStyle(
                    color: MColor.primaryNavy,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
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
                      style: TextStyle(
                        color: MColor.primaryNavy,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      "${ride.passengerCount} Passenger${ride.passengerCount > 1 ? 's' : ''}",
                      style: TextStyle(
                        color: MColor.primaryNavy.withValues(alpha:0.6),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          _buildSectionDivider(),

          // ── Pickup & Drop Info
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                _buildLocationRow(
                  icon: Icons.radio_button_checked,
                  title: "PICKUP",
                  value: ride.pickupLocation,
                ),
                const SizedBox(height: 6),
                _buildDashedLine(),
                const SizedBox(height: 6),
                _buildLocationRow(
                  icon: Icons.location_on_outlined,
                  title: "DROP-OFF",
                  value: ride.dropoffLocation,
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),
          _buildSectionDivider(),

          // ── Waiting Timer (if applicable)
          Obx(() {
            if (!rideController.isOnStop.value) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.only(top: 8),
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: MColor.primaryNavy.withValues(alpha:0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: MColor.primaryNavy.withValues(alpha:0.1),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.timer_outlined,
                      color: MColor.primaryNavy.withValues(alpha:0.8), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Current Wait: ${rideController.currentTimerFormatted}",
                      style: TextStyle(
                        color: MColor.primaryNavy,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (rideController.totalWaitingTimeSeconds.value > 0)
                    Text(
                      "Total: ${rideController.totalWaitingTimeFormatted}",
                      style: TextStyle(
                        color: MColor.primaryNavy.withValues(alpha:0.7),
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            );
          }),

          const SizedBox(height: 12),

          // ── Fare + Action Button / Slide to Arrive / Arrived Banner
          if (ride.status == "Waiting" || ride.status == "Pending")
            // Show "Slide to Arrive" for Waiting/Pending status
            Column(
              children: [
                // Fare display for Waiting status
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: [
                        MColor.primaryNavy.withValues(alpha:0.05),
                        MColor.primaryNavy.withValues(alpha:0.03)
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: MColor.primaryNavy.withValues(alpha:0.08),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                          Icons.payments_rounded,
                          color: MColor.primaryNavy.withValues(alpha:0.8),
                          size: 18
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "\$${(ride.fareEstimate ?? ride.fareFinal).toStringAsFixed(2)}"
                              "${(ride.tip != null && ride.tip! > 0) ? " + \$${ride.tip!.toStringAsFixed(2)} Tip" : ""}",
                          style: TextStyle(
                            color: MColor.primaryNavy,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Slide to Arrive — Compact Design
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: MColor.primaryNavy,
                    borderRadius: BorderRadius.circular(28), // full pill shape
                    boxShadow: [
                      BoxShadow(
                        color: MColor.primaryNavy.withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: 0,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ActionSlider.standard(
                    sliderBehavior: SliderBehavior.stretch,
                    width: double.infinity,
                    height: 56,
                    backgroundColor: Colors.transparent,
                    toggleColor: Colors.transparent,
                    borderWidth: 0,
                    icon: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child:   Icon(
                        Icons.arrow_forward_rounded,
                        color: MColor.primaryNavy,
                        size: 20,
                      ),
                    ),
                    loadingIcon: SizedBox(
                      width: 44,
                      height: 44,
                      child: Padding(
                        padding: const EdgeInsets.all(13),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: MColor.primaryNavy,
                          backgroundColor: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                    successIcon: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child:   Icon(
                        Icons.check_rounded,
                        color: MColor.primaryNavy,
                        size: 20,
                      ),
                    ),
                    action: (controller) async {
                      if (rideController.isArriving.value) {
                        controller.reset();
                        return;
                      }
                      controller.loading();
                      await rideController.markAsArrived(ride.rideId);
                      controller.success();
                      await Future.delayed(const Duration(milliseconds: 600));
                      controller.reset();
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(width: 40), // breathing room from thumb
                        const Text(
                          'Slide to arrive',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          else if (ride.status == "Arrived")
            // Show only the Arrived banner — no slider
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [
                    MColor.primaryNavy,
                    MColor.primaryNavy,
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Arrived at Pickup",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          "Waiting for passenger to board",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.directions_car_rounded,
                    color: Colors.white.withValues(alpha: 0.7),
                    size: 26,
                  ),
                ],
              ),
            )
          else
            // Show Fare + Pause/Resume for In-Progress status
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: [
                          MColor.primaryNavy.withValues(alpha:0.05),
                          MColor.primaryNavy.withValues(alpha:0.03)
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: MColor.primaryNavy.withValues(alpha:0.08),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                            Icons.payments_rounded,
                            color: MColor.primaryNavy.withValues(alpha:0.8),
                            size: 18
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            "\$${(ride.fareEstimate ?? ride.fareFinal).toStringAsFixed(2)}"
                                "${(ride.tip != null && ride.tip! > 0) ? " + \$${ride.tip!.toStringAsFixed(2)} Tip" : ""}",
                            style: TextStyle(
                              color: MColor.primaryNavy,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Obx(() {
                  if (!(rideController.isOnStop.value || isInProgress)) {
                    return const SizedBox.shrink();
                  }
                  return ElevatedButton(
                    onPressed: rideController.isProcessingRequest.value
                        ? null
                        : () => rideController.toggleRideStatus(ride.rideId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MColor.primaryNavy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: rideController.isProcessingRequest.value
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : Row(
                      children: [
                        Icon(
                          rideController.isOnStop.value
                              ? Icons.play_arrow_rounded
                              : Icons.pause_rounded,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          rideController.isOnStop.value ? "Resume" : "Pause",
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
        ],
      ),
    );
  }

  // ── Subwidgets ─────────────────────────────

  Widget _buildStatusBadge(String status) {
    IconData icon;
    String label;
    Color color;

    switch (status) {
      case 'Waiting':
        icon = Icons.schedule_rounded;
        label = 'Waiting';
        color = MColor.primaryNavy.withValues(alpha:0.8);
        break;
      case 'Pending':
        icon = Icons.pending_rounded;
        label = 'Pending';
        color = Colors.orange.shade700;
        break;
      case 'Arrived':
        icon = Icons.check_circle_rounded;
        label = 'Arrived';
        color = Colors.green.shade700;
        break;
      case 'In-Progress':
        icon = Icons.directions_car_rounded;
        label = 'In Progress';
        color = MColor.primaryNavy;
        break;
      case 'Completed':
        icon = Icons.check_circle_rounded;
        label = 'Completed';
        color = Colors.green.shade700;
        break;
      default:
        icon = Icons.info_outline_rounded;
        label = status;
        color = MColor.primaryNavy.withValues(alpha:0.6);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha:0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              )),
        ],
      ),
    );
  }

  Widget _buildDashedLine() {
    return Container(
      width: double.infinity,
      height: 1,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: MColor.primaryNavy.withValues(alpha:0.2),
            width: 1,
            style: BorderStyle.solid,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionDivider() => Divider(
    color: MColor.primaryNavy.withValues(alpha:0.15),
    thickness: 1,
    height: 1,
  );

  Widget _buildLocationRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: MColor.primaryNavy.withValues(alpha:0.8), size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                    color: MColor.primaryNavy.withValues(alpha:0.6),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  )),
              Text(
                value,
                style: TextStyle(
                  color: MColor.primaryNavy,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: MColor.primaryNavy.withValues(alpha:0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: MColor.primaryNavy.withValues(alpha:0.2), width: 1),
        ),
        child: Icon(icon, color: MColor.primaryNavy, size: 18),
      ),
    );
  }

  void _messagePassenger() {
    ChatController? chatCtrl;
    try {
      chatCtrl = Get.find<ChatController>();
    } catch (_) {
      chatCtrl = null;
    }

    if (chatCtrl != null) {
      chatCtrl.updateRideInfo(
        rideId: ride.rideId,
        driverId: ride.passengerId,
        driverName: ride.passengerName,
      );
      if (Get.currentRoute != AppRoutes.chatScreen) {
        Get.toNamed(AppRoutes.chatScreen);
      }
    } else {
      Get.toNamed(AppRoutes.chatScreen, arguments: {
        'rideId': ride.rideId,
        'driverId': ride.passengerId,
        'driverName': ride.passengerName,
      });
    }
  }

  void _callPassenger() {
    if (ride.passengerPhone.isNotEmpty) {
      final Uri phoneUri = Uri(scheme: 'tel', path: ride.passengerPhone);
      launchUrl(phoneUri);
    } else {
      Get.snackbar(
        "Call Passenger",
        "Phone number not available",
        backgroundColor: MColor.primaryNavy.withValues(alpha:0.08),
        colorText: MColor.primaryNavy,
        icon: Icon(Icons.phone_outlined, color: MColor.primaryNavy),
        duration: const Duration(seconds: 2),
      );
    }
  }
}


