import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';
import 'package:pick_u_driver/authentication/profile_screen.dart';
import 'package:pick_u_driver/core/sharePref.dart';
import 'package:pick_u_driver/driver_screen/main_screen/home_screen.dart';
import 'package:pick_u_driver/routes/app_routes.dart';
import 'package:pick_u_driver/utils/modern_drawer.dart';
import 'package:pick_u_driver/utils/profile_widget_menu.dart';
import 'package:pick_u_driver/utils/theme/mcolors.dart';

import '../core/permission_service.dart';

class MainMap extends StatefulWidget {
  const MainMap({super.key});

  @override
  State<MainMap> createState() => _MainMapState();
}

class _MainMapState extends State<MainMap> {
  final _currentIndex = 0;
  final PermissionService _permissionService = PermissionService.to;

  List<Widget> pageList = [
    const HomeScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    var isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;

    return Obx(() {
      if (!_permissionService.isReady) {
        return _buildPermissionScreen(context, isDark);
      }

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
            if (_permissionService.isCheckingPermissions.value)
              _buildPermissionCheckingOverlay(),
          ],
        ),
      );
    });
  }

  /// Build beautiful permission screen
  Widget _buildPermissionScreen(BuildContext context, bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [Colors.grey[900]!, Colors.grey[800]!]
                : [Colors.blue[50]!, Colors.white],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated icon container
                  Container(
                    height: 120,
                    width: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: MColor.primaryNavy
                    ),
                    child: Icon(
                      !_permissionService.hasLocationPermission.value
                          ? Icons.location_off_rounded
                          : Icons.gps_off_rounded,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Title
                  Text(
                    !_permissionService.hasLocationPermission.value
                        ? 'Location Access Required'
                        : 'GPS Service Required',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.grey[800],
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 16),

                  // Description
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      _permissionService.permissionError.value.isNotEmpty
                          ? _permissionService.permissionError.value
                          : (!_permissionService.hasLocationPermission.value
                          ? 'We need access to your location to provide accurate driver tracking and navigation services.'
                          : 'Please enable GPS/Location services to use all app features.'),
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark ? Colors.grey[300] : Colors.grey[600],
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 50),

                  // Main action button
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      color: MColor.primaryNavy
                    ),
                    child: ElevatedButton(
                      onPressed: _retryPermissions,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: Text(
                        !_permissionService.hasLocationPermission.value
                            ? 'Grant Location Access'
                            : 'Enable GPS',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Secondary action button (only for permission issues)
                  if (!_permissionService.hasLocationPermission.value)
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () async {
                          await _permissionService.openAppSettings();
                          await _retryPermissions();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? Colors.white : MColor.primaryNavy,
                          side: BorderSide(
                            color: isDark ? Colors.grey[600]! : MColor.primaryNavy,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: const Text(
                          'Open App Settings',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 40),

                  // Features list
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800]?.withOpacity(0.5) : Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Why we need this:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildFeatureItem(
                          Icons.navigation_rounded,
                          'Real-time navigation',
                          isDark,
                        ),
                        _buildFeatureItem(
                          Icons.my_location_rounded,
                          'Driver location tracking',
                          isDark,
                        ),
                        _buildFeatureItem(
                          Icons.route_rounded,
                          'Optimal route suggestions',
                          isDark,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: MColor.primaryNavy,
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[300] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  /// Build small permission checking overlay
  Widget _buildPermissionCheckingOverlay() {
    return Positioned(
      top: 50,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
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


  /// Retry permission and GPS check
  Future<void> _retryPermissions() async {
    await _permissionService.ensurePermissionsWithDialog();
  }


}
