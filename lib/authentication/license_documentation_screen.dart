import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';
import 'package:pick_u_driver/controllers/edit_profile_controller.dart';
import 'package:pick_u_driver/utils/picku_appbar.dart';

class LicenseDocumentationScreen extends StatelessWidget {
  const LicenseDocumentationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<EditProfileController>();

    return Scaffold(
      appBar: PickUAppBar(
        title: 'License & Documentation',
        onBackPressed: () {
          Get.back();
        },
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: controller.licenseFormKey,
            child: Column(
              children: [
                TextFormField(
                  controller: controller.txtLicenseNumber,
                  keyboardType: TextInputType.text,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(LineAwesomeIcons.id_card_solid),
                    labelText: 'Enter License Number',
                    hintText: 'Driver License Number',
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
                    labelText: 'Social Insurance Number',
                    hintText: 'SIN',
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
                Obx(() => ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                  ),
                  onPressed: controller.isLoading.value
                      ? null
                      : () => controller.updateLicenseDocumentation(),
                  label: controller.isLoading.value
                      ? const Text('Updating...')
                      : Text('Update License'.toUpperCase()),
                  icon: controller.isLoading.value
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(LineAwesomeIcons.edit),
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

