import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';
import 'package:pick_u_driver/controllers/edit_profile_controller.dart';
import 'package:pick_u_driver/utils/picku_appbar.dart';

import '../routes/app_routes.dart';

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

                    _SectionHeader(title: "Driver Details"),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Get.toNamed(
                            AppRoutes.driverLicenseDocs,
                            arguments: controller.user.value,
                          );
                        },
                        icon: const Icon(LineAwesomeIcons.id_card_solid),
                        label: const Text('Edit License & Documentation'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Get.toNamed(
                            AppRoutes.vehicleInformation,
                            arguments: controller.user.value,
                          );
                        },
                        icon: const Icon(LineAwesomeIcons.car_solid),
                        label: const Text('Edit Vehicle Information'),
                      ),
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
