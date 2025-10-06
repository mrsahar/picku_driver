import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pick_u_driver/core/global_variables.dart';
import 'package:pick_u_driver/models/driver_documents_response.dart';
import 'package:pick_u_driver/providers/api_provider.dart';
import 'package:pick_u_driver/utils/theme/mcolors.dart';

class DriverDocumentsController extends GetxController {
  final ApiProvider _apiProvider = Get.find<ApiProvider>();
  final ImagePicker _picker = ImagePicker();

  // Observable variables for images
  Rx<File?> licenseImage = Rx<File?>(null);
  Rx<File?> registrationImage = Rx<File?>(null);
  Rx<File?> insuranceImage = Rx<File?>(null);
  Rx<File?> selfieImage = Rx<File?>(null);

  // Loading state
  RxBool isUploading = false.obs;

  // Allowed image formats
  final List<String> _allowedExtensions = ['png', 'jpg', 'jpeg'];

  @override
  void onInit() {
    super.onInit();
    print(' SAHAr 📸 Driver Documents Controller Initialized');
  }

  // Pick image from camera or gallery
  Future<void> pickImage(ImageType imageType, ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        // Validate file extension
        final String extension = pickedFile.path.split('.').last.toLowerCase();
        if (!_allowedExtensions.contains(extension)) {
          Get.snackbar(
            'Invalid Format',
            'Please select only PNG or JPG images',
            snackPosition: SnackPosition.TOP,
            margin: EdgeInsets.all(16),
          );
          return;
        }

        final File imageFile = File(pickedFile.path);

        // Assign to appropriate variable based on type
        switch (imageType) {
          case ImageType.license:
            licenseImage.value = imageFile;
            print(' SAHAr ✅ License image selected');
            break;
          case ImageType.registration:
            registrationImage.value = imageFile;
            print(' SAHAr ✅ Registration image selected');
            break;
          case ImageType.insurance:
            insuranceImage.value = imageFile;
            print(' SAHAr ✅ Insurance image selected');
            break;
          case ImageType.selfie:
            selfieImage.value = imageFile;
            print(' SAHAr ✅ Selfie image selected');
            break;
        }
      }
    } catch (e) {
      print(' SAHAr 💥 Error picking image: $e');
      Get.snackbar(
        'Error',
        'Failed to pick image: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: EdgeInsets.all(16),
      );
    }
  }

  // Show bottom sheet for image source selection
  void showImageSourceDialog(ImageType imageType) {
    Get.bottomSheet(
      Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Choose Image Source',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: MColor.primaryNavy,
              ),
            ),
            SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.camera_alt, color: MColor.primaryNavy),
              title: Text('Camera'),
              onTap: () {
                Get.back();
                pickImage(imageType, ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: MColor.primaryNavy),
              title: Text('Gallery'),
              onTap: () {
                Get.back();
                pickImage(imageType, ImageSource.gallery);
              },
            ),
            SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // Remove selected image
  void removeImage(ImageType imageType) {
    switch (imageType) {
      case ImageType.license:
        licenseImage.value = null;
        break;
      case ImageType.registration:
        registrationImage.value = null;
        break;
      case ImageType.insurance:
        insuranceImage.value = null;
        break;
      case ImageType.selfie:
        selfieImage.value = null;
        break;
    }
  }

  // Validate all images are selected
  bool _validateImages() {
    if (licenseImage.value == null) {
      _showErrorSnackbar('License image is required');
      return false;
    }
    if (registrationImage.value == null) {
      _showErrorSnackbar('Registration image is required');
      return false;
    }
    if (insuranceImage.value == null) {
      _showErrorSnackbar('Insurance image is required');
      return false;
    }
    if (selfieImage.value == null) {
      _showErrorSnackbar('Selfie image is required');
      return false;
    }
    return true;
  }

  // Upload documents
  Future<void> uploadDocuments() async {
    // Validate all images are selected
    if (!_validateImages()) {
      return;
    }

    try {
      isUploading.value = true;

      // Get user ID from GlobalVariables
      final String driverId = GlobalVariables.instance.userId;
      if (driverId.isEmpty) {
        _showErrorSnackbar('Driver ID not found. Please login again.');
        isUploading.value = false;
        return;
      }

      print(' SAHAr 🚀 Starting document upload for driver: $driverId');

      // Read files as bytes
      final licenseBytes = await licenseImage.value!.readAsBytes();
      final registrationBytes = await registrationImage.value!.readAsBytes();
      final insuranceBytes = await insuranceImage.value!.readAsBytes();
      final selfieBytes = await selfieImage.value!.readAsBytes();

      print(' SAHAr 📖 Files read successfully');
      print(' SAHAr 📏 License size: ${licenseBytes.length} bytes');
      print(' SAHAr 📏 Registration size: ${registrationBytes.length} bytes');
      print(' SAHAr 📏 Insurance size: ${insuranceBytes.length} bytes');
      print(' SAHAr 📏 Selfie size: ${selfieBytes.length} bytes');

      // Get file extensions
      final licenseExt = licenseImage.value!.path.split('.').last.toLowerCase();
      final registrationExt = registrationImage.value!.path.split('.').last.toLowerCase();
      final insuranceExt = insuranceImage.value!.path.split('.').last.toLowerCase();
      final selfieExt = selfieImage.value!.path.split('.').last.toLowerCase();

      // Determine content types
      String getContentType(String ext) {
        switch (ext) {
          case 'jpg':
          case 'jpeg':
            return 'image/jpeg';
          case 'png':
            return 'image/png';
          default:
            return 'image/jpeg';
        }
      }

      // Create a Map to pass file data to API provider
      final fileData = {
        'driverId': driverId,
        'files': {
          'LicenseImage': {
            'bytes': licenseBytes,
            'filename': 'license.$licenseExt',
            'contentType': getContentType(licenseExt),
          },
          'RegistrationImage': {
            'bytes': registrationBytes,
            'filename': 'registration.$registrationExt',
            'contentType': getContentType(registrationExt),
          },
          'InsuranceImage': {
            'bytes': insuranceBytes,
            'filename': 'insurance.$insuranceExt',
            'contentType': getContentType(insuranceExt),
          },
          'SelfieImage': {
            'bytes': selfieBytes,
            'filename': 'selfie.$selfieExt',
            'contentType': getContentType(selfieExt),
          },
        },
      };

      print(' SAHAr 📤 File data prepared with 4 files');

      // Make API call using uploadMultipart
      final response = await _apiProvider.uploadMultipart(
        '/api/Drivers/upload-images',
        fileData,
      );

      isUploading.value = false;

      if (response.statusCode == 200) {
        print(' SAHAr ✅ Documents uploaded successfully');

        // Parse response
        final responseData = DriverDocumentsResponse.fromJson(response.body);

        // Navigate to VerifyMessageScreen with success message
        Get.offAllNamed(
          '/verify-message', // Update this route name as per your routes
          arguments: {
            'message': responseData.message.isNotEmpty
                ? responseData.message
                : 'Documents uploaded successfully! Please wait for admin verification.',
          },
        );
      } else {
        print('SAHAr ❌ Upload failed with status: ${response.statusCode}, message: ${response.statusText}, body: ${response.body}');

        _showErrorSnackbar(
          'Upload failed. Please check your images and try again.\nError: ${response.statusText ?? 'Unknown error'}',
        );
      }
    } catch (e) {
      isUploading.value = false;
      print(' SAHAr 💥 Exception during upload: $e');
      _showErrorSnackbar(
        'Failed to upload documents. Please check your internet connection and try again.',
      );
    }
  }

  // Show error snackbar
  void _showErrorSnackbar(String message) {
    Get.snackbar(
      'Error',
      message,
      snackPosition: SnackPosition.TOP,
      margin: EdgeInsets.all(16),
      duration: Duration(seconds: 4),
    );
  }

  @override
  void onClose() {
    print(' SAHAr 📸 Driver Documents Controller Disposed');
    super.onClose();
  }
}

// Enum for image types
enum ImageType {
  license,
  registration,
  insurance,
  selfie,
}
