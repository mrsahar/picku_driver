class DriverProfileModel {
  final String id;
  final String name;
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

  DriverProfileModel({
    required this.id,
    required this.name,
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

  factory DriverProfileModel.fromJson(Map<String, dynamic> json) {
    return DriverProfileModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
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
      'name': name,
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

  // Create empty profile with driver ID
  factory DriverProfileModel.empty(String driverId) {
    return DriverProfileModel(
      id: driverId,
      name: '',
      phoneNumber: '',
      address: '',
      licenseNumber: '',
      carLicensePlate: '',
      carVin: '',
      carRegistration: '',
      carInsurance: '',
      sin: '',
      vehicleName: '',
      vehicleColor: '',
      stripeAccountId: '',
    );
  }

  // Copy with method for updating fields
  DriverProfileModel copyWith({
    String? id,
    String? name,
    String? phoneNumber,
    String? address,
    String? licenseNumber,
    String? carLicensePlate,
    String? carVin,
    String? carRegistration,
    String? carInsurance,
    String? sin,
    String? vehicleName,
    String? vehicleColor,
    String? stripeAccountId,
  }) {
    return DriverProfileModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      carLicensePlate: carLicensePlate ?? this.carLicensePlate,
      carVin: carVin ?? this.carVin,
      carRegistration: carRegistration ?? this.carRegistration,
      carInsurance: carInsurance ?? this.carInsurance,
      sin: sin ?? this.sin,
      vehicleName: vehicleName ?? this.vehicleName,
      vehicleColor: vehicleColor ?? this.vehicleColor,
      stripeAccountId: stripeAccountId ?? this.stripeAccountId,
    );
  }

  // Check if profile is complete (core fields only)
  bool get isComplete {
    return name.isNotEmpty &&
        phoneNumber.isNotEmpty &&
        address.isNotEmpty &&
        licenseNumber.isNotEmpty &&
        carLicensePlate.isNotEmpty &&
        carVin.isNotEmpty &&
        carRegistration.isNotEmpty &&
        carInsurance.isNotEmpty &&
        sin.isNotEmpty &&
        vehicleName.isNotEmpty &&
        vehicleColor.isNotEmpty;
  }

  // Check if Stripe account is connected
  bool get hasStripeAccount => stripeAccountId.isNotEmpty;

  // Check if ready for payment collection
  bool get canReceivePayments => isComplete && hasStripeAccount;

  // Get completion percentage
  double get completionPercentage {
    int completedFields = 0;
    const int totalFields = 11; // Excluding stripeAccountId from completion

    if (name.isNotEmpty) completedFields++;
    if (phoneNumber.isNotEmpty) completedFields++;
    if (address.isNotEmpty) completedFields++;
    if (licenseNumber.isNotEmpty) completedFields++;
    if (carLicensePlate.isNotEmpty) completedFields++;
    if (carVin.isNotEmpty) completedFields++;
    if (carRegistration.isNotEmpty) completedFields++;
    if (carInsurance.isNotEmpty) completedFields++;
    if (sin.isNotEmpty) completedFields++;
    if (vehicleName.isNotEmpty) completedFields++;
    if (vehicleColor.isNotEmpty) completedFields++;

    return completedFields / totalFields;
  }

  // Get missing fields list
  List<String> get missingFields {
    final List<String> missing = [];

    if (name.isEmpty) missing.add('Full Name');
    if (phoneNumber.isEmpty) missing.add('Phone Number');
    if (address.isEmpty) missing.add('Address');
    if (licenseNumber.isEmpty) missing.add('License Number');
    if (carLicensePlate.isEmpty) missing.add('License Plate');
    if (carVin.isEmpty) missing.add('VIN');
    if (carRegistration.isEmpty) missing.add('Registration');
    if (carInsurance.isEmpty) missing.add('Insurance');
    if (sin.isEmpty) missing.add('SIN');
    if (vehicleName.isEmpty) missing.add('Vehicle Name');
    if (vehicleColor.isEmpty) missing.add('Vehicle Color');
    if (stripeAccountId.isEmpty) missing.add('Stripe Account');

    return missing;
  }
}