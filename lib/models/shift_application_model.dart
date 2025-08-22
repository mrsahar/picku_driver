// models/shift_application_model.dart - Simplified version
import 'dart:ui';

import 'package:flutter/material.dart';

class ShiftApplicationModel {
  final String shiftId;
  final String status;

  ShiftApplicationModel({
    required this.shiftId,
    required this.status,
  });

  factory ShiftApplicationModel.fromJson(Map<String, dynamic> json) {
    return ShiftApplicationModel(
      shiftId: json['shiftId'] ?? '',
      status: json['status'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shiftId': shiftId,
      'status': status,
    };
  }

  // Helper methods
  bool get isPending => status.toLowerCase() == 'pending';
  bool get isApproved => status.toLowerCase() == 'approved';
  bool get isRejected => status.toLowerCase() == 'rejected';

  String get statusDisplay {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }

  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData get statusIcon {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.schedule;
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }
}