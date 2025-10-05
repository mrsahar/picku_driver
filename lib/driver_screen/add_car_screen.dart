import 'package:flutter/material.dart';

class AddCarScreen extends StatefulWidget {
  const AddCarScreen({super.key});

  @override
  _AddCarScreenState createState() => _AddCarScreenState();
}

class _AddCarScreenState extends State<AddCarScreen> {
  final _carNameController = TextEditingController();
  final _carNumberController = TextEditingController();
  String _selectedCarType = 'Select Type';
  String _selectedNoOfSeats = 'Select No. of Seats';
  String _selectedFuelType = 'Select Fuel Type';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Add New Car'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Navigate back
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: <Widget>[
            // Car Name Field
            _buildTextField('Car Name', _carNameController, 'Ex. Maruti Suzuki Swift (VXI)', false),

            // Car Type Dropdown
            _buildDropdown('Car Type', _selectedCarType, ['Select Type', 'Sedan', 'SUV', 'Hatchback'], (value) {
              setState(() {
                _selectedCarType = value!;
              });
            }),

            // No. of Seats Dropdown
            _buildDropdown('No. of Seats', _selectedNoOfSeats, ['Select No. of Seats', '2', '4', '5'], (value) {
              setState(() {
                _selectedNoOfSeats = value!;
              });
            }),

            // Car Number Field
            _buildTextField('Car Number', _carNumberController, 'Enter Car Number', false),

            // Car Fuel Type Dropdown
            _buildDropdown('Car Fuel Type', _selectedFuelType, ['Select Fuel Type', 'Petrol', 'Diesel', 'Electric'], (value) {
              setState(() {
                _selectedFuelType = value!;
              });
            }),

            // Car Documents Link
            _buildNavigationItem('Car Documents', Icons.arrow_forward_ios, () {
              // Navigate to Car Documents screen
              print(' SAHAr Car Documents tapped');
            }),

            // Car Images Link
            _buildNavigationItem('Car Images', Icons.arrow_forward_ios, () {
              // Navigate to Car Images screen
              print(' SAHAr Car Images tapped');
            }),

            // Add New Car Button
            const SizedBox(height: 20.0),
            ElevatedButton(
              onPressed: () {
                // Handle Add Car action
                print(' SAHAr Add New Car pressed');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 15.0),
              ),
              child: Text('Add New Car', style: TextStyle(color: theme.colorScheme.onPrimary)),
            ),
          ],
        ),
      ),
    );
  }

  // Helper function to build text fields
  Widget _buildTextField(String label, TextEditingController controller, String hintText, bool isPassword) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
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
          border: const OutlineInputBorder(),
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
