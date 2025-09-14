import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Color primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Handle back navigation
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: <Widget>[
            // Profile Picture and Edit Icon
            const Center(
              child: CircleAvatar(
                radius: 50.0,
                backgroundImage: NetworkImage(
                    'https://www.example.com/profile.jpg'), // Replace with actual image URL
              ),
            ),
            const SizedBox(height: 20.0),
            IconButton(
              icon: Icon(Icons.edit, color: primaryColor),
              onPressed: () {
                // Handle profile image change
                print('Edit Profile Image');
              },
            ),
            const SizedBox(height: 20.0),

            // User's Name
            const Center(
              child: Text(
                'Jenny Wilson',
                style: TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 30.0),

            // List of Profile Options
            _buildListItem(context, 'Your profile', primaryColor),
            _buildListItem(context, 'Notification', primaryColor),
            _buildListItem(context, 'Your Rides', primaryColor),
            _buildListItem(context, 'Pre-Booked Rides', primaryColor),
            _buildListItem(context, 'Settings', primaryColor),
            _buildListItem(context, 'Cars', primaryColor),
            _buildListItem(context, 'Help Center', primaryColor),
            _buildListItem(context, 'Privacy Policy', primaryColor),
            _buildListItem(context, 'Log out', primaryColor),
          ],
        ),
      ),
    );
  }

  // Helper function to build list items
  Widget _buildListItem(BuildContext context, String label, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: ListTile(
        title: Text(label),
        trailing: Icon(Icons.arrow_forward_ios, color: primaryColor),
        onTap: () {
          // Handle each item tap
          print('$label tapped');
        },
      ),
    );
  }
}
