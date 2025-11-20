class FeedbackResponse {
  final double averageRating;
  final List<FeedbackItem> feedbacks;

  FeedbackResponse({
    required this.averageRating,
    required this.feedbacks,
  });

  factory FeedbackResponse.fromJson(Map<String, dynamic> json) {
    return FeedbackResponse(
      averageRating: (json['averageRating'] as num).toDouble(),
      feedbacks: (json['feedbacks'] as List)
          .map((item) => FeedbackItem.fromJson(item))
          .toList(),
    );
  }
}

class FeedbackItem {
  final String feedbackId;
  final String rideId;
  final String userId;
  final String driverId;
  final int rating;
  final String comments;
  final String createdAt;
  final String feedbackFrom;
  final String driverName;
  final String userName;

  FeedbackItem({
    required this.feedbackId,
    required this.rideId,
    required this.userId,
    required this.driverId,
    required this.rating,
    required this.comments,
    required this.createdAt,
    required this.feedbackFrom,
    required this.driverName,
    required this.userName,
  });

  factory FeedbackItem.fromJson(Map<String, dynamic> json) {
    return FeedbackItem(
      feedbackId: json['feedbackId'] ?? '',
      rideId: json['rideId'] ?? '',
      userId: json['userId'] ?? '',
      driverId: json['driverId'] ?? '',
      rating: json['rating'] ?? 0,
      comments: json['comments'] ?? '',
      createdAt: json['createdAt'] ?? '',
      feedbackFrom: json['feedbackFrom'] ?? '',
      driverName: json['driverName'] ?? '',
      userName: json['userName'] ?? '',
    );
  }
}