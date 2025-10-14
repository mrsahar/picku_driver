import 'package:flutter/material.dart';

class CancelledBookingsPage extends StatelessWidget {
  const CancelledBookingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Mock data for demonstration
    final cancelledBookings = [
      {
        "name": "John Doe",
        "imgName":'assets/img/u2.png',
        "crn": "#123ABC45",
        "distance": "3.2 Mile",
        "duration": "5 mins",
        "pricePerMile": "\$1.00/mile",
        "date": "Nov 30, 2023",
        "time": "09:00 AM",
        "pickup": "1234 Main St. City, State",
        "dropoff": "5678 Elm St. City, State",
        "carType": "SUV",
        "cancellationType": "Cancelled by You"
      },
      {
        "name": "Jane Smith",
        "imgName":'assets/img/user_placeholder.png',
        "crn": "#987XYZ65",
        "distance": "5.0 Mile",
        "duration": "8 mins",
        "pricePerMile": "\$1.50/mile",
        "date": "Nov 28, 2023",
        "time": "11:30 AM",
        "pickup": "4321 Oak St. City, State",
        "dropoff": "8765 Pine St. City, State",
        "carType": "Sedan",
        "cancellationType": "Cancelled by Rider"
      },
    ];

    return Scaffold(
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: cancelledBookings.length,
        itemBuilder: (context, index) {
          final booking = cancelledBookings[index];
          return BookingCard(
            name: booking["name"]!,
            crn: booking["crn"]!,
            imgName: booking["imgName"]!,
            distance: booking["distance"]!,
            duration: booking["duration"]!,
            pricePerMile: booking["pricePerMile"]!,
            date: booking["date"]!,
            time: booking["time"]!,
            pickup: booking["pickup"]!,
            dropoff: booking["dropoff"]!,
            carType: booking["carType"]!,
            cancellationType: booking["cancellationType"]!,
            theme: theme,
          );
        },
      ),
    );
  }
}

class BookingCard extends StatelessWidget {
  final String name;
  final String imgName;
  final String crn;
  final String distance;
  final String duration;
  final String pricePerMile;
  final String date;
  final String time;
  final String pickup;
  final String dropoff;
  final String carType;
  final String cancellationType;
  final ThemeData theme;

  const BookingCard({
    Key? key,
    required this.name,
    required this.imgName,
    required this.crn,
    required this.distance,
    required this.duration,
    required this.pricePerMile,
    required this.date,
    required this.time,
    required this.pickup,
    required this.dropoff,
    required this.carType,
    required this.cancellationType,
    required this.theme,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cancellationColor = cancellationType == "Cancelled by You"
        ? theme.colorScheme.primary.withValues(alpha:0.04)
        : theme.colorScheme.error.withValues(alpha:0.04);

    final cancellationTextColor = cancellationType == "Cancelled by You"
        ? theme.colorScheme.primary
        : theme.colorScheme.error;

    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.only(bottom: 16.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cancellation Type Label
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: cancellationColor,
                borderRadius: BorderRadius.circular(4.0),
              ),
              child: Text(
                cancellationType,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cancellationTextColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8.0),
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: AssetImage(imgName),
                  // Replace with a real image
                  radius: 24,
                ),
                const SizedBox(width: 16.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "CRN : $crn",
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _IconText(
                  icon: Icons.location_on,
                  text: distance,
                  theme: theme,
                ),
                _IconText(
                  icon: Icons.access_time,
                  text: duration,
                  theme: theme,
                ),
                _IconText(
                  icon: Icons.attach_money,
                  text: pricePerMile,
                  theme: theme,
                ),
              ],
            ),
            const SizedBox(height: 16.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Date & Time",
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  "$date | $time",
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
            const Divider(height: 16.0),
            _LocationDetail(
              icon: Icons.radio_button_checked,
              address: pickup,
              theme: theme,
            ),
            const SizedBox(height: 8.0),
            _LocationDetail(
              icon: Icons.location_on,
              address: dropoff,
              theme: theme,
            ),
            const SizedBox(height: 16.0),
            Text(
              "Booking Car Type: $carType",
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// _IconText and _LocationDetail widgets remain unchanged.

class _IconText extends StatelessWidget {
  final IconData icon;
  final String text;
  final ThemeData theme;

  const _IconText({
    Key? key,
    required this.icon,
    required this.text,
    required this.theme,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16.0,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 4.0),
        Text(
          text,
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _LocationDetail extends StatelessWidget {
  final IconData icon;
  final String address;
  final ThemeData theme;

  const _LocationDetail({
    Key? key,
    required this.icon,
    required this.address,
    required this.theme,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16.0,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 8.0),
        Expanded(
          child: Text(
            address,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
