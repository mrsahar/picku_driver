class ChatMessage {
  final String senderId;
  final String senderRole="Driver";
  final String message;
  final DateTime dateTime;
  final bool isFromCurrentUser;

  ChatMessage({
    required this.senderId,
    required String senderRole,
    required this.message,
    required this.dateTime,
    this.isFromCurrentUser = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      senderId: json['senderId'] ?? '',
      senderRole:"Driver",
      message: json['message'] ?? '',
      dateTime: DateTime.tryParse(json['dateTime'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'senderId': senderId,
      'senderRole':"Driver",
      'message': message,
      'dateTime': dateTime.toIso8601String(),
    };
  }

  ChatMessage copyWith({
    String? rideId,
    String? senderId,
    String? message,
    DateTime? dateTime,
    bool? isFromCurrentUser,
  }) {
    return ChatMessage(
      senderId: senderId ?? this.senderId,
      senderRole:"Driver",
      message: message ?? this.message,
      dateTime: dateTime ?? this.dateTime,
      isFromCurrentUser: isFromCurrentUser ?? this.isFromCurrentUser,
    );
  }
}