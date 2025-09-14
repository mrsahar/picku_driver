import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pick_u_driver/driver_screen/car_doc_screen.dart';
import 'package:pick_u_driver/driver_screen/main_map.dart';
import 'package:pick_u_driver/driver_screen/request/bank_account_detail_screen.dart';
import 'package:pick_u_driver/driver_screen/request/driving_license_upload_page.dart';
import 'package:pick_u_driver/driver_screen/request/profile_picture_screen.dart';
import 'package:pick_u_driver/driver_screen/widget/submit_screen.dart';

class RequiredDocuments extends StatelessWidget {
  const RequiredDocuments({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.onPrimary,
      appBar: AppBar(
        title: Text(
          'Welcome!, Esther',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black
                : Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Required Steps Section
            Text(
              'Required Steps',
              style: textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12.0),
            _buildListTile(
              context,
              title: 'Profile Picture',
              onTap: () {
                // Navigate to Profile Picture Page
                Get.to(() => const ProfilePictureScreen());
              },
            ),
            _buildListTile(
              context,
              title: 'Bank Account Details',
              onTap: () {
                // Navigate to Bank Account Page
                Get.to(() => const BankAccountDetailsScreen());
              },
            ),
            _buildListTile(
              context,
              title: 'Driving Details',
              onTap: () {
                // Navigate to Driving Details Page
                Get.to(() => const DrivingLicensePage());
              },
            ),
            _buildListTile(
              context,
              title: 'Add Car',
              onTap: () {
                // Navigate to Driving Details Page
                Get.to(() => const CarDocumentsScreen());
              },
            ),
            const SizedBox(height: 24.0),

            // Submitted Steps Section
            Text(
              'Submitted Steps',
              style: textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12.0),
            _buildListTile(
              context,
              title: 'Government ID',
              onTap: () {
                // Navigate to Government ID Page

                showVerificationBottomSheet(context);
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
             Get.to(() => const MainMap());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
            child: Text(
              'Continue',
              style: textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black
                    : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper Method to Create a List Tile
  Widget _buildListTile(BuildContext context, {required String title, required VoidCallback onTap}) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 0.0, horizontal: 16.0),
        tileColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        title: Text(
          title,
          style: theme.textTheme.bodyMedium,
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: theme.colorScheme.primary,
        ),
        onTap: onTap,
      ),
    );
  }
}
