import 'dart:convert';
import 'dart:typed_data';

class UserProfileModel {
  final String userId;
  final String name;
  final String phoneNumber;
  final bool hasImage;
  final String? profilePicture; // Base64 string
  final String? email;
  final String? status;
  final String? address;
  final String? licenseNumber;
  final String? carLicensePlate;
  final String? carVin;
  final String? carRegistration;
  final String? carInsurance;
  final String? sin;
  final String? vehicleName;
  final String? vehicleColor;
  final String? stripeAccountId;

  UserProfileModel({
    required this.userId,
    required this.name,
    required this.phoneNumber,
    required this.hasImage,
    this.profilePicture,
    this.email,
    this.status,
    this.address,
    this.licenseNumber,
    this.carLicensePlate,
    this.carVin,
    this.carRegistration,
    this.carInsurance,
    this.sin,
    this.vehicleName,
    this.vehicleColor,
    this.stripeAccountId,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      userId: json['id'] ?? json['userId'] ?? json['driverId'] ?? '',
      name: json['name'] ?? json['fullName'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      hasImage: json['hasImage'] ?? false,
      profilePicture: json['profilePicture'],
      email: json['email'],
      status: json['status'],
      address: json['address'],
      licenseNumber: json['licenseNumber'],
      carLicensePlate: json['carLicensePlate'],
      carVin: json['carVin'],
      carRegistration: json['carRegistration'],
      carInsurance: json['carInsurance'],
      sin: json['sin'],
      vehicleName: json['vehicleName'],
      vehicleColor: json['vehicleColor'],
      stripeAccountId: json['stripeAccountId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'id': userId,
      'name': name,
      'phoneNumber': phoneNumber,
      'hasImage': hasImage,
      'profilePicture': profilePicture,
      'email': email,
      'status': status,
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

  // Helper method to get image bytes from base64 string
  Uint8List? getImageBytes() {
    if (profilePicture == null || profilePicture!.isEmpty) {
      return null;
    }

    try {
      // Remove the data URL prefix if it exists (data:image/jpeg;base64,)
      String base64String = profilePicture!;
      if (base64String.contains(',')) {
        base64String = base64String.split(',')[1];
      }

      return base64Decode(base64String);
    } catch (e) {
      print(' SAHAr Error decoding base64 image: $e');
      return null;
    }
  }

  // Helper method to check if profile picture is available
  bool get hasProfilePicture => profilePicture != null && profilePicture!.isNotEmpty;

  // Helper method to get the image format from base64 string
  String? get imageFormat {
    if (profilePicture == null || !profilePicture!.contains('data:image/')) {
      return null;
    }

    try {
      final prefix = profilePicture!.split(';')[0];
      return prefix.split('/')[1]; // Returns 'jpeg', 'png', etc.
    } catch (e) {
      return null;
    }
  }
}