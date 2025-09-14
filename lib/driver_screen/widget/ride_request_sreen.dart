import 'package:flutter/material.dart';
import 'package:flutter_dash/flutter_dash.dart';

Widget RideRequestScreen(BuildContext context) {
  final theme = Theme.of(context);
  var brightness = MediaQuery.of(context).platformBrightness;
  final isDarkMode = brightness == Brightness.dark;
  final inputBorderColor = isDarkMode ? Colors.grey[700] : Colors.grey[300];
  return Column(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16.0),
            topRight: Radius.circular(16.0),
          ),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withOpacity(0.3),
              blurRadius: 10.0,
              offset: const Offset(0, -4), // Shadow at the top
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 50,
                height: 3,
                decoration: BoxDecoration(
                  color: inputBorderColor,
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Ride Request",
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "5 mins Away",
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6.0),
                Divider(color: theme.dividerColor, thickness: 0.4),
                // Driver Info Card
                Padding(
                  padding: const EdgeInsets.all(6.0),
                  child: Column(
                    children: [
                      // Driver Profile Picture and Name
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 36.0,
                            backgroundImage: AssetImage('assets/img/u2.png'),
                          ),
                          const SizedBox(width: 16.0),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Esther Howard",
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                "Cash Payment",
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.hintColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12.0),
                      // Pickup and Drop-Off Info
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            children: [
                              const SizedBox(height: 3),
                              Icon(
                                Icons.circle,
                                size: 16,
                                color: theme.colorScheme.primary,
                              ),
                              Dash(
                                direction: Axis.vertical,
                                length: 36,
                                dashLength: 5,
                                dashColor: theme.dividerColor,
                              ),
                              const SizedBox(height: 3),
                              Icon(
                                Icons.location_on,
                                size: 16,
                                color: theme.colorScheme.error,
                              ),
                            ],
                          ),
                          const SizedBox(width: 8), // Add spacing between the columns
                          Expanded( // Ensures the column next to the icons doesn't cause layout issues
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "6391 Elgin St. Celina, Delaware",
                                  style: theme.textTheme.bodySmall!.copyWith(
                                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                                  ),
                                ),
                                SizedBox(
                                  height: 40, // Define the size of the Stack
                                  child: Stack(
                                    children: [
                                      Align(
                                        alignment: Alignment.topRight,
                                        child: Container(
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.surface, // Solid white
                                              border: Border.all(
                                                color: theme.dividerColor,
                                                width: 0.4,
                                              ),
                                              borderRadius: BorderRadius.circular(8.0),
                                            ),
                                            padding: const EdgeInsets.all(8.0),
                                            child: Text(
                                              "10 mins trip",
                                              style: theme.textTheme.labelSmall,
                                            ),
                                          ),
                                      ),
                                      Align(
                                        alignment: Alignment.center,
                                        child: Padding(
                                          padding: const EdgeInsets.only(right: 90.0),
                                          child: Divider(
                                            color: theme.dividerColor,
                                            thickness: 0.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  "1901 Thornridge Cir. Shiloh",
                                  style: theme.textTheme.bodySmall!.copyWith(
                                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 30,
                      ),
                      // Time and Buttons
                      SizedBox(
                        width: double.infinity, // Ensure the Row takes up all available width
                        child: Row(
                          children: [
                            // Decline Button
                            ElevatedButton(
                              onPressed: () {},
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent.withOpacity(0.1),
                                  elevation: 0,
                                  foregroundColor: theme.colorScheme.error,
                                  side: BorderSide.none),
                              child: const Text("Decline"),
                            ),
                            const SizedBox(width: 8.0), // Space between the buttons

                            // Accept Button
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: () {
                                  // Handle accept action
                                },
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                ),
                                child: const Text("Accept"),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}
