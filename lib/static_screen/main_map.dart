import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';
import 'package:pick_u_driver/static_screen/main_screen/home_screen.dart';
import 'package:pick_u_driver/utils/profile_widget_menu.dart';

import '../authentication/profile_screen.dart';

class MainMap extends StatefulWidget {
  const MainMap({super.key});

  @override
  State<MainMap> createState() => _MainMapState();
}

class _MainMapState extends State<MainMap> {
 // final _currentIndex = 0;

  List<Widget> pageList = [
    const HomeScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    var isDark = MediaQuery.of(context).platformBrightness == Brightness.dark; 
    final textColor = isDark ? Colors.white : Colors.black;
    final iconColor = isDark ? Colors.orange : Colors.black;

    return Scaffold(
      drawer: Drawer(
        width: context.width * .7,
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: (isDark)
                        ? Image.asset("assets/img/only_logo.png")
                        : Image.asset("assets/img/logo.png"),
                  ),
                  const SizedBox(height: 20,),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(1.0),
                    child: Row(
                      children: [
                        Icon(LineAwesomeIcons.at_solid,
                          size: 16.0,color: Theme.of(context).colorScheme.secondary),
                        const SizedBox(width: 2.0),
                        const Text(
                          "Sherjeel",
                          style: TextStyle(fontSize: 14.0),
                        ),
                      ],
                    ),
                  )
                ],
              ),

            ),
            ProfileMenuWidget(
                title: "Home",
                icon: LineAwesomeIcons.home_solid,
                onPress: () {}),
            ProfileMenuWidget(
                title: "Profile",
                icon: LineAwesomeIcons.user_solid,
                onPress: () {
                  Get.to(() => const ProfileScreen());
                }),
            ProfileMenuWidget(
                title: "Booking",
                icon: LineAwesomeIcons.calendar_solid,
                onPress: () {
                 // Get.to(() => const BookingsPage());
                }),
            ProfileMenuWidget(
                title: "History",
                icon: LineAwesomeIcons.history_solid,
                onPress: () {
                  //Get.to(() => const HistoryScreen());
                }),
            ProfileMenuWidget(
                title: "Wallet",
                icon: LineAwesomeIcons.wallet_solid,
                onPress: () {
                 // Get.to(() => const TodayEarningsWidget());
                }),
            ProfileMenuWidget(
                title: "Settings",
                icon: LineAwesomeIcons.tools_solid,
                onPress: () {
                //  Get.to(() => const SelectCarPage());
                }),
            ProfileMenuWidget(
                title: "Feedback",
                icon: LineAwesomeIcons.comment,
                onPress: () {
                 // Get.to(() => const PaymentMethodsPage());
                }),
            Container(height: 8),
            const Divider(
              height: 1,
            ),
            ProfileMenuWidget(
                title: "Logout",
                textColor: Colors.red,
                icon: LineAwesomeIcons.sign_out_alt_solid,
                onPress: () {
                //  Get.to(() => const DriverScreen());
                }),
          ],
        ),
      ),
      body: Stack(
        children: [
          pageList.elementAt(0),
          Builder(
            builder: (context) => Positioned(
              top: 40,
              left: 10,
              child: IconButton(
                icon: const Icon(LineAwesomeIcons.bars_solid),
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
