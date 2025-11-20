class DriverProfileResponse {
  final String id;
  final String phoneNumber;
  final String address;
  final String licenseNumber;
  final String carLicensePlate;
  final String carVin;
  final String carRegistration;
  final String carInsurance;
  final String sin;
  final String vehicleName;
  final String vehicleColor;
  final String stripeAccountId;

  DriverProfileResponse({
    required this.id,
    required this.phoneNumber,
    required this.address,
    required this.licenseNumber,
    required this.carLicensePlate,
    required this.carVin,
    required this.carRegistration,
    required this.carInsurance,
    required this.sin,
    required this.vehicleName,
    required this.vehicleColor,
    required this.stripeAccountId,
  });

  factory DriverProfileResponse.fromJson(Map<String, dynamic> json) {
    return DriverProfileResponse(
      id: json['id'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      address: json['address'] ?? '',
      licenseNumber: json['licenseNumber'] ?? '',
      carLicensePlate: json['carLicensePlate'] ?? '',
      carVin: json['carVin'] ?? '',
      carRegistration: json['carRegistration'] ?? '',
      carInsurance: json['carInsurance'] ?? '',
      sin: json['sin'] ?? '',
      vehicleName: json['vehicleName'] ?? '',
      vehicleColor: json['vehicleColor'] ?? '',
      stripeAccountId: json['stripeAccountId'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phoneNumber': phoneNumber,
      'address': address,
      'licenseNumber': licenseNumber,
      'carLicensePlate': carLicensePlate,
      'carVin': carVin,
      'carRegistration': carRegistration,
      'carInsurance': carInsurance,
      'sin': sin,
      'vehicleName': vehicleName,
      'vehicleColor': vehicleColor,
      'stripeAccountId': stripeAccountId,
    };
  }
}

