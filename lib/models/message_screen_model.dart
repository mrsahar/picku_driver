class ChatMessage {
  final String senderId;
  final String senderRole;
  final String message;
  final DateTime dateTime;
  final bool isFromCurrentUser;

  ChatMessage({
    required this.senderId,
    required this.senderRole,
    required this.message,
    required this.dateTime,
    this.isFromCurrentUser = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      senderId: json['senderId'] ?? '',
      senderRole: json['senderRole'] ?? '',
      message: json['message'] ?? '',
      dateTime: DateTime.tryParse(json['dateTime'] ?? json['timestamp'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'senderId': senderId,
      'senderRole': senderRole,
      'message': message,
      'dateTime': dateTime.toIso8601String(),
    };
  }

  ChatMessage copyWith({
    String? rideId,
    String? senderId,
    String? senderRole,
    String? message,
    DateTime? dateTime,
    bool? isFromCurrentUser,
  }) {
    return ChatMessage(
      senderId: senderId ?? this.senderId,
      senderRole: senderRole ?? this.senderRole,
      message: message ?? this.message,
      dateTime: dateTime ?? this.dateTime,
      isFromCurrentUser: isFromCurrentUser ?? this.isFromCurrentUser,
    );
  }
}