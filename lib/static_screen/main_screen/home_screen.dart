import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pick_u_driver/static_screen/widget/arrival_destination_widget.dart';
import 'package:pick_u_driver/static_screen/widget/arriveded_customer_location.dart';
import 'package:pick_u_driver/static_screen/widget/customer_location.dart';
import 'package:pick_u_driver/static_screen/widget/finding_job.dart';
import 'package:pick_u_driver/static_screen/widget/ride_request_sreen.dart';
import 'package:pick_u_driver/utils/light_map_theme.dart';

import '../../utils/dark_map_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Completer<GoogleMapController> _controller =
  Completer<GoogleMapController>();
  late GoogleMap googleMap;

  static const CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(31.8329711, 70.9028416),
    zoom: 14,
  );
  bool isShowingLocationWidget = true;
  int isWidget = 0;

  @override
  Widget build(BuildContext context) {
    var mediaQuery = MediaQuery.of(context);
    final size = MediaQuery.sizeOf(context);
    var brightness = mediaQuery.platformBrightness;
    final isDarkMode = brightness == Brightness.dark;

    final List<Widget> widgets = [

      KeyedSubtree(key: ValueKey(0), child: FindingJob(context)),
      KeyedSubtree(key: ValueKey(1), child: RideRequestScreen(context)),
      KeyedSubtree(key: ValueKey(2), child: CustomerLocation(context)),
      KeyedSubtree(key: ValueKey(3), child: ArrivededCustomerLocation(context)),
      KeyedSubtree(key: ValueKey(4), child: ArrivededDestination(context)),
    ];
    return Stack(
      children: [
        // Google Map
        GoogleMap(
          mapType: MapType.normal,
          style: (isDarkMode) ? darkMapTheme : lightMapTheme,
          initialCameraPosition: _kGooglePlex,
          myLocationButtonEnabled: true,
          onMapCreated: (GoogleMapController controller) {
            _controller.complete(controller);
          },
        ),
        // Custom Bottom Sheet with AnimatedSwitcher
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500), // Transition duration
            transitionBuilder: (child, animation) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 1.0), // Start from below the view
                  end: Offset.zero, // End at the current position
                ).animate(animation),
                child: child,
              );
            },
            child: widgets[isWidget],
          ),
        ),
        Positioned(
            top: 30,
            right: 0,
            child: IconButton(
              icon: const Icon(Icons.swap_horiz),
              onPressed: toggleLocationWidget,
            ))
      ],
    );
  }

  // Toggle between widgets
  void toggleLocationWidget() {
    setState(() {
      // Cycle through widget indices
      isWidget = (isWidget + 1) % 5; // Assuming you have 4 widgets in the list
    });
  }
}
