import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ScheduledRideHistoryResponse {
  final List<ScheduledRideItem> items;
  final int completedRides;
  final double totalFare;

  ScheduledRideHistoryResponse({
    required this.items,
    required this.completedRides,
    required this.totalFare,
  });

  factory ScheduledRideHistoryResponse.fromJson(Map<String, dynamic> json) {
    return ScheduledRideHistoryResponse(
      items: (json['items'] as List<dynamic>?)
          ?.map((item) => ScheduledRideItem.fromJson(item as Map<String, dynamic>))
          .toList() ?? [],
      completedRides: json['completedRides'] ?? 0,
      totalFare: (json['totalFare'] ?? 0.0).toDouble(),
    );
  }
}

class ScheduledRideStop {
  final String rideStopId;
  final String rideId;
  final int stopOrder;
  final String location;
  final double latitude;
  final double longitude;

  ScheduledRideStop({
    required this.rideStopId,
    required this.rideId,
    required this.stopOrder,
    required this.location,
    required this.latitude,
    required this.longitude,
  });

  factory ScheduledRideStop.fromJson(Map<String, dynamic> json) {
    return ScheduledRideStop(
      rideStopId: json['rideStopId'] ?? '',
      rideId: json['rideId'] ?? '',
      stopOrder: json['stopOrder'] ?? 0,
      location: json['location'] ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
    );
  }
}

class ScheduledRideItem {
  final String rideId;
  final String userId;
  final String driverId;
  final String rideType;
  final String? vehicle;
  final String? vehicleColor;
  final bool isScheduled;
  final DateTime scheduledTime;
  final int passengerCount;
  final double fareEstimate;
  final double fareFinal;
  final String status;
  final double distance;
  final double? adminCommission;
  final String? driverPayment;
  final String? pickupLocation;
  final String? dropoffLocation;
  final String? totalWaitingTime;
  final String rideStartTime;
  final String rideEndTime;
  final DateTime createdAt;
  final List<ScheduledRideStop> rideStops;

  ScheduledRideItem({
    required this.rideId,
    required this.userId,
    required this.driverId,
    required this.rideType,
    this.vehicle,
    this.vehicleColor,
    required this.isScheduled,
    required this.scheduledTime,
    required this.passengerCount,
    required this.fareEstimate,
    required this.fareFinal,
    required this.status,
    required this.distance,
    this.adminCommission,
    this.driverPayment,
    this.pickupLocation,
    this.dropoffLocation,
    this.totalWaitingTime,
    required this.rideStartTime,
    required this.rideEndTime,
    required this.createdAt,
    required this.rideStops,
  });

  factory ScheduledRideItem.fromJson(Map<String, dynamic> json) {
    return ScheduledRideItem(
      rideId: json['rideId'] ?? '',
      userId: json['userId'] ?? '',
      driverId: json['driverId'] ?? '',
      rideType: json['rideType'] ?? '',
      vehicle: json['vehicle'],
      vehicleColor: json['vehicleColor'],
      isScheduled: json['isScheduled'] ?? false,
      scheduledTime: DateTime.parse(json['scheduledTime']),
      passengerCount: json['passengerCount'] ?? 0,
      fareEstimate: (json['fareEstimate'] ?? 0.0).toDouble(),
      fareFinal: (json['fareFinal'] ?? 0.0).toDouble(),
      status: json['status'] ?? '',
      distance: (json['distance'] ?? 0.0).toDouble(),
      adminCommission: json['adminCommission']?.toDouble(),
      driverPayment: json['driverPayment'],
      pickupLocation: json['pickupLocation'],
      dropoffLocation: json['dropoffLocation'],
      totalWaitingTime: json['totalWaitingTime'],
      rideStartTime: json['rideStartTime'] ?? '',
      rideEndTime: json['rideEndTime'] ?? '',
      createdAt: DateTime.parse(json['createdAt']),
      rideStops: (json['rideStops'] as List<dynamic>?)
          ?.map((stop) => ScheduledRideStop.fromJson(stop as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  // Helper methods to get pickup and dropoff locations from rideStops
  String get actualPickupLocation {
    if (pickupLocation != null && pickupLocation!.isNotEmpty) {
      return pickupLocation!;
    }
    final pickupStop = rideStops.where((stop) => stop.stopOrder == 0).firstOrNull;
    return pickupStop?.location ?? 'Unknown pickup location';
  }

  String get actualDropoffLocation {
    if (dropoffLocation != null && dropoffLocation!.isNotEmpty) {
      return dropoffLocation!;
    }
    final dropoffStop = rideStops.where((stop) => stop.stopOrder == 1).firstOrNull;
    return dropoffStop?.location ?? 'Unknown dropoff location';
  }

  String get formattedScheduledDate {
    return DateFormat('dd MMM yyyy, HH:mm').format(scheduledTime);
  }

  String get formattedScheduledTime {
    return DateFormat('HH:mm').format(scheduledTime);
  }

  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
      case 'canceled':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      case 'ongoing':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String get shortPickupLocation {
    final location = actualPickupLocation;
    final parts = location.split(',');
    return parts.length > 2 ? '${parts[0]}, ${parts[1]}...' : location;
  }

  String get shortDropoffLocation {
    final location = actualDropoffLocation;
    final parts = location.split(',');
    return parts.length > 2 ? '${parts[0]}, ${parts[1]}...' : location;
  }

  // For sorting - pending rides with latest scheduled time first
  int compareTo(ScheduledRideItem other) {
    if (status.toLowerCase() == 'pending' && other.status.toLowerCase() == 'pending') {
      return other.scheduledTime.compareTo(scheduledTime); // Latest first
    } else if (status.toLowerCase() == 'pending') {
      return -1; // Pending rides come first
    } else if (other.status.toLowerCase() == 'pending') {
      return 1; // Other ride goes after pending
    } else {
      return other.createdAt.compareTo(createdAt); // Latest created first for non-pending
    }
  }
}