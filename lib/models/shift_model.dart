// models/shift_model.dart
import 'package:flutter/material.dart';

class ShiftModel {
  final String shiftId;
  final DateTime shiftDate;
  final String shiftStart;
  final String shiftEnd;
  final int maxDriverCount;
  final String description;
  final String? status;
  final DateTime createdAt;

  ShiftModel({
    required this.shiftId,
    required this.shiftDate,
    required this.shiftStart,
    required this.shiftEnd,
    required this.maxDriverCount,
    required this.description,
    this.status,
    required this.createdAt,
  });

  factory ShiftModel.fromJson(Map<String, dynamic> json) {
    return ShiftModel(
      shiftId: json['shiftId'] ?? '',
      shiftDate: DateTime.parse(json['shiftDate']),
      shiftStart: json['shiftStart'] ?? '',
      shiftEnd: json['shiftEnd'] ?? '',
      maxDriverCount: json['maxDriverCount'] ?? 0,
      description: json['description'] ?? '',
      status: json['status'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shiftId': shiftId,
      'shiftDate': shiftDate.toIso8601String(),
      'shiftStart': shiftStart,
      'shiftEnd': shiftEnd,
      'maxDriverCount': maxDriverCount,
      'description': description,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Helper methods for UI display
  String get formattedTime {
    return '$shiftStart - $shiftEnd';
  }

  String get formattedDate {
    return '${shiftDate.day}/${shiftDate.month}/${shiftDate.year}';
  }

  String get title {
    // Generate title based on time
    final startHour = int.tryParse(shiftStart.split(':')[0]) ?? 0;

    if (startHour >= 5 && startHour < 12) {
      return 'Morning Shift';
    } else if (startHour >= 12 && startHour < 17) {
      return 'Afternoon Shift';
    } else if (startHour >= 17 && startHour < 21) {
      return 'Evening Shift';
    } else {
      return 'Night Shift';
    }
  }

  IconData get icon {
    // Generate icon based on time
    final startHour = int.tryParse(shiftStart.split(':')[0]) ?? 0;

    if (startHour >= 5 && startHour < 12) {
      return Icons.wb_sunny; // Morning
    } else if (startHour >= 12 && startHour < 17) {
      return Icons.wb_sunny_outlined; // Afternoon
    } else if (startHour >= 17 && startHour < 21) {
      return Icons.wb_twilight; // Evening
    } else {
      return Icons.bedtime; // Night
    }
  }

  String get displayDescription {
    if (description.isNotEmpty) {
      return description;
    }
    return 'Available slots: $maxDriverCount drivers';
  }
}