import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pick_u_driver/authentication/profile_screen.dart';
import 'package:pick_u_driver/driver_screen/main_screen/home_screen.dart';
import 'package:pick_u_driver/utils/modern_drawer.dart';

import '../core/permission_service.dart';
import '../routes/app_routes.dart';

class MainMap extends StatefulWidget {
  const MainMap({super.key});

  @override
  State<MainMap> createState() => _MainMapState();
}

class _MainMapState extends State<MainMap> {
  final _currentIndex = 0;
  PermissionService? _permissionService;

  List<Widget> pageList = [
    const HomeScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndInitialize();
  }

  /// Check permissions and initialize PermissionService if needed
  Future<void> _checkPermissionsAndInitialize() async {
    // Check if PermissionService is registered
    if (!Get.isRegistered<PermissionService>()) {
      // Check permission status without initializing service
      await _checkPermissionStatus();
      return;
    }

    _permissionService = PermissionService.to;

    // Check if permissions are ready
    if (!_permissionService!.isReady) {
      // Redirect to permission screen
      if (mounted) {
        Get.offAllNamed(AppRoutes.whyNeedPermission);
      }
      return;
    }
  }

  /// Check permission status without initializing PermissionService
  Future<void> _checkPermissionStatus() async {
    try {
      // Check permission status using Geolocator and permission_handler
      final geoPermission = await Geolocator.checkPermission();
      final permissionStatus = await Permission.location.status;

      // If permission is not granted, show permission screen
      if (geoPermission == LocationPermission.denied ||
          geoPermission == LocationPermission.deniedForever ||
          !permissionStatus.isGranted) {
        if (mounted) {
          Get.offAllNamed(AppRoutes.whyNeedPermission);
        }
        return;
      }

      // Permission is granted, check GPS
      final gpsEnabled = await Geolocator.isLocationServiceEnabled();
      if (!gpsEnabled) {
        if (mounted) {
          Get.offAllNamed(AppRoutes.whyNeedPermission);
        }
        return;
      }

      // All good, initialize PermissionService and proceed
      _permissionService = Get.put(PermissionService(), permanent: true);
    } catch (e) {
      print('Error checking permission status: $e');
      if (mounted) {
        Get.offAllNamed(AppRoutes.whyNeedPermission);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    var isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;

    // If PermissionService is not initialized, show loading or redirect
    if (_permissionService == null) {
      return Scaffold(
        backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Obx(() {
      // First check permissions
      if (!_permissionService!.isReady) {
        // Redirect to permission screen
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Get.offAllNamed(AppRoutes.whyNeedPermission);
        });
        return Scaffold(
          backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
          body: const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      // All good - show main screen
      return Scaffold(
        drawer: buildModernDrawer(context, isDark),
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

            // Show small checking overlay while checking permissions
            if (_permissionService!.isCheckingPermissions.value)
              _buildPermissionCheckingOverlay(),
          ],
        ),
      );
    });
  }

  /// Build small permission checking overlay
  Widget _buildPermissionCheckingOverlay() {
    return Positioned(
      top: 50,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha:0.95),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Checking permissions...',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
