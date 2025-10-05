import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController(text: 'Esther Howard');
  final _phoneController = TextEditingController(text: '603.555.0123');
  final _emailController = TextEditingController(text: 'example@gmail.com');
  String _selectedCity = 'New Jersey, New York';

  @override
  Widget build(BuildContext context) {
    Color primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: Text('Your Profile'),
        backgroundColor: primaryColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: <Widget>[
            // Profile Picture
            Center(
              child: CircleAvatar(
                radius: 50.0,
                backgroundImage: NetworkImage(
                    'https://www.example.com/profile.jpg'), // Replace with actual image URL
              ),
            ),
            SizedBox(height: 20.0),
            IconButton(
              icon: Icon(Icons.edit, color: primaryColor),
              onPressed: () {
                // Handle profile image change
                print(' SAHAr Edit Profile Image');
              },
            ),
            SizedBox(height: 20.0),

            // Name Field
            _buildTextField('Name', _nameController, 'Enter your name'),

            // Phone Number Field
            _buildTextField('Phone Number', _phoneController, 'Enter phone number', false, true),

            // Email Field
            _buildTextField('Email', _emailController, 'Enter your email'),

            // City You Drive In Dropdown
            _buildDropdown('City You Drive In', _selectedCity, ['New Jersey, New York', 'California', 'Texas'], (value) {
              setState(() {
                _selectedCity = value!;
              });
            }),

            // Documents Link
            _buildNavigationItem('Documents', Icons.arrow_forward_ios, () {
              // Navigate to Document Details page
              print(' SAHAr Update Documents tapped');
            }),

            // Update Button
            SizedBox(height: 20.0),
            ElevatedButton(
              onPressed: () {
                // Handle update action
                print(' SAHAr Update Profile pressed');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: EdgeInsets.symmetric(vertical: 15.0),
              ),
              child: Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  // Helper function to build text fields
  Widget _buildTextField(String label, TextEditingController controller, String hintText, [bool obscureText = false, bool isPhone = false]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
        ),
      ),
    );
  }

  // Helper function to build dropdowns
  Widget _buildDropdown(String label, String selectedValue, List<String> options, Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: DropdownButtonFormField<String>(
        value: selectedValue,
        onChanged: onChanged,
        items: options.map<DropdownMenuItem<String>>((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList(),
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
      ),
    );
  }

  // Helper function to build navigation items
  Widget _buildNavigationItem(String label, IconData icon, Function onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        trailing: Icon(icon, color: Theme.of(context).primaryColor),
        onTap: () => onTap(),
      ),
    );
  }
}
