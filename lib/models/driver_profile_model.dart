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
    );
  }

  // Check if profile is complete
  bool get isComplete {
    return name.isNotEmpty &&
        phoneNumber.isNotEmpty &&
        address.isNotEmpty &&
        licenseNumber.isNotEmpty &&
        carLicensePlate.isNotEmpty &&
        carVin.isNotEmpty &&
        carRegistration.isNotEmpty &&
        carInsurance.isNotEmpty &&
        sin.isNotEmpty;
  }

  // Get completion percentage
  double get completionPercentage {
    int completedFields = 0;
    const int totalFields = 9;

    if (name.isNotEmpty) completedFields++;
    if (phoneNumber.isNotEmpty) completedFields++;
    if (address.isNotEmpty) completedFields++;
    if (licenseNumber.isNotEmpty) completedFields++;
    if (carLicensePlate.isNotEmpty) completedFields++;
    if (carVin.isNotEmpty) completedFields++;
    if (carRegistration.isNotEmpty) completedFields++;
    if (carInsurance.isNotEmpty) completedFields++;
    if (sin.isNotEmpty) completedFields++;

    return completedFields / totalFields;
  }
}