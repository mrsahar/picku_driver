import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pick_u_driver/utils/picku_appbar.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: PickUAppBar(
          title: "Help Center",
          onBackPressed: () {
            Get.back();
          },
        ),
      body: const Center(
        child: Text(
          "No help content available yet",
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
