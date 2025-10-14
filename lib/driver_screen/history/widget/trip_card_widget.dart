import 'package:flutter/material.dart';
import 'package:pick_u_driver/models/ride_history_model.dart';
import 'package:pick_u_driver/utils/theme/mcolors.dart';
class TripHistoryCard extends StatelessWidget {
  const TripHistoryCard({
    super.key,
    required this.ride,
  });

  final RideItem ride;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: MColor.primaryNavy.withValues(alpha:0.1),
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with date and status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 16,
                      color: MColor.primaryNavy.withValues(alpha:0.6),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      ride.formattedDate,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: MColor.primaryNavy.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    ride.status.toUpperCase(),
                    style: TextStyle(
                      color: MColor.primaryNavy,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Time and locations
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time column
                SizedBox(
                  width: 60,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ride.formattedStartTime,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: MColor.primaryNavy,
                        ),
                      ),
                      const SizedBox(height: 38),
                      Text(
                        ride.formattedEndTime,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: MColor.primaryNavy,
                        ),
                      ),
                    ],
                  ),
                ),

                // Route indicator column
                Column(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: MColor.primaryNavy,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: 2,
                      height: 40,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: MColor.primaryNavy.withValues(alpha:0.3),
                      ),
                    ),
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: MColor.primaryNavy,
                    ),
                  ],
                ),

                const SizedBox(width: 16),

                // Locations column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ride.shortPickupLocation,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade800,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 32),
                      Text(
                        ride.shortDropoffLocation,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade800,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Divider
            Container(
              height: 1,
              color: Colors.grey.shade200,
            ),

            const SizedBox(height: 12),

            // Fare
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Fare: ',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '\$${ride.fareFinal.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18,
                    color: MColor.primaryNavy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

