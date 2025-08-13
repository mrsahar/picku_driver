import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:pick_u_driver/static_screen/collect_cash.dart';

Widget FindingJob(BuildContext context) {
  final theme = Theme.of(context);
  var brightness = MediaQuery.of(context).platformBrightness;
  final isDarkMode = brightness == Brightness.dark;
  final inputBorderColor = isDarkMode ? Colors.grey[700] : Colors.grey[300];

  return Column(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      Material( // Wrap the container in Material
        color: Colors.transparent, // To match the parent background
        child: Container(
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title Section
                  // Driver Info Card
                  ElevatedButton(
                    onPressed: () {
                      // Add OTP action here
                      Get.to(() => CollectCashScreen());
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    child: const Text('Finding Jobs'),
                  ),
                ],
              ),
        ),
      ),
    ],
  );
}
