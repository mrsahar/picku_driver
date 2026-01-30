import 'package:intl/intl.dart';

class PrivacyPolicyResponse {
  final String? title;
  final String? content;
  final String? createdAt;
  final String? updatedAt;
  final int? version;
  final bool? isActive;

  PrivacyPolicyResponse({
    this.title,
    this.content,
    this.createdAt,
    this.updatedAt,
    this.version,
    this.isActive,
  });

  factory PrivacyPolicyResponse.fromJson(Map<String, dynamic> json) {
    print('PrivacyPolicyResponse.fromJson: Parsing JSON...');
    print('PrivacyPolicyResponse.fromJson: JSON keys: ${json.keys.toList()}');
    
    return PrivacyPolicyResponse(
      title: json['title'] as String?,
      content: json['content'] as String?,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
      version: json['version'] as int?,
      isActive: json['isActive'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'content': content,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'version': version,
      'isActive': isActive,
    };
  }

  bool get hasContent => content != null && content!.trim().isNotEmpty;

  String get formattedCreatedAt {
    if (createdAt == null) return 'N/A';
    try {
      final date = DateTime.parse(createdAt!);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return createdAt!;
    }
  }

  String get formattedUpdatedAt {
    if (updatedAt == null) return 'N/A';
    try {
      final date = DateTime.parse(updatedAt!);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return updatedAt!;
    }
  }
}
