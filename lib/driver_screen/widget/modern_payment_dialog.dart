import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pick_u_driver/core/background_tracking_service.dart';
import 'package:pick_u_driver/routes/app_routes.dart';
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
        // Get current ride value - this is reactive
        final ride = backgroundService.currentRide.value;
        final isWaiting = backgroundService.isWaitingForPayment.value;
        final isCompleted = backgroundService.paymentCompleted.value;

        // Debug prints
        print('🔄 BOTTOM SHEET REBUILD');
        print('   - Ride: ${ride?.rideId}');
        print('   - Status: ${ride?.status}');
        print('   - Payment: ${ride?.payment}');
        print('   - Tip: ${ride?.tip}');
        print('   - isWaiting: $isWaiting');
        print('   - isCompleted: $isCompleted');

        // If no ride, show error state
        if (ride == null) {
          return _buildErrorState(context);
        }

        // Calculate payment details
        final hasTip = ride.tip != null && ride.tip! > 0;
        final hasPayment = ride.payment != null && ride.payment == 'Successful';
        final totalEarning = ride.fareFinal + (ride.tip ?? 0);

        // Determine if payment is complete
        final paymentComplete = hasPayment && isCompleted;

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
                    // Icon with animation
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      transitionBuilder: (child, animation) {
                        return ScaleTransition(
                          scale: animation,
                          child: child,
                        );
                      },
                      child: Container(
                        key: ValueKey(paymentComplete),
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: paymentComplete
                              ? Colors.green.withValues(alpha: 0.1)
                              : MColor.primaryNavy.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: paymentComplete
                              ? Icon(
                            Icons.check_circle,
                            size: 48,
                            color: Colors.green.shade700,
                          )
                              : SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                MColor.primaryNavy,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Title with animation
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        paymentComplete ? 'Payment Received!' : 'Awaiting Payment',
                        key: ValueKey(paymentComplete),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: MColor.primaryNavy,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Subtitle with animation
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        paymentComplete
                            ? 'Payment has been successfully completed'
                            : 'Please wait while the passenger completes payment',
                        key: ValueKey('subtitle_$paymentComplete'),
                        style: TextStyle(
                          fontSize: 14,
                          color: MColor.primaryNavy.withValues(alpha: 0.6),
                        ),
                        textAlign: TextAlign.center,
                      ),
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

                          // Fare Breakdown
                          _buildPaymentRow(
                            label: 'Ride Fare',
                            amount: ride.fareFinal,
                            isTotal: false,
                          ),

                          // Show tip section with animation
                          AnimatedSize(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOut,
                            child: paymentComplete && hasTip
                                ? Column(
                              children: [
                                const SizedBox(height: 12),
                                _buildPaymentRow(
                                  label: 'Tip',
                                  amount: ride.tip!,
                                  isTotal: false,
                                  isTip: true,
                                ),
                                const SizedBox(height: 12),
                                Divider(
                                  color: MColor.primaryNavy.withValues(alpha: 0.1),
                                  height: 1,
                                ),
                                const SizedBox(height: 12),
                              ],
                            )
                                : const SizedBox.shrink(),
                          ),

                          // Total Earning with animation
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.1),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              );
                            },
                            child: _buildPaymentRow(
                              key: ValueKey('total_$totalEarning'),
                              label: 'Total Earning',
                              amount: paymentComplete ? totalEarning : ride.fareFinal,
                              isTotal: true,
                            ),
                          ),

                          // Payment Status Badge with animation
                          AnimatedSize(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOut,
                            child: paymentComplete
                                ? Column(
                              children: [
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.green.withValues(alpha: 0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        size: 14,
                                        color: Colors.green.shade700,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Payment Successful',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Action Buttons with animation
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.2),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: paymentComplete
                          ? Row(
                        key: const ValueKey('buttons'),
                        children: [
                          // OK Button
                          Expanded(
                            child: ElevatedButton(
                              onPressed: onDismiss,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: MColor.primaryNavy.withValues(alpha: 0.1),
                                foregroundColor: MColor.primaryNavy,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: MColor.primaryNavy.withValues(alpha: 0.2),
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: const Text(
                                'OK',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          // View Earnings Button
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                onDismiss();
                                Get.toNamed(AppRoutes.EarningSCREEN);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: MColor.primaryNavy,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'View Earnings',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                          : Container(
                        key: const ValueKey('waiting'),
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
                    ),

                    // Add bottom padding for safe area
                    SizedBox(height: MediaQuery.of(context).padding.bottom),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 5,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: MColor.primaryNavy.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Error',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: MColor.primaryNavy,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ride information not available',
            style: TextStyle(
              fontSize: 14,
              color: MColor.primaryNavy.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onDismiss,
            style: ElevatedButton.styleFrom(
              backgroundColor: MColor.primaryNavy,
              foregroundColor: Colors.white,
            ),
            child: const Text('Close'),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildPaymentRow({
    Key? key,
    required String label,
    required double amount,
    required bool isTotal,
    bool isTip = false,
  }) {
    return Row(
      key: key,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (isTip)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.star,
                  size: 14,
                  color: Colors.amber.shade700,
                ),
              ),
            Text(
              label,
              style: TextStyle(
                fontSize: isTotal ? 16 : 14,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
                color: MColor.primaryNavy.withValues(
                  alpha: isTotal ? 1.0 : 0.7,
                ),
              ),
            ),
          ],
        ),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: isTotal ? 24 : 16,
            fontWeight: FontWeight.bold,
            color: isTip ? Colors.amber.shade700 : MColor.primaryNavy,
          ),
        ),
      ],
    );
  }
}