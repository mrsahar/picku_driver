import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pick_u_driver/core/background_tracking_service.dart';
import 'package:pick_u_driver/utils/theme/mcolors.dart';

class ModernPaymentBottomSheet extends StatelessWidget {
  final VoidCallback onDismiss;

  const ModernPaymentBottomSheet({
    Key? key,
    required this.onDismiss,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final BackgroundTrackingService backgroundService = Get.find<BackgroundTrackingService>();

    return PopScope(
      canPop: false,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 30,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Obx(() {
          final ride = backgroundService.currentRide.value;

          print('🔄 BOTTOM SHEET REBUILD');
          print('   - Ride: ${ride?.rideId}');
          print('   - Status: ${ride?.status}');
          print('   - Payment: ${ride?.payment}');

          if (ride == null) {
            print('⚠️ SAHAr Ride is null, closing payment bottom sheet');
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (Get.isBottomSheetOpen == true) {
                Get.back();
              }
            });
            return const SizedBox.shrink();
          }

          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Drag handle only (no X button)
                Padding(
                  padding: const EdgeInsets.only(top: 14, left: 20, right: 20),
                  child: Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: MColor.primaryNavy.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                  child: Column(
                    children: [
                      // ── Bill / Payments Icon
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              color: MColor.primaryNavy.withValues(alpha: 0.04),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: MColor.primaryNavy.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Icon(
                                Icons.receipt_long_outlined,
                                size: 34,
                                color: MColor.primaryNavy,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      Text(
                        'Awaiting Payment',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: MColor.primaryNavy,
                          letterSpacing: -0.3,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 6),

                      Text(
                        'Waiting for the passenger to complete their payment',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: MColor.primaryNavy.withValues(alpha: 0.55),
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 16),

                      // ── Payment Details Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: MColor.primaryNavy.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: MColor.primaryNavy.withValues(alpha: 0.08),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: MColor.primaryNavy.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.person_outline,
                                      size: 22,
                                      color: MColor.primaryNavy.withValues(alpha: 0.75),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Passenger',
                                        style: TextStyle(
                                          fontSize: 11,
                                          letterSpacing: 0.4,
                                          color: MColor.primaryNavy.withValues(alpha: 0.5),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        ride.passengerName,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: MColor.primaryNavy,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            Divider(
                              color: MColor.primaryNavy.withValues(alpha: 0.08),
                              height: 1,
                            ),

                            const SizedBox(height: 16),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Expected Fare',
                                      style: TextStyle(
                                        fontSize: 12,
                                        letterSpacing: 0.3,
                                        color: MColor.primaryNavy.withValues(alpha: 0.5),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Total to collect',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: MColor.primaryNavy.withValues(alpha: 0.35),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '\$${ride.fareFinal.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: MColor.primaryNavy,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── Info banner
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: MColor.primaryNavy.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: MColor.primaryNavy.withValues(alpha: 0.06),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: Icon(
                                Icons.info_outline_rounded,
                                size: 15,
                                color: MColor.primaryNavy.withValues(alpha: 0.45),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'No action needed — this screen will update as soon as payment is confirmed.',
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.45,
                                  color: MColor.primaryNavy.withValues(alpha: 0.55),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── Dismiss button
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () {
                            Get.back();
                            onDismiss();
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: MColor.primaryNavy.withValues(alpha: 0.06),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            'Dismiss',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: MColor.primaryNavy.withValues(alpha: 0.75),
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: MediaQuery.of(context).padding.bottom),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}