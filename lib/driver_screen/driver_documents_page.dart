import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pick_u_driver/controllers/driver_documents_controller.dart';
import '../utils/theme/mcolors.dart';

class DriverDocumentsPage extends GetView<DriverDocumentsController> {
  const DriverDocumentsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: MColor.primaryNavy,
        elevation: 0,
        title: Text(
          'Upload Documents',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Get.back(),
        ),
      ),
      body: Obx(() {
        return Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Section
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: MColor.primaryNavy.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: MColor.primaryNavy,
                          size: 24,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Please upload clear images of all required documents. Only PNG and JPG formats are accepted.',
                            style: TextStyle(
                              color: MColor.primaryNavy,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),

                  // License Image
                  _buildImageUploadSection(
                    title: 'License Image',
                    subtitle: 'Upload your driving license',
                    icon: Icons.badge_outlined,
                    imageType: ImageType.license,
                    selectedImage: controller.licenseImage.value,
                  ),
                  SizedBox(height: 16),

                  // Registration Image
                  _buildImageUploadSection(
                    title: 'Registration Image',
                    subtitle: 'Upload vehicle registration document',
                    icon: Icons.description_outlined,
                    imageType: ImageType.registration,
                    selectedImage: controller.registrationImage.value,
                  ),
                  SizedBox(height: 16),

                  // Insurance Image
                  _buildImageUploadSection(
                    title: 'Insurance Image',
                    subtitle: 'Upload vehicle insurance document',
                    icon: Icons.security_outlined,
                    imageType: ImageType.insurance,
                    selectedImage: controller.insuranceImage.value,
                  ),
                  SizedBox(height: 16),

                  // Selfie Image
                  _buildImageUploadSection(
                    title: 'Selfie Image',
                    subtitle: 'Upload a clear selfie photo',
                    icon: Icons.person_outline,
                    imageType: ImageType.selfie,
                    selectedImage: controller.selfieImage.value,
                  ),
                  SizedBox(height: 32),

                  // Upload Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: controller.isUploading.value
                          ? null
                          : () => controller.uploadDocuments(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MColor.primaryNavy,
                        disabledBackgroundColor: MColor.primaryNavy.withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: controller.isUploading.value
                          ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Uploading...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      )
                          : Text(
                        'Upload Documents',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                ],
              ),
            ),

            // Loading Overlay
            if (controller.isUploading.value)
              Container(
                color: Colors.black26,
                child: Center(
                  child: Card(
                    margin: EdgeInsets.all(32),
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              MColor.primaryNavy,
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Uploading your documents...',
                            style: TextStyle(
                              fontSize: 16,
                              color: MColor.primaryNavy,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }

  Widget _buildImageUploadSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required ImageType imageType,
    required File? selectedImage,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selectedImage != null
              ? MColor.primaryNavy.withOpacity(0.3)
              : Colors.grey[300]!,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: MColor.primaryNavy.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: MColor.primaryNavy,
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (selectedImage != null)
                  Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 24,
                  ),
              ],
            ),
          ),

          // Image Preview or Upload Button
          if (selectedImage != null)
            Column(
              children: [
                Divider(height: 1, color: Colors.grey[300]),
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          selectedImage,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  controller.showImageSourceDialog(imageType),
                              icon: Icon(Icons.refresh, size: 18),
                              label: Text('Change'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: MColor.primaryNavy,
                                side: BorderSide(color: MColor.primaryNavy),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => controller.removeImage(imageType),
                              icon: Icon(Icons.delete_outline, size: 18),
                              label: Text('Remove'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: BorderSide(color: Colors.red),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            )
          else
            Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: OutlinedButton.icon(
                onPressed: () => controller.showImageSourceDialog(imageType),
                icon: Icon(Icons.add_photo_alternate, size: 20),
                label: Text('Select Image'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: MColor.primaryNavy,
                  side: BorderSide(color: MColor.primaryNavy, width: 1.5),
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  minimumSize: Size(double.infinity, 48),
                ),
              ),
            ),
        ],
      ),
    );
  }
}