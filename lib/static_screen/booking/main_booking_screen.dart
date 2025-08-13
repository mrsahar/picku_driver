import 'package:flutter/material.dart';
import 'package:pick_u_driver/static_screen/booking/active_booking_screen.dart';
import 'package:pick_u_driver/static_screen/booking/cancelled_booking_screen.dart';
import 'package:pick_u_driver/static_screen/booking/completed_bookings_screen.dart';

class BookingsPage extends StatelessWidget {
  const BookingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 3, // Number of tabs
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          title: Text(
            "Bookings",
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.black
                  : Colors.white,
            ),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context); // Go back to the previous screen
            },
          ),
          bottom: TabBar(
            labelColor: theme.colorScheme.secondary,
            unselectedLabelColor: theme.hintColor,
            indicatorColor: theme.colorScheme.secondary,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: const [
              Tab(text: "Active"),
              Tab(text: "Completed"),
              Tab(text: "Cancelled"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            ActiveBookingsPage(),
            CompletedBookingsPage(),
            CancelledBookingsPage(),
          ],
        ),
      ),
    );
  }
}






