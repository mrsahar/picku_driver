import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pick_u_driver/driver_screen/add_car_screen.dart';

class CarDocumentsScreen extends StatelessWidget {
  const CarDocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Color primaryColor = Theme.of(context).primaryColor;
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.onPrimary,
      appBar: AppBar(
        title: const Text('Car Documents'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Navigate back
            Navigator.pop(context);
          },
        ),centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: <Widget>[
          // List of car documents
          Text(
            'Required Steps',
            style: textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),const SizedBox(height: 12.0),
          _buildListItem(context, 'Car PUC', primaryColor),
          _buildListItem(context, 'Car Insurance', primaryColor),
          _buildListItem(context, 'Car Registration Certificate', primaryColor),
          _buildListItem(context, 'Car Permit', primaryColor),
        ],
      ),
    );
  }

  // Helper function to build the list items
  Widget _buildListItem(BuildContext context, String title, Color primaryColor) {
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: ListTile(
        title: Text(
          title,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: primaryColor,
        ),
        onTap: () {
          Get.to(() => const AddCarScreen());
          print(' SAHAr $title tapped');
        },
      ),
    );
  }
}
