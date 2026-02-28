import 'dart:async';

import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:action_slider/action_slider.dart';

import 'package:pick_u_driver/controllers/chat_controller.dart';

import 'package:pick_u_driver/controllers/ride_controller.dart';

import 'package:pick_u_driver/routes/app_routes.dart';

import 'package:pick_u_driver/utils/theme/mcolors.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../../models/ride_assignment_model.dart';

class RideWidget extends StatefulWidget {
  final RideAssignment ride;

  const RideWidget({super.key, required this.ride});

  @override
  State<RideWidget> createState() => _RideWidgetState();
}

class _RideWidgetState extends State<RideWidget> {
  static const int _noShowThresholdSeconds = 300;

  Timer? _noShowTimer;

  int _secondsWaited = 0;

  bool _showNoShowPanel = false;

  @override
  void initState() {
    super.initState();

    if (widget.ride.status == 'Arrived') {
      _startNoShowTimer();
    }
  }

  @override
  void didUpdateWidget(RideWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.ride.status == 'Arrived' && oldWidget.ride.status != 'Arrived') {
      _resetNoShowTimer();

      _startNoShowTimer();
    }

    if (widget.ride.status != 'Arrived' && oldWidget.ride.status == 'Arrived') {
      _stopNoShowTimer();
    }
  }

  @override
  void dispose() {
    _noShowTimer?.cancel();

    super.dispose();
  }

  void _startNoShowTimer() {
    _noShowTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();

        return;
      }

      setState(() {
        _secondsWaited++;

        if (_secondsWaited >= _noShowThresholdSeconds && !_showNoShowPanel) {
          _showNoShowPanel = true;
        }
      });
    });
  }

  void _stopNoShowTimer() {
    _noShowTimer?.cancel();

    _noShowTimer = null;
  }

  void _resetNoShowTimer() {
    _stopNoShowTimer();

    setState(() {
      _secondsWaited = 0;

      _showNoShowPanel = false;
    });
  }

  int get _secondsUntilNoShow => (_noShowThresholdSeconds - _secondsWaited)
      .clamp(0, _noShowThresholdSeconds);

  String get _countdownFormatted {
    final m = _secondsUntilNoShow ~/ 60;

    final s = _secondsUntilNoShow % 60;

    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final RideController rideController = Get.put(RideController());

    final ride = widget.ride;

    final bool isInProgress = ride.status == "In-Progress";

    return Container(
      width: double.infinity,

      margin: const EdgeInsets.only(top: 8),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),

        boxShadow: [
          BoxShadow(
            color: MColor.primaryNavy.withValues(alpha: 0.12),

            blurRadius: 20,

            spreadRadius: 0,

            offset: const Offset(0, -3),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          _buildHeader(ride, rideController),


          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                // ── Route card
                _buildRouteCard(ride),

                // ── Waiting Timer
                Obx(() {
                  if (!rideController.isOnStop.value) {
                    return const SizedBox.shrink();
                  }

                  return Padding(
                    padding: const EdgeInsets.only(top: 12),

                    child: _buildWaitingTimer(rideController),
                  );
                }),

                const SizedBox(height: 10),

                // ── CTA Section
                if (ride.status == "Waiting" || ride.status == "Pending")
                  _buildSlideToArrive(rideController, ride)
                else if (ride.status == "Arrived")
                  _buildArrivedActions(rideController, ride)
                else
                  _buildInProgressActions(rideController, ride, isInProgress),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────

  // Sub-widgets

  // ─────────────────────────────────────────────────────────────

  Widget _buildHeader(RideAssignment ride, RideController rideController) {
    final status = ride.status;
    IconData statusIcon;
    String statusLabel;

    switch (status) {
      case 'Waiting':
        statusIcon = Icons.schedule_rounded;

        statusLabel = 'Heading to Pickup';

        break;

      case 'Arrived':
        statusIcon = Icons.place_rounded;

        statusLabel = 'Arrived · Waiting';

        break;

      case 'In-Progress':
        statusIcon = Icons.moving_rounded;

        statusLabel = 'In Progress';

        break;

      case 'Completed':
        statusIcon = Icons.check_circle_outline_rounded;

        statusLabel = 'Completed';

        break;

      default:
        statusIcon = Icons.info_outline_rounded;

        statusLabel = status;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          // drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),

              width: 32,

              height: 4,

              decoration: BoxDecoration(
                color: MColor.primaryNavy.withValues(alpha: 0.12),

                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          _buildStatusFareRow(ride),

          const SizedBox(height: 10),

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,

            children: [
              // avatar
              Container(
                width: 44,

                height: 44,

                decoration: BoxDecoration(
                  color: MColor.primaryNavy.withValues(alpha: 0.08),

                  shape: BoxShape.circle,
                ),

                child: Center(
                  child: Text(
                    ride.passengerName.isNotEmpty
                        ? ride.passengerName[0].toUpperCase()
                        : 'P',

                    style: TextStyle(
                      color: MColor.primaryNavy,

                      fontWeight: FontWeight.w800,

                      fontSize: 18,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // name + status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      ride.passengerName.isNotEmpty
                          ? ride.passengerName
                          : 'Passenger',

                      style: TextStyle(
                        color: MColor.primaryNavy,

                        fontWeight: FontWeight.w700,

                        fontSize: 15,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Row(
                      children: [
                        Icon(
                          Icons.person_outline_rounded,

                          size: 12,

                          color: MColor.primaryNavy.withValues(alpha: 0.5),
                        ),

                        const SizedBox(width: 3),

                        Text(
                          '${ride.passengerCount} Passenger${ride.passengerCount > 1 ? "s" : ""}',

                          style: TextStyle(
                            color: MColor.primaryNavy.withValues(alpha: 0.55),

                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // right side: action buttons only
              Row(
                children: [
                  _buildIconBtn(
                    icon: Icons.chat_bubble_outline_rounded,

                    onTap: _messagePassenger,
                  ),

                  const SizedBox(width: 6),

                  _buildIconBtn(
                    icon: Icons.phone_rounded,

                    onTap: _callPassenger,

                    filled: true,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFareRow(RideAssignment ride) {
    final fare = ride.fareEstimate ?? ride.fareFinal;

    final hasTip = ride.tip != null && ride.tip! > 0;

    final status = ride.status;

    IconData statusIcon;

    String statusLabel;

    switch (status) {
      case 'Waiting':
        statusIcon = Icons.schedule_rounded;

        statusLabel = 'Heading to Pickup';

        break;

      case 'Arrived':
        statusIcon = Icons.place_rounded;

        statusLabel = 'Arrived';

        break;

      case 'In-Progress':
        statusIcon = Icons.moving_rounded;

        statusLabel = 'In Progress';

        break;

      case 'Completed':
        statusIcon = Icons.check_circle_outline_rounded;

        statusLabel = 'Completed';

        break;

      default:
        statusIcon = Icons.info_outline_rounded;

        statusLabel = status;
    }

    return Row(
      children: [
        // ── Status pill (left)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),

          decoration: BoxDecoration(
            border: Border.all(
              color: MColor.primaryNavy.withValues(alpha: 0.3),

              width: 1.2,
            ),

            borderRadius: BorderRadius.circular(20),
          ),

          child: Row(
            mainAxisSize: MainAxisSize.min,

            children: [
              Icon(statusIcon, size: 12, color: MColor.primaryNavy),

              const SizedBox(width: 5),

              Text(
                statusLabel,

                style: TextStyle(
                  color: MColor.primaryNavy,

                  fontSize: 12,

                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        const Spacer(),

        // ── Fare (right)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),

          decoration: BoxDecoration(
            color: MColor.primaryNavy.withValues(alpha: 0.06),

            borderRadius: BorderRadius.circular(20),

            border: Border.all(
              color: MColor.primaryNavy.withValues(alpha: 0.12),

              width: 1,
            ),
          ),

          child: Row(
            mainAxisSize: MainAxisSize.min,

            children: [
              Icon(
                Icons.receipt_long_rounded,

                size: 13,
                color: MColor.primaryNavy.withValues(alpha: 0.6),
              ),

              const SizedBox(width: 5),

              Text(
                'Fare',

                style: TextStyle(
                  color: MColor.primaryNavy.withValues(alpha: 0.6),

                  fontSize: 12,

                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(width: 6),

              Text(
                r'$' + fare.toStringAsFixed(2),

                style: TextStyle(
                  color: MColor.primaryNavy,

                  fontSize: 14,

                  fontWeight: FontWeight.w800,
                ),
              ),

              if (hasTip) ...[
                const SizedBox(width: 5),

                Text(
                  r'+$' + ride.tip!.toStringAsFixed(2),

                  style: TextStyle(
                    color: MColor.primaryNavy.withValues(alpha: 0.5),

                    fontSize: 11,

                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIconBtn({
    required IconData icon,

    required VoidCallback onTap,

    bool filled = false,
  }) {
    return GestureDetector(
      onTap: onTap,

      child: Container(
        width: 34,

        height: 34,

        decoration: BoxDecoration(
          color: filled
              ? MColor.primaryNavy
              : MColor.primaryNavy.withValues(alpha: 0.07),

          borderRadius: BorderRadius.circular(10),

          border: filled
              ? null
              : Border.all(
                  color: MColor.primaryNavy.withValues(alpha: 0.12),
                  width: 1,
                ),
        ),

        child: Icon(
          icon,

          color: filled ? Colors.white : MColor.primaryNavy,

          size: 15,
        ),
      ),
    );
  }

  Widget _buildRouteCard(RideAssignment ride) {
    return Container(
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: MColor.primaryNavy.withValues(alpha: 0.04),

        borderRadius: BorderRadius.circular(16),

        border: Border.all(
          color: MColor.primaryNavy.withValues(alpha: 0.1),

          width: 1,
        ),
      ),

      child: Column(
        children: [
          _buildLocationRow(
            icon: Icons.radio_button_checked_rounded,

            title: "PICKUP",

            value: ride.pickupLocation,
          ),

          Padding(
            padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),

            child: Row(
              children: [
                Container(
                  width: 2,

                  height: 20,

                  margin: const EdgeInsets.only(left: 7),

                  decoration: BoxDecoration(
                    color: MColor.primaryNavy.withValues(alpha: 0.2),

                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            ),
          ),

          _buildLocationRow(
            icon: Icons.location_on_rounded,

            title: "DROP-OFF",

            value: ride.dropoffLocation,
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingTimer(RideController rideController) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),

      decoration: BoxDecoration(
        color: MColor.primaryNavy.withValues(alpha: 0.06),

        borderRadius: BorderRadius.circular(14),

        border: Border.all(
          color: MColor.primaryNavy.withValues(alpha: 0.12),

          width: 1,
        ),
      ),

      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),

            decoration: BoxDecoration(
              color: MColor.primaryNavy.withValues(alpha: 0.1),

              shape: BoxShape.circle,
            ),

            child: Icon(
              Icons.timer_outlined,

              color: MColor.primaryNavy,
              size: 16,
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  'Current Wait',

                  style: TextStyle(
                    color: MColor.primaryNavy.withValues(alpha: 0.55),

                    fontSize: 11,

                    fontWeight: FontWeight.w600,
                  ),
                ),

                Text(
                  rideController.currentTimerFormatted,

                  style: TextStyle(
                    color: MColor.primaryNavy,

                    fontWeight: FontWeight.w800,

                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),

          if (rideController.totalWaitingTimeSeconds.value > 0)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,

              children: [
                Text(
                  'Total',

                  style: TextStyle(
                    color: MColor.primaryNavy.withValues(alpha: 0.55),

                    fontSize: 11,

                    fontWeight: FontWeight.w600,
                  ),
                ),

                Text(
                  rideController.totalWaitingTimeFormatted,

                  style: TextStyle(
                    color: MColor.primaryNavy,

                    fontWeight: FontWeight.w700,

                    fontSize: 14,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSlideToArrive(
    RideController rideController,
    RideAssignment ride,
  ) {
    return Container(
      height: 60,

      decoration: BoxDecoration(
        color: MColor.primaryNavy,

        borderRadius: BorderRadius.circular(30),

        boxShadow: [
          BoxShadow(
            color: MColor.primaryNavy.withValues(alpha: 0.35),

            blurRadius: 20,

            offset: const Offset(0, 8),
          ),
        ],
      ),

      child: ActionSlider.standard(
        sliderBehavior: SliderBehavior.stretch,

        width: double.infinity,

        height: 60,

        backgroundColor: Colors.transparent,

        toggleColor: Colors.transparent,

        borderWidth: 0,

        icon: Container(
          width: 48,

          height: 48,

          decoration: BoxDecoration(
            shape: BoxShape.circle,

            color: Colors.white,

            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),

                blurRadius: 10,

                offset: const Offset(0, 3),
              ),
            ],
          ),

          child: Icon(
            Icons.arrow_forward_rounded,

            color: MColor.primaryNavy,

            size: 22,
          ),
        ),

        loadingIcon: SizedBox(
          width: 48,

          height: 48,

          child: Padding(
            padding: const EdgeInsets.all(14),

            child: CircularProgressIndicator(
              strokeWidth: 2.5,

              color: MColor.primaryNavy,

              backgroundColor: Colors.white.withValues(alpha: 0.3),
            ),
          ),
        ),

        successIcon: Container(
          width: 48,

          height: 48,

          decoration: const BoxDecoration(
            shape: BoxShape.circle,

            color: Colors.white,
          ),

          child: Icon(Icons.check_rounded, color: MColor.primaryNavy, size: 22),
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

          children: const [
            SizedBox(width: 44),

            Icon(
              Icons.directions_car_filled_rounded,

              color: Colors.white54,
              size: 16,
            ),

            SizedBox(width: 8),

            Text(
              'Slide to Arrive',

              style: TextStyle(
                color: Colors.white,

                fontWeight: FontWeight.w700,

                fontSize: 15,

                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArrivedActions(
    RideController rideController,
    RideAssignment ride,
  ) {
    return Column(
      children: [
        // No-show panel
        if (_showNoShowPanel) ...[
          Container(
            width: double.infinity,

            padding: const EdgeInsets.all(14),

            decoration: BoxDecoration(
              color: MColor.primaryNavy.withValues(alpha: 0.05),

              borderRadius: BorderRadius.circular(14),

              border: Border.all(
                color: MColor.primaryNavy.withValues(alpha: 0.2),

                width: 1.2,
              ),
            ),

            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Container(
                  padding: const EdgeInsets.all(7),

                  decoration: BoxDecoration(
                    color: MColor.primaryNavy.withValues(alpha: 0.1),

                    shape: BoxShape.circle,
                  ),

                  child: Icon(
                    Icons.warning_amber_rounded,

                    color: MColor.primaryNavy,
                    size: 18,
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Text(
                        'Passenger not showing up?',

                        style: TextStyle(
                          color: MColor.primaryNavy,

                          fontWeight: FontWeight.w700,

                          fontSize: 13,
                        ),
                      ),

                      const SizedBox(height: 2),

                      Text(
                        'You\'ve been waiting over 5 minutes. You may cancel this ride.',

                        style: TextStyle(
                          color: MColor.primaryNavy.withValues(alpha: 0.65),

                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          Obx(
            () => _buildFullButton(
              label: rideController.isProcessingRequest.value
                  ? 'Cancelling...'
                  : 'Cancel — Passenger No-Show',

              icon: Icons.cancel_outlined,

              isLoading: rideController.isProcessingRequest.value,

              onPressed: rideController.isProcessingRequest.value
                  ? null
                  : () => _confirmCancelRide(rideController, ride.rideId),

              outlined: true,
            ),
          ),

          const SizedBox(height: 10),
        ] else ...[
          // Countdown hint
          Container(
            margin: const EdgeInsets.only(bottom: 12),

            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),

            decoration: BoxDecoration(
              color: MColor.primaryNavy.withValues(alpha: 0.05),

              borderRadius: BorderRadius.circular(10),
            ),

            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,

              children: [
                Icon(
                  Icons.timer_outlined,

                  size: 14,

                  color: MColor.primaryNavy.withValues(alpha: 0.5),
                ),

                const SizedBox(width: 6),

                Text(
                  'Cancel option unlocks in  $_countdownFormatted',

                  style: TextStyle(
                    fontSize: 12,

                    color: MColor.primaryNavy.withValues(alpha: 0.55),

                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],

        // Start Ride button
        Obx(
          () => _buildFullButton(
            label: rideController.isStartingRide.value
                ? 'Starting...'
                : 'Start Ride',

            icon: Icons.play_arrow_rounded,

            isLoading: rideController.isStartingRide.value,

            onPressed: rideController.isStartingRide.value
                ? null
                : () => rideController.startRide(ride.rideId),
          ),
        ),
      ],
    );
  }

  Widget _buildInProgressActions(
      RideController rideController,
      RideAssignment ride,
      bool isInProgress,
      ) {
    return Obx(
          () => Row(
        children: [
          if (rideController.isOnStop.value || isInProgress) ...[
            Expanded(
              flex: 1,
              child: OutlinedButton.icon(
                onPressed: rideController.isProcessingRequest.value
                    ? null
                    : () => rideController.toggleRideStatus(ride.rideId),
                style: OutlinedButton.styleFrom(
                  foregroundColor: MColor.primaryNavy,
                  side: BorderSide(
                    color: rideController.isProcessingRequest.value
                        ? MColor.primaryNavy.withValues(alpha: 0.3)
                        : MColor.primaryNavy,
                    width: 1.5,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: rideController.isProcessingRequest.value
                    ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: MColor.primaryNavy,
                  ),
                )
                    : Icon(
                  rideController.isOnStop.value
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded,
                  size: 16,
                ),
                label: Text(
                  rideController.isOnStop.value ? 'Resume' : 'Pause',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: rideController.isProcessingRequest.value
                  ? null
                  : () => _confirmEndRide(rideController, ride.rideId),
              style: ElevatedButton.styleFrom(
                backgroundColor: MColor.primaryNavy,
                foregroundColor: Colors.white,
                disabledBackgroundColor: MColor.primaryNavy.withValues(alpha: 0.4),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              icon: rideController.isProcessingRequest.value
                  ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Icon(Icons.stop_circle_rounded, size: 16),
              label: const Text(
                'End Ride',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Generic full-width button (filled or outlined)

  Widget _buildFullButton({
    required String label,

    required IconData icon,

    required bool isLoading,

    required VoidCallback? onPressed,

    bool outlined = false,
  }) {
    if (outlined) {
      return SizedBox(
        width: double.infinity,

        child: OutlinedButton.icon(
          onPressed: onPressed,

          style: OutlinedButton.styleFrom(
            foregroundColor: MColor.primaryNavy,

            side: BorderSide(
              color: isLoading
                  ? MColor.primaryNavy.withValues(alpha: 0.3)
                  : MColor.primaryNavy,

              width: 1.5,
            ),

            padding: const EdgeInsets.symmetric(vertical: 14),

            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),

          icon: isLoading
              ? SizedBox(
                  width: 16,

                  height: 16,

                  child: CircularProgressIndicator(
                    strokeWidth: 2,

                    color: MColor.primaryNavy,
                  ),
                )
              : Icon(icon, size: 20),

          label: Text(
            label,

            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,

      child: ElevatedButton.icon(
        onPressed: onPressed,

        style: ElevatedButton.styleFrom(
          backgroundColor: MColor.primaryNavy,

          foregroundColor: Colors.white,

          disabledBackgroundColor: MColor.primaryNavy.withValues(alpha: 0.4),

          padding: const EdgeInsets.symmetric(vertical: 14),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),

          elevation: 0,
        ),

        icon: isLoading
            ? const SizedBox(
                width: 16,

                height: 16,

                child: CircularProgressIndicator(
                  strokeWidth: 2,

                  color: Colors.white,
                ),
              )
            : Icon(icon, size: 20),

        label: Text(
          label,

          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,

    required String title,

    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,

      children: [
        Icon(icon, color: MColor.primaryNavy, size: 18),

        const SizedBox(width: 10),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Text(
                title,

                style: TextStyle(
                  color: MColor.primaryNavy.withValues(alpha: 0.5),

                  fontSize: 10.5,

                  fontWeight: FontWeight.w700,

                  letterSpacing: 0.8,
                ),
              ),

              Text(
                value,

                style: TextStyle(
                  color: MColor.primaryNavy,

                  fontSize: 13.5,

                  fontWeight: FontWeight.w600,
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

  // ── Dialogs ───────────────────────────────────────────────────

  void _confirmCancelRide(RideController rideController, String rideId) {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),

        title: Row(
          children: [
            Icon(Icons.cancel_outlined, color: MColor.primaryNavy, size: 24),

            const SizedBox(width: 8),

            const Text(
              'Cancel Ride?',

              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
            ),
          ],
        ),

        content: const Text(
          'Are you sure you want to cancel this ride?\nReason: Passenger no-show.',

          style: TextStyle(fontSize: 14),
        ),

        actions: [
          TextButton(
            onPressed: () => Get.back(),

            child: Text(
              'Keep Waiting',

              style: TextStyle(
                color: MColor.primaryNavy,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          ElevatedButton(
            onPressed: () {
              Get.back();

              rideController.cancelRide(rideId, reason: 'Passenger no-show');
            },

            style: ElevatedButton.styleFrom(
              backgroundColor: MColor.primaryNavy,

              foregroundColor: Colors.white,

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),

            child: const Text(
              'Cancel Ride',

              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),

      barrierDismissible: true,
    );
  }

  void _confirmEndRide(RideController rideController, String rideId) {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),

        title: Row(
          children: [
            Icon(
              Icons.stop_circle_rounded,
              color: MColor.primaryNavy,
              size: 18,
            ),

            const SizedBox(width: 8),

            const Text(
              'End Ride?',

              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
            ),
          ],
        ),

        content: const Text(
          'Are you sure you want to end this ride? This action cannot be undone.',

          style: TextStyle(fontSize: 14),
        ),

        actions: [
          TextButton(
            onPressed: () => Get.back(),

            child: Text(
              'Cancel',

              style: TextStyle(
                color: MColor.primaryNavy,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          ElevatedButton(
            onPressed: () {
              Get.back();

              rideController.endRide(rideId);
            },

            style: ElevatedButton.styleFrom(
              backgroundColor: MColor.primaryNavy,

              foregroundColor: Colors.white,

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),

            child: const Text(
              'End Ride',

              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),

      barrierDismissible: true,
    );
  }

  void _messagePassenger() {
    final ride = widget.ride;

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
      Get.toNamed(
        AppRoutes.chatScreen,
        arguments: {
          'rideId': ride.rideId,

          'driverId': ride.passengerId,

          'driverName': ride.passengerName,
        },
      );
    }
  }

  void _callPassenger() {
    final ride = widget.ride;

    if (ride.passengerPhone.isNotEmpty) {
      final Uri phoneUri = Uri(scheme: 'tel', path: ride.passengerPhone);

      launchUrl(phoneUri);
    } else {
      Get.snackbar(
        "Call Passenger",

        "Phone number not available",

        backgroundColor: MColor.primaryNavy.withValues(alpha: 0.08),

        colorText: MColor.primaryNavy,

        icon: Icon(Icons.phone_outlined, color: MColor.primaryNavy),

        duration: const Duration(seconds: 2),
      );
    }
  }
}
