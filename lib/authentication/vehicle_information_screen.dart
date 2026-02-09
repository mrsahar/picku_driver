import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';
import 'package:pick_u_driver/controllers/edit_profile_controller.dart';
import 'package:pick_u_driver/utils/picku_appbar.dart';

class VehicleInformationScreen extends StatelessWidget {
  const VehicleInformationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<EditProfileController>();

    return Scaffold(
      appBar: PickUAppBar(
        title: 'Vehicle Information',
        onBackPressed: () {
          Get.back();
        },
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: controller.vehicleFormKey,
            child: Column(
              children: [
                TextFormField(
                  controller: controller.txtVehicleName,
                  keyboardType: TextInputType.text,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(LineAwesomeIcons.car_solid),
                    labelText: 'Vehicle Name',
                    hintText: 'e.g., Toyota Camry 2020',
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
                    labelText: 'Vehicle Color',
                    hintText: 'e.g., Black',
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
                  decoration: const InputDecoration(
                    prefixIcon: Icon(LineAwesomeIcons.credit_card_solid),
                    labelText: 'License Plate',
                    hintText: 'Vehicle License Plate Number',
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
                  decoration: const InputDecoration(
                    prefixIcon: Icon(LineAwesomeIcons.barcode_solid),
                    labelText: 'VIN Number',
                    hintText: 'Vehicle Identification Number',
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
                    prefixIcon: Icon(LineAwesomeIcons.file_contract_solid),
                    labelText: 'Registration Number',
                    hintText: 'Vehicle Registration Number',
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
                    prefixIcon: Icon(LineAwesomeIcons.shield_alt_solid),
                    labelText: 'Insurance Number',
                    hintText: 'Vehicle Insurance Number',
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
                Obx(() => ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                  ),
                  onPressed: controller.isLoading.value
                      ? null
                      : () => controller.updateVehicleInformation(),
                  label: controller.isLoading.value
                      ? const Text('Updating...')
                      : Text('Update Vehicle Info'.toUpperCase()),
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

