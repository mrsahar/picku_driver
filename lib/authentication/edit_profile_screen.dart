import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';
import 'package:pick_u_driver/controllers/edit_profile_controller.dart';
import 'package:pick_u_driver/utils/picku_appbar.dart';

// Section header widget for grouping form fields
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<EditProfileController>();

    return Scaffold(
        appBar: PickUAppBar(
          title: "Edit Profile",
          onBackPressed: () {
            Get.back();
          },
        ),
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // -- IMAGE with ICON
              Obx(() => Stack(
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: controller.getProfileImageWidget(),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => controller.showImagePickerOptions(),
                      child: Container(
                        width: 35,
                        height: 35,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(100),
                          color: Colors.amberAccent,
                        ),
                        child: const Icon(
                          LineAwesomeIcons.camera_solid,
                          color: Colors.black,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              )),
              const SizedBox(height: 50),

              // -- Form Fields
              Form(
                key: controller.formKey,
                child: Column(
                  children: [
                    // Personal Information Section
                    _SectionHeader(title: "Personal Information"),

                    TextFormField(
                      controller: controller.txtUserName,
                      keyboardType: TextInputType.text,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(LineAwesomeIcons.user_check_solid),
                        labelText: "Enter Username",
                        hintText: "Username",
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter username';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    TextFormField(
                      controller: controller.txtMobile,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(LineAwesomeIcons.phone_solid),
                        labelText: "Enter Phone number",
                        hintText: "Phone Number",
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    TextFormField(
                      controller: controller.txtAddress,
                      keyboardType: TextInputType.streetAddress,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(LineAwesomeIcons.location_arrow_solid),
                        labelText: "Enter Address",
                        hintText: "Street Address",
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 30),

                    // License & Documentation Section
                    _SectionHeader(title: "License & Documentation"),

                    TextFormField(
                      controller: controller.txtLicenseNumber,
                      keyboardType: TextInputType.text,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(LineAwesomeIcons.id_card_solid),
                        labelText: "Enter License Number",
                        hintText: "Driver License Number",
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter license number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    TextFormField(
                      controller: controller.txtSin,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(LineAwesomeIcons.shield_alt_solid),
                        labelText: "Social Insurance Number",
                        hintText: "SIN",
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter SIN';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 30),

                    // Vehicle Information Section
                    _SectionHeader(title: "Vehicle Information"),

                    TextFormField(
                      controller: controller.txtVehicleName,
                      keyboardType: TextInputType.text,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(LineAwesomeIcons.car_solid),
                        labelText: "Vehicle Name/Model",
                        hintText: "e.g., Toyota Camry 2020",
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter vehicle name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    TextFormField(
                      controller: controller.txtVehicleColor,
                      keyboardType: TextInputType.text,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(LineAwesomeIcons.palette_solid),
                        labelText: "Vehicle Color",
                        hintText: "e.g., Black, White, Red",
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter vehicle color';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    TextFormField(
                      controller: controller.txtCarLicensePlate,
                      keyboardType: TextInputType.text,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(LineAwesomeIcons.car_solid),
                        labelText: "Car License Plate",
                        hintText: "e.g., ABC-1234",
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter license plate';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    TextFormField(
                      controller: controller.txtCarVin,
                      keyboardType: TextInputType.text,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(LineAwesomeIcons.car_solid),
                        labelText: "Vehicle Identification Number",
                        hintText: "VIN",
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter VIN';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    TextFormField(
                      controller: controller.txtCarRegistration,
                      keyboardType: TextInputType.text,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(LineAwesomeIcons.file_solid),
                        labelText: "Car Registration Number",
                        hintText: "Registration Number",
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter registration number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    TextFormField(
                      controller: controller.txtCarInsurance,
                      keyboardType: TextInputType.text,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(LineAwesomeIcons.file_contract_solid),
                        labelText: "Car Insurance Number",
                        hintText: "Insurance Policy Number",
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter insurance number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 30),

                    // -- Form Submit Button
                    Obx(() => ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                      ),
                      onPressed: controller.isLoading.value
                          ? null
                          : () => controller.updateProfile(),
                      label: controller.isLoading.value
                          ? const Text("Updating...")
                          : Text("Update Profile".toUpperCase()),
                      icon: controller.isLoading.value
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(LineAwesomeIcons.edit),
                    )),
                    const SizedBox(height: 20),

                    // -- Delete Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            "Want to delete your account?",
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Obx(() => ElevatedButton(
                          onPressed: controller.isLoading.value
                              ? null
                              : () => controller.deleteAccount(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                            elevation: 0,
                            foregroundColor: Colors.red,
                            shape: const StadiumBorder(),
                            side: BorderSide.none,
                          ),
                          child: const Text("Delete", style: TextStyle(fontSize: 12)),
                        )),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
