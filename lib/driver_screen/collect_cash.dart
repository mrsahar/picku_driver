import 'package:flutter/material.dart';
import 'package:flutter_dash/flutter_dash.dart';
import 'package:get/get.dart';

import 'package:pick_u_driver/driver_screen/earning_widget.dart';

class CollectCashScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Collect Cash'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          Container(
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(50.0),
                              color: theme.colorScheme.primary
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Icon(
                                Icons.account_balance_wallet,
                                size: 48,
                                color: theme.colorScheme.surface,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Collect Cash',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
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
                                            child: Padding(
                                              padding: const EdgeInsets.only(top: 5.0),
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: theme.colorScheme.surface, // Solid white
                                                  border: Border.all(
                                                    color: theme.dividerColor,
                                                    width: 0.5,
                                                  ),
                                                  borderRadius: BorderRadius.circular(8.0),
                                                ),
                                                padding: const EdgeInsets.all(6.0),
                                                child: Text(
                                                  "10 mins trip",
                                                  style: theme.textTheme.bodySmall,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Align(
                                            alignment: Alignment.center,
                                            child: Padding(
                                              padding: const EdgeInsets.only(right: 85.0),
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
                          Dash(
                            direction: Axis.horizontal,
                            length: context.width * .8,
                            // Bounded width
                            dashLength: 6,
                            dashThickness: 1.5,
                            dashGap: 4,
                            dashColor: theme.dividerColor,
                          ), const SizedBox(height: 16),
                          const ListTile(
                            leading: CircleAvatar(
                              backgroundImage: AssetImage("assets/img/u2.png"),
                            ),
                            title: Text('Estger Howard'),
                            subtitle: Text('Cash Payment'),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(16.0),
                              bottomRight: Radius.circular(16.0))),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Amount',
                              style: TextStyle(color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.black
                                  : Colors.white,),
                            ),
                            Text(
                              '\$12.5',
                              style: TextStyle(color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.black
                                  : Colors.white,),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Get.to(() => const TodayEarningsWidget());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: const Text('Cash Collected'),
              ),
            )
          ],
        ),
      ),
    );
  }
}
