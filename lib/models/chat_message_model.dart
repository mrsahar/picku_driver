class ChatMessage {
  final String senderId;
  final String senderRole;
  final String message;
  final DateTime timestamp;

  ChatMessage({
    required this.senderId,
    required this.senderRole,
    required this.message,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      senderId: json['senderId'] ?? '',
      senderRole: json['senderRole'] ?? '',
      message: json['message'] ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'senderId': senderId,
      'senderRole': senderRole,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  bool get isAdmin => senderRole.toLowerCase() == 'admin';
  bool get isDriver => senderRole.toLowerCase() == 'driver';
}