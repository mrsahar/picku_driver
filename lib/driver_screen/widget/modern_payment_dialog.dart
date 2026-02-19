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

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Obx(() {
        // Get current ride value
        final ride = backgroundService.currentRide.value;

        // Debug prints
        print('🔄 BOTTOM SHEET REBUILD');
        print('   - Ride: ${ride?.rideId}');
        print('   - Status: ${ride?.status}');
        print('   - Payment: ${ride?.payment}');

        // If no ride, close the bottom sheet immediately
        if (ride == null) {
          print('⚠️ SAHAr Ride is null, closing payment bottom sheet');
          // Close the bottom sheet after current frame
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (Get.isBottomSheetOpen == true) {
              Get.back();
            }
          });
          // Return empty container while closing
          return const SizedBox.shrink();
        }

        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 50,
                height: 5,
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                decoration: BoxDecoration(
                  color: MColor.primaryNavy.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  children: [
                    // Waiting Icon (no loading indicator)
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: MColor.primaryNavy.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.payments_outlined,
                          size: 40,
                          color: MColor.primaryNavy,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Title
                    Text(
                      'Awaiting Payment',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: MColor.primaryNavy,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 8),

                    // Subtitle
                    Text(
                      'Please wait while the passenger completes payment',
                      style: TextStyle(
                        fontSize: 14,
                        color: MColor.primaryNavy.withValues(alpha: 0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 24),

                    // Payment Details Card
                    Container(
                      padding: const EdgeInsets.all(20),
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
                          // Passenger Name
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: MColor.primaryNavy.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.person_outline,
                                  size: 20,
                                  color: MColor.primaryNavy.withValues(alpha: 0.7),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Passenger',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: MColor.primaryNavy.withValues(alpha: 0.6),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      ride.passengerName,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: MColor.primaryNavy,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Divider
                          Divider(
                            color: MColor.primaryNavy.withValues(alpha: 0.1),
                            height: 1,
                          ),

                          const SizedBox(height: 20),

                          // Expected Fare
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Expected Fare',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: MColor.primaryNavy,
                                ),
                              ),
                              Text(
                                '\$${ride.fareFinal.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: MColor.primaryNavy,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Info message (no buttons)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: MColor.primaryNavy.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: MColor.primaryNavy.withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'This will update automatically when payment is received',
                              style: TextStyle(
                                fontSize: 12,
                                color: MColor.primaryNavy.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Add bottom padding for safe area
                    SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

}