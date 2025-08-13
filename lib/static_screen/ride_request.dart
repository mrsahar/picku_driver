import 'package:flutter/material.dart';

class RideRequestScreen extends StatelessWidget {
  const RideRequestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Color primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride Request'),
        backgroundColor: primaryColor,
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            showModalBottomSheet(
              context: context,
              builder: (context) => RideRequestBottomSheet(),
            );
          },
          child: const Text('Show Ride Request'),
        ),
      ),
    );
  }
}

class RideRequestBottomSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Color primaryColor = Theme.of(context).primaryColor;

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Profile Picture and Name
          const Row(
            children: <Widget>[
              CircleAvatar(
                radius: 25.0,
                backgroundImage: NetworkImage('https://www.example.com/profile.jpg'), // Replace with a valid image URL or asset
              ),
              SizedBox(width: 10.0),
              Text(
                'Esther Howard',
                style: TextStyle(
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Spacer(),
              Text(
                '5 mins Away',
                style: TextStyle(fontSize: 14.0, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 15.0),

          // Payment Method
          Row(
            children: <Widget>[
              Icon(Icons.payment, color: primaryColor),
              const SizedBox(width: 8.0),
              const Text(
                'Cash Payment',
                style: TextStyle(fontSize: 16.0),
              ),
            ],
          ),
          const SizedBox(height: 15.0),

          // Ride Information
          Row(
            children: <Widget>[
              Icon(Icons.location_on, color: primaryColor),
              const SizedBox(width: 8.0),
              const Expanded(
                child: Text(
                  '6391 Elgin St. Celina, Delaware...',
                  style: TextStyle(fontSize: 16.0),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          Row(
            children: <Widget>[
              Icon(Icons.location_on, color: primaryColor),
              const SizedBox(width: 8.0),
              const Expanded(
                child: Text(
                  '1901 Thornridge Cir. Sh...',
                  style: TextStyle(fontSize: 16.0),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Spacer(),
              const Text(
                '10 mins trip',
                style: TextStyle(fontSize: 16.0),
              ),
            ],
          ),
          const SizedBox(height: 20.0),

          // Decline and Accept buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              ElevatedButton(
                onPressed: () {
                  // Handle Decline
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 30.0),
                ),
                child: const Text('Decline'),
              ),
              ElevatedButton(
                onPressed: () {
                  // Handle Accept
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 30.0),
                ),
                child: const Text('Accept'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
