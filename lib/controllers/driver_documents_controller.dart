import 'dart:io';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:pick_u_driver/core/sharePref.dart';
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

      // Get user ID from SharedPreferences
      final String? driverId = await SharedPrefsService.getUserId();
      if (driverId == null || driverId.isEmpty) {
        _showErrorSnackbar('Driver ID not found. Please login again.');
        isUploading.value = false;
        return;
      }

      print(' SAHAr 🚀 Starting document upload for driver: $driverId');

      // Create FormData
      final formData = FormData({
        'DriverId': driverId,
        'LicenseImage': MultipartFile(
          licenseImage.value!,
          filename: '${driverId}_License.${licenseImage.value!.path.split('.').last}',
        ),
        'RegistrationImage': MultipartFile(
          registrationImage.value!,
          filename: '${driverId}_Registration.${registrationImage.value!.path.split('.').last}',
        ),
        'InsuranceImage': MultipartFile(
          insuranceImage.value!,
          filename: '${driverId}_Insurance.${insuranceImage.value!.path.split('.').last}',
        ),
        'SelfieImage': MultipartFile(
          selfieImage.value!,
          filename: '${driverId}_Selfie.${selfieImage.value!.path.split('.').last}',
        ),
      });

      // Make API call
      final response = await _apiProvider.postData2(
        '/api/Drivers/upload-images',
        formData,
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
        print(' SAHAr ❌ Upload failed with status: ${response.statusCode}');
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