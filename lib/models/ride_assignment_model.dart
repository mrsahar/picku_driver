class RideAssignment {
  final String rideId;
  final String rideType;
  final double? fareEstimate; // Added fareEstimate
  final double fareFinal;
  final DateTime createdAt;
  final String status;
  final String passengerId;
  final String passengerName;
  final String passengerPhone;
  final String pickupLocation;
  final double pickUpLat;
  final double pickUpLon;
  final String dropoffLocation;
  final double dropoffLat;
  final double dropoffLon;
  final List<RideStop> stops;
  final int passengerCount;
  final String? payment;
  final double? tip;

  RideAssignment({
    required this.rideId,
    required this.rideType,
    this.fareEstimate,
    required this.fareFinal,
    required this.createdAt,
    required this.status,
    required this.passengerId,
    required this.passengerName,
    required this.passengerPhone,
    required this.pickupLocation,
    required this.pickUpLat,
    required this.pickUpLon,
    required this.dropoffLocation,
    required this.dropoffLat,
    required this.dropoffLon,
    required this.stops,
    required this.passengerCount,
    this.payment,
    this.tip,
  });

  factory RideAssignment.fromJson(Map<String, dynamic> json) {
    return RideAssignment(
      rideId: json['rideId'] ?? '',
      rideType: json['rideType'] ?? 'standard',
      fareEstimate: json['fareEstimate'] != null
          ? (json['fareEstimate'] is num ? (json['fareEstimate'] as num).toDouble() : double.tryParse(json['fareEstimate'].toString()))
          : null,
      fareFinal: _parseFareFinal(json),
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      status: json['status'] ?? 'Waiting',
      passengerId: json['passengerId'] ?? '',
      passengerName: json['passengerName'] ?? '',
      passengerPhone: json['passengerPhone'] ?? '',
      pickupLocation: json['pickupLocation'] ?? '',
      pickUpLat: (json['pickUpLat'] ?? 0).toDouble(),
      pickUpLon: (json['pickUpLon'] ?? 0).toDouble(),
      dropoffLocation: json['dropoffLocation'] ?? '',
      dropoffLat: (json['dropoffLat'] ?? 0).toDouble(),
      dropoffLon: (json['dropoffLon'] ?? 0).toDouble(),
      stops: (json['stops'] as List?)
          ?.map((stop) => RideStop.fromJson(stop))
          .toList() ?? [],
      passengerCount: json['passengerCount'] ?? 1,
      payment: json['payment'],
      tip: json['tip'] != null
          ? (json['tip'] is num ? (json['tip'] as num).toDouble() : double.tryParse(json['tip'].toString()))
          : null,
    );
  }

  // Helper method to safely parse fareFinal with fallback to fareEstimate
  static double _parseFareFinal(Map<String, dynamic> json) {
    // First try to parse fareFinal
    if (json['fareFinal'] != null) {
      if (json['fareFinal'] is num) {
        return (json['fareFinal'] as num).toDouble();
      }
      final parsed = double.tryParse(json['fareFinal'].toString());
      if (parsed != null) return parsed;
    }

    // Fall back to fareEstimate
    if (json['fareEstimate'] != null) {
      if (json['fareEstimate'] is num) {
        return (json['fareEstimate'] as num).toDouble();
      }
      final parsed = double.tryParse(json['fareEstimate'].toString());
      if (parsed != null) return parsed;
    }

    // Default to 0.0
    return 0.0;
  }

  // Helper method to get the display fare
  double get displayFare => fareEstimate ?? fareFinal;
}
class RideStop {
  final int stopOrder;
  final String location;
  final double latitude;
  final double longitude;

  RideStop({
    required this.stopOrder,
    required this.location,
    required this.latitude,
    required this.longitude,
  });

  factory RideStop.fromJson(Map<String, dynamic> json) {
    return RideStop(
      stopOrder: json['stopOrder'] ?? 0,
      location: json['location'] ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stopOrder': stopOrder,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
