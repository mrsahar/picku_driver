import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pick_u_driver/utils/picku_appbar.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: PickUAppBar(
          title: "Notifications",
          onBackPressed: () {
            Get.back();
          },
        ),
      body: const Center(
        child: Text(
          "No notifications yet",
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
