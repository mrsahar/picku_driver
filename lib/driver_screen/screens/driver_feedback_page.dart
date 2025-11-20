import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../controllers/driver_feedback_controller.dart';
import '../../models/feedback_response_model.dart';
import '../../utils/picku_appbar.dart';

class DriverFeedbackPage extends GetView<DriverFeedbackController> {
  const DriverFeedbackPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: const PickUAppBar(
        title: 'My Reviews',
        showBackButton: true,
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return Center(
            child: CircularProgressIndicator(
              color: theme.primaryColor,
              strokeWidth: 3,
            ),
          );
        }

        if (controller.errorMessage.isNotEmpty) {
          return _buildErrorState(context);
        }

        if (controller.feedbacks.isEmpty) {
          return _buildEmptyState(context);
        }

        return RefreshIndicator(
          onRefresh: controller.refreshFeedbacks,
          color: theme.primaryColor,
          backgroundColor: Colors.white,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            children: [
              _buildHeaderSummary(context),
              const SizedBox(height: 24),
              Row(
                children: [
                  Text(
                    'Recent Comments',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[800],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${controller.feedbacks.length} Total',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...controller.feedbacks.map((feedback) => _buildModernFeedbackItem(
                context,
                feedback,
              )),
            ],
          ),
        );
      }),
    );
  }

  // --- Header Summary ---
  Widget _buildHeaderSummary(BuildContext context) {
    final rating = controller.averageRating.value;
    String statusText;
    IconData statusIcon;
    Color statusColor;

    if (rating >= 4.5) {
      statusText = "Top Driver";
      statusIcon = Icons.emoji_events_rounded;
      statusColor = Colors.green;
    } else if (rating >= 4.0) {
      statusText = "Excellent";
      statusIcon = Icons.thumb_up_alt_rounded;
      statusColor = Colors.teal;
    } else if (rating >= 3.0) {
      statusText = "Good";
      statusIcon = Icons.sentiment_satisfied_alt_rounded;
      statusColor = Colors.amber[700]!;
    } else if (rating >= 2.0) {
      statusText = "Fair";
      statusIcon = Icons.sentiment_neutral_rounded;
      statusColor = Colors.orange;
    } else {
      statusText = "At Risk";
      statusIcon = Icons.warning_amber_rounded;
      statusColor = Colors.red;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Overall Rating",
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      rating.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).primaryColor,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _buildStarRating(rating, 20, Colors.amber),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(height: 50, width: 1, color: Colors.grey[200]),
          Expanded(
            flex: 3,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(statusIcon, color: statusColor, size: 28),
                const SizedBox(height: 4),
                Text(
                  statusText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  // --- List Item ---
  Widget _buildModernFeedbackItem(BuildContext context, FeedbackItem feedback) {
    return GestureDetector(
        onTap: () => _showDetailSheet(context, feedback),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[100],
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Icon(Icons.person_outline, color: Colors.grey[600], size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            feedback.userName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            controller.formatDateTime(feedback.createdAt),
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getRatingColor(feedback.rating).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            feedback.rating.toString(),
                            style: TextStyle(
                              color: _getRatingColor(feedback.rating),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.star_rounded,
                            color: _getRatingColor(feedback.rating),
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (feedback.comments.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        Container(
                          width: 3,
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            feedback.comments,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey[700],
                              height: 1.5,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 14, color: Colors.grey[400]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Trip ID: ${feedback.rideId}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 11,
                          fontFamily: 'Monospace',
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 16, color: Colors.grey[300]),
                  ],
                ),
              ],
            ),
          ),
        ));
  }

  // --- Detail Bottom Sheet ---
  void _showDetailSheet(BuildContext context, FeedbackItem feedback) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 24),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                // 1. Rating Hero Section
                Center(
                  child: Column(
                    children: [
                      Text(
                        feedback.rating.toString(),
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: _getRatingColor(feedback.rating),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildStarRating(feedback.rating.toDouble(), 32, _getRatingColor(feedback.rating)),
                      const SizedBox(height: 8),
                      Text(
                        feedback.rating >= 4 ? "Excellent Experience" : (feedback.rating >= 3 ? "Good Experience" : "Needs Improvement"),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 24),

                // 2. User Info
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.grey[100],
                      child: Text(
                        feedback.userName.substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          feedback.userName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          controller.formatDateTime(feedback.createdAt),
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // 3. Full Comment
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.format_quote_rounded, color: Colors.grey[300], size: 32),
                      const SizedBox(height: 8),
                      Text(
                        feedback.comments.isEmpty ? "No comments provided." : feedback.comments,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.6,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // 4. Technical Details (IDs)
                Text(
                  "TRIP DETAILS",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[400],
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),
                _buildDetailRow(context, "Trip ID", feedback.rideId),
                _buildDetailRow(context, "Review ID", feedback.feedbackId),
                _buildDetailRow(context, "Driver", feedback.driverName),
                _buildDetailRow(context, "Source", feedback.feedbackFrom),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildDetailRow(BuildContext context, String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          flex: 7,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Monospace',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (label.contains("ID")) // Only show copy icon for IDs
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$label copied to clipboard'), duration: const Duration(seconds: 1)),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Icon(Icons.copy_rounded, size: 16, color: Theme.of(context).primaryColor),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

  // --- Utility Methods (Unchanged) ---
  Widget _buildEmptyState(BuildContext context) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
          child: Icon(Icons.rate_review_outlined, size: 48, color: Colors.grey[400]),
        ),
        const SizedBox(height: 24),
        Text('No Reviews Yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
        const SizedBox(height: 8),
        Text('When you complete rides, reviews\nwill show up here.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[500], height: 1.5)),
      ],
    ),
  );
}

  Widget _buildErrorState(BuildContext context) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_rounded, size: 60, color: Colors.red[200]),
          const SizedBox(height: 16),
          Text('Oops!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[800])),
          const SizedBox(height: 8),
          Text(controller.errorMessage.value, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: controller.loadFeedbacks,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildStarRating(double rating, double size, Color color) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(5, (index) {
      if (index < rating.floor()) return Icon(Icons.star_rounded, size: size, color: color);
      if (index < rating) return Icon(Icons.star_half_rounded, size: size, color: color);
      return Icon(Icons.star_outline_rounded, size: size, color: Colors.grey[300]);
    }),
  );
}

  Color _getRatingColor(int rating) {
    if (rating >= 4) return Colors.green;
    if (rating >= 3) return Colors.orange;
    return Colors.red;
  }
}