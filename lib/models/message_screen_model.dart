class ChatMessage {
  final String rideId;
  final String senderId;
  final String senderRole;
  final String message;
  final DateTime dateTime;
  final bool isFromCurrentUser;
  /// Hub sequence for JoinRideChat(lastReceivedSequence) / replay.
  final int? sequence;

  ChatMessage({
    this.rideId = '',
    required this.senderId,
    required this.senderRole,
    required this.message,
    required this.dateTime,
    this.isFromCurrentUser = false,
    this.sequence,
  });

  static int? _readSequence(Map<String, dynamic> json) {
    final v = json['sequence'] ?? json['Sequence'];
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  static String _readString(Map<String, dynamic> json, String a, String b) {
    final v = json[a] ?? json[b];
    return v?.toString() ?? '';
  }

  static DateTime _readDateTime(Map<String, dynamic> json) {
    // Hub sends "DateTime"; some legacy paths send "dateTime"/"timestamp".
    final v = json['dateTime'] ?? json['DateTime'] ?? json['timestamp'] ?? json['Timestamp'];
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      rideId: _readString(json, 'rideId', 'RideId'),
      senderId: _readString(json, 'senderId', 'SenderId'),
      senderRole: _readString(json, 'senderRole', 'SenderRole'),
      message: _readString(json, 'message', 'Message'),
      dateTime: _readDateTime(json),
      sequence: _readSequence(json),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rideId': rideId,
      'senderId': senderId,
      'senderRole': senderRole,
      'message': message,
      'dateTime': dateTime.toIso8601String(),
      if (sequence != null) 'sequence': sequence,
    };
  }

  ChatMessage copyWith({
    String? rideId,
    String? senderId,
    String? senderRole,
    String? message,
    DateTime? dateTime,
    bool? isFromCurrentUser,
    int? sequence,
  }) {
    return ChatMessage(
      rideId: rideId ?? this.rideId,
      senderId: senderId ?? this.senderId,
      senderRole: senderRole ?? this.senderRole,
      message: message ?? this.message,
      dateTime: dateTime ?? this.dateTime,
      isFromCurrentUser: isFromCurrentUser ?? this.isFromCurrentUser,
      sequence: sequence ?? this.sequence,
    );
  }
}