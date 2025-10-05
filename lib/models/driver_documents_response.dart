class DriverDocumentsResponse {
  final bool success;
  final String message;
  final dynamic data;

  DriverDocumentsResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory DriverDocumentsResponse.fromJson(Map<String, dynamic> json) {
    return DriverDocumentsResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'data': data,
    };
  }
}