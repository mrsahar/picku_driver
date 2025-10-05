import 'package:flutter/material.dart';

class LocationAccessScreen extends StatelessWidget {
  const LocationAccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Color primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Enable Location Access'),
        backgroundColor: primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.location_on,
              size: 100.0,
              color: primaryColor,
            ),
            const SizedBox(height: 20.0),
            const Text(
              'Enable Location Access',
              style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10.0),
            const Text(
              'To ensure a seamless and efficient experience, allow us access to your location.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16.0),
            ),
            const SizedBox(height: 30.0),
            ElevatedButton(
              onPressed: () {
                // Handle location access
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 30.0),
              ),
              child: const Text('Allow Location Access'),
            ),
            TextButton(
              onPressed: () {
                // Handle maybe later
              },
              style: TextButton.styleFrom(
                foregroundColor: primaryColor,
              ),
              child: const Text('Maybe Later'),
            ),
          ],
        ),
      ),
    );
  }
}
