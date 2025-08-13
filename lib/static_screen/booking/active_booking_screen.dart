import 'package:flutter/material.dart';

class ActiveBookingsPage extends StatelessWidget {
  const ActiveBookingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: 3, // Number of bookings
        itemBuilder: (context, index) {
          return BookingCard(
            name: "Jenny Wilson",
            crn: "#854HG23",
            distance: "4.5 Mile",
            duration: "4 mins",
            pricePerMile: "\$1.25/mile",
            date: "Oct 18, 2023",
            time: "08:00 AM",
            pickup: "6391 Elgin St. Celina, Delaware",
            dropoff: "1901 Thornridge Cir. Shiloh",
            carType: "Sedan",
            theme: theme,
          );
        },
      ),
    );
  }
}

class BookingCard extends StatelessWidget {
  final String name;
  final String crn;
  final String distance;
  final String duration;
  final String pricePerMile;
  final String date;
  final String time;
  final String pickup;
  final String dropoff;
  final String carType;
  final ThemeData theme;

  const BookingCard({
    Key? key,
    required this.name,
    required this.crn,
    required this.distance,
    required this.duration,
    required this.pricePerMile,
    required this.date,
    required this.time,
    required this.pickup,
    required this.dropoff,
    required this.carType,
    required this.theme,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
            Row(
              children: [
                const CircleAvatar(
                  backgroundImage: AssetImage("assets/img/user_placeholder.png"), // Replace with a real image
                  radius: 24,
                ),
                const SizedBox(width: 16.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "CRN : $crn",
                        style: theme.textTheme.bodySmall?.copyWith(
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
                  style: theme.textTheme.bodySmall,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Booking Car Type:",
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  carType,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

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
          style: theme.textTheme.bodySmall,
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
