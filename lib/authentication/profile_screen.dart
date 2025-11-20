import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';
import 'package:pick_u_driver/routes/app_routes.dart';
import 'package:pick_u_driver/utils/picku_appbar.dart';
import 'package:pick_u_driver/utils/profile_widget_menu.dart';

import '../controllers/profile_controller.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ProfileController controller = Get.find<ProfileController>();

    return Scaffold(
        appBar: PickUAppBar(
          title: "Profile",
          onBackPressed: () {
            Get.back();
          },
        ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (controller.userProfile.value == null) {
          return const Center(
            child: Text('Failed to load profile'),
          );
        }

        final user = controller.userProfile.value!;

        return SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                /// -- IMAGE
                Stack(
                  children: [
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: Obx(() {
                          if (controller.hasProfileImage) {
                            return CircleAvatar(
                              radius: 50,
                              backgroundImage: MemoryImage(controller.profileImage.value!),
                            );
                          } else {
                            return CircleAvatar(
                              radius: 50,
                              child: Icon(Icons.person, size: 50),
                            );
                          }
                        }),
                      ),
                    ),
                    // Loading indicator for image
                    if (controller.isImageLoading.value)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha:0.3),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  user.name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Text(
                  user.phoneNumber,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    final result = await Get.toNamed(
                      AppRoutes.editProfile,
                      arguments: controller.userProfile.value,
                    );
                    if (result == true) {
                      controller.refreshProfile();
                    }
                  },
                  label: Text("Edit Profile".toUpperCase()),
                  icon: const Icon(LineAwesomeIcons.edit),
                ),
                const SizedBox(height: 20),
                const Divider(color: Colors.black12),
                const SizedBox(height: 20),

                /// -- PROFILE DETAILS SECTION
                _buildProfileDetailSection('Personal Information', [
                  _buildDetailRow('Full Name', user.name),
                  _buildDetailRow('Phone', user.phoneNumber),
                  if (user.email != null && user.email!.isNotEmpty)
                    _buildDetailRow('Email', user.email!),
                  if (user.status != null && user.status!.isNotEmpty)
                    _buildDetailRow('Status', user.status!),
                ]),
                const SizedBox(height: 20),

                /// -- LICENSE & VEHICLE SECTION
                if (user.licenseNumber != null && user.licenseNumber!.isNotEmpty ||
                    user.carLicensePlate != null && user.carLicensePlate!.isNotEmpty ||
                    user.vehicleName != null && user.vehicleName!.isNotEmpty ||
                    user.vehicleColor != null && user.vehicleColor!.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProfileDetailSection('License & Vehicle Information', [
                        if (user.licenseNumber != null && user.licenseNumber!.isNotEmpty)
                          _buildDetailRow('License Number', user.licenseNumber!),
                        if (user.carLicensePlate != null && user.carLicensePlate!.isNotEmpty)
                          _buildDetailRow('Car License Plate', user.carLicensePlate!),
                        if (user.vehicleName != null && user.vehicleName!.isNotEmpty)
                          _buildDetailRow('Vehicle Name', user.vehicleName!),
                        if (user.vehicleColor != null && user.vehicleColor!.isNotEmpty)
                          _buildDetailRow('Vehicle Color', user.vehicleColor!),
                      ]),
                      const SizedBox(height: 20),
                    ],
                  ),

                /// -- PAYMENT SECTION
                if (user.stripeAccountId != null && user.stripeAccountId!.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProfileDetailSection('Payment Information', [
                        _buildDetailRow('Stripe Account ID', user.stripeAccountId!),
                      ]),
                      const SizedBox(height: 20),
                    ],
                  ),

                ProfileMenuWidget(
                  title: "Logout",
                  icon: LineAwesomeIcons.sign_out_alt_solid,
                  textColor: Colors.red,
                  endIcon: false,
                  onPress: () => controller.logout(),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  /// Helper method to build a profile detail section
  static Widget _buildProfileDetailSection(String title, List<Widget> details) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: List.generate(
              details.length,
              (index) {
                return Column(
                  children: [
                    details[index],
                    if (index < details.length - 1)
                      const Divider(height: 1, color: Colors.black12),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  /// Helper method to build a detail row
  static Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
