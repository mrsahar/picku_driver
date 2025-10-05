class RideAssignment {
  final String rideId;
  final String rideType;
  final double fareEstimate;
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

  RideAssignment({
    required this.rideId,
    required this.rideType,
    required this.fareEstimate,
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
  });

  factory RideAssignment.fromJson(Map<String, dynamic> json) {
    return RideAssignment(
      rideId: json['rideId'] ?? '',
      rideType: json['rideType'] ?? 'standard',
      fareEstimate: (json['fareEstimate'] ?? 0).toDouble(),
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
    );
  }
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
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
    );
  }
}