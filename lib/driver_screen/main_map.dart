import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';
import 'package:pick_u_driver/authentication/profile_screen.dart';
import 'package:pick_u_driver/core/sharePref.dart';
import 'package:pick_u_driver/driver_screen/main_screen/home_screen.dart';
import 'package:pick_u_driver/routes/app_routes.dart';
import 'package:pick_u_driver/utils/profile_widget_menu.dart';
import 'package:pick_u_driver/utils/theme/mcolors.dart';

class MainMap extends StatefulWidget {
  const MainMap({super.key});

  @override
  State<MainMap> createState() => _MainMapState();
}

class _MainMapState extends State<MainMap> {
   final _currentIndex = 0;

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
        child: Container(
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
                          Icon(LineAwesomeIcons.at_solid, size: 18.0,color: MColor.trackingOrange,),
                          SizedBox(width: 2.0),
                          FutureBuilder<String?>(
                            future: SharedPrefsService.getUserFullName(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const SizedBox(
                                  height: 14.0,
                                  child: CircularProgressIndicator(strokeWidth: 1.5),
                                );
                              }

                              return Text(
                                snapshot.data ?? 'Guest',
                                style: const TextStyle(fontSize: 14.0),
                              );
                            },
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
                    Get.toNamed(AppRoutes.profileScreen);
                  }),
              ProfileMenuWidget(
                  title: "History",
                  icon: LineAwesomeIcons.history_solid,
                  onPress: () {
                    Get.toNamed(AppRoutes.rideHistory);
                  }),
              Container(height: 8),ProfileMenuWidget(
                  title: "Scheduled Ride",
                  icon: LineAwesomeIcons.comment,
                  onPress: () {
                    Get.toNamed(AppRoutes.scheduledRideHistory);
                  }),
              ProfileMenuWidget(
                  title: "Wallet",
                  icon: LineAwesomeIcons.wallet_solid,
                  onPress: () {}),
              ProfileMenuWidget(
                  title: "Settings",
                  icon: LineAwesomeIcons.tools_solid,
                  onPress: () {
                   // Get.to(() => const SelectCarPage());
                  }),
              ProfileMenuWidget(
                  title: "Feedback",
                  icon: LineAwesomeIcons.comment,
                  onPress: () {
                    //Get.to(() => const PaymentMethodsPage());
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
                    Get.to(() => logout());
                  }),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          pageList.elementAt(_currentIndex),
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

  Future<void> logout() async {
    try {
      bool? confirmed = await Get.dialog<bool>(
        AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Get.back(result: true),
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        // Clear user data from SharedPreferences
        await SharedPrefsService.clearUserData();

        // Navigate to login screen and remove all previous routes
        Get.offAllNamed('/login');

        Get.snackbar('Success', 'Logged out successfully');
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to logout: ${e.toString()}');
    }
  }
}
