import 'package:flutter/material.dart';

class CancelRideScreen extends StatefulWidget {
  const CancelRideScreen({super.key});

  @override
  _CancelRideScreenState  createState() => _CancelRideScreenState();
}

class _CancelRideScreenState extends State<CancelRideScreen> {
  // To store the selected reason
  String? _selectedReason = 'Rider Not Available';
  final TextEditingController _otherReasonController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    Color primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: Text('Cancel Ride'),
        backgroundColor: primaryColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
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
            // Information Text
            Text(
              'Please select the reason for cancellations:',
              style: TextStyle(fontSize: 16.0),
            ),
            SizedBox(height: 20.0),

            // Radio buttons for selection
            _buildRadioOption('Rider Not Available'),
            _buildRadioOption('Rider want to book another cab'),
            _buildRadioOption('Rider Misbehave'),
            _buildRadioOption('Taxi Breakdown'),
            _buildRadioOption('Puncture'),

            // Other option with a text field for input
            _buildRadioOption('Other'),
            if (_selectedReason == 'Other') ...[
              SizedBox(height: 10.0),
              TextField(
                controller: _otherReasonController,
                decoration: InputDecoration(
                  labelText: 'Enter your Reason',
                  border: OutlineInputBorder(),
                  contentPadding:
                  EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
                ),
                maxLines: 4,
              ),
            ],
            SizedBox(height: 20.0),

            // Cancel Ride Button
            ElevatedButton(
              onPressed: () {
                // Handle cancel ride action
                print(' SAHAr Cancel Ride pressed');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: EdgeInsets.symmetric(vertical: 15.0),
              ),
              child: Text('Cancel Ride'),
            ),
          ],
        ),
      ),
    );
  }

  // Helper function to build radio button options
  Widget _buildRadioOption(String label) {
    return Row(
      children: <Widget>[
        Radio<String>(
          value: label,
          groupValue: _selectedReason,
          onChanged: (value) {
            setState(() {
              _selectedReason = value;
            });
          },
        ),
        Text(label),
      ],
    );
  }
}
