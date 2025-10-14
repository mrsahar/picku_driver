// pages/driver_profile_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pick_u_driver/controllers/driver_profile_controller.dart';

class DriverProfilePage extends StatelessWidget {
  final DriverProfileController controller = Get.find<DriverProfileController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Driver Profile'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Obx(() {
        // Show loading screen while fetching profile
        if (controller.isFetchingProfile.value) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading profile...'),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Form(
            key: controller.formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Personal Information Section
                _buildSectionHeader(context, 'Personal Information', Icons.person),
                SizedBox(height: 16),
                _buildNameField(),
                SizedBox(height: 16),
                _buildPhoneField(),
                SizedBox(height: 16),
                _buildAddressField(),

                SizedBox(height: 32),

                // Driver License Section
                _buildSectionHeader(context, 'Driver License', Icons.credit_card),
                SizedBox(height: 16),
                _buildLicenseField(),
                SizedBox(height: 16),
                _buildSinField(),

                SizedBox(height: 32),

                // Vehicle Information Section
                _buildSectionHeader(context, 'Vehicle Information', Icons.directions_car),
                SizedBox(height: 16),
                _buildCarPlateField(),
                SizedBox(height: 16),
                _buildCarVinField(),
                SizedBox(height: 16),
                _buildCarRegistrationField(),
                SizedBox(height: 16),
                _buildCarInsuranceField(),

                SizedBox(height: 32),

                // Submit Button
                _buildSubmitButton(context),

                SizedBox(height: 20),
              ],
            ),
          ),
        );
      }),
    );
  }



  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha:0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).primaryColor,
            size: 20,
          ),
        ),
        SizedBox(width: 12),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: controller.nameController,
      decoration: InputDecoration(
        labelText: 'Full Name *',
        hintText: 'Enter your full name',
        prefixIcon: Icon(Icons.person),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      textCapitalization: TextCapitalization.words,
      validator: (value) => controller.validateRequired(value, 'Name'),
    );
  }

  Widget _buildPhoneField() {
    return TextFormField(
      controller: controller.phoneController,
      decoration: InputDecoration(
        labelText: 'Phone Number *',
        hintText: 'Enter your phone number',
        prefixIcon: Icon(Icons.phone),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      keyboardType: TextInputType.phone,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      validator: controller.validatePhoneNumber,
    );
  }

  Widget _buildAddressField() {
    return TextFormField(
      controller: controller.addressController,
      decoration: InputDecoration(
        labelText: 'Address *',
        hintText: 'Enter your full address',
        prefixIcon: Icon(Icons.location_on),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      maxLines: 2,
      textCapitalization: TextCapitalization.words,
      validator: (value) => controller.validateRequired(value, 'Address'),
    );
  }

  Widget _buildLicenseField() {
    return TextFormField(
      controller: controller.licenseController,
      decoration: InputDecoration(
        labelText: 'Driver\'s License Number *',
        hintText: 'Enter your license number',
        prefixIcon: Icon(Icons.credit_card),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      textCapitalization: TextCapitalization.characters,
      validator: (value) => controller.validateRequired(value, 'License Number'),
    );
  }

  Widget _buildSinField() {
    return TextFormField(
      controller: controller.sinController,
      decoration: InputDecoration(
        labelText: 'SIN (Social Insurance Number) *',
        hintText: 'Enter your SIN',
        prefixIcon: Icon(Icons.security),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      validator: (value) => controller.validateRequired(value, 'SIN'),
    );
  }

  Widget _buildCarPlateField() {
    return TextFormField(
      controller: controller.carPlateController,
      decoration: InputDecoration(
        labelText: 'Car License Plate *',
        hintText: 'Enter your license plate',
        prefixIcon: Icon(Icons.confirmation_number),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      textCapitalization: TextCapitalization.characters,
      validator: (value) => controller.validateRequired(value, 'License Plate'),
    );
  }

  Widget _buildCarVinField() {
    return TextFormField(
      controller: controller.carVinController,
      decoration: InputDecoration(
        labelText: 'Car VIN Number *',
        hintText: 'Enter 17-character VIN',
        prefixIcon: Icon(Icons.code),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        helperText: 'Vehicle Identification Number (17 characters)',
      ),
      textCapitalization: TextCapitalization.characters,
      maxLength: 17,
      validator: controller.validateVin,
    );
  }

  Widget _buildCarRegistrationField() {
    return TextFormField(
      controller: controller.carRegistrationController,
      decoration: InputDecoration(
        labelText: 'Car Registration *',
        hintText: 'Enter registration number',
        prefixIcon: Icon(Icons.description),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      textCapitalization: TextCapitalization.characters,
      validator: (value) => controller.validateRequired(value, 'Car Registration'),
    );
  }

  Widget _buildCarInsuranceField() {
    return TextFormField(
      controller: controller.carInsuranceController,
      decoration: InputDecoration(
        labelText: 'Car Insurance *',
        hintText: 'Enter insurance policy number',
        prefixIcon: Icon(Icons.shield),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      validator: (value) => controller.validateRequired(value, 'Car Insurance'),
    );
  }

  Widget _buildSubmitButton(BuildContext context) {
    return Obx(() => SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: controller.isSubmitting.value
            ? null
            : controller.updateDriverProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 2,
        ),
        child: controller.isSubmitting.value
            ? SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        )
            : Text(
          'Update Profile',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ));
  }
}