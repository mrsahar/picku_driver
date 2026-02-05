import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pick_u_driver/authentication/profile_screen.dart';
import 'package:pick_u_driver/driver_screen/main_screen/home_screen.dart';
import 'package:pick_u_driver/driver_screen/setup_payment_account_screen.dart';
import 'package:pick_u_driver/utils/modern_drawer.dart';
import 'package:pick_u_driver/utils/theme/mcolors.dart';

import '../core/permission_service.dart';
import '../core/sharePref.dart';
import '../routes/app_routes.dart';

class MainMap extends StatefulWidget {
  const MainMap({super.key});

  @override
  State<MainMap> createState() => _MainMapState();
}

class _MainMapState extends State<MainMap> {
  final _currentIndex = 0;
  PermissionService? _permissionService;

  // Stripe account check
  final RxBool _isCheckingStripeAccount = true.obs;
  final RxBool _hasStripeAccount = false.obs;

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

    // Permissions are ready, check Stripe account
    _checkStripeAccount();
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
      _checkStripeAccount();
    } catch (e) {
      print('Error checking permission status: $e');
      if (mounted) {
        Get.offAllNamed(AppRoutes.whyNeedPermission);
      }
    }
  }

  /// Check if driver has Stripe connected account
  Future<void> _checkStripeAccount() async {
    try {
      print('SAHAr: ========================================');
      print('SAHAr: 🔍 Checking for Stripe Account');
      print('SAHAr: ========================================');

      _isCheckingStripeAccount.value = true;

      String? stripeAccountId = await SharedPrefsService.getDriverStripeAccountId();

      if (stripeAccountId != null && stripeAccountId.isNotEmpty) {
        print('SAHAr: ✅ Stripe Account found: $stripeAccountId');
        _hasStripeAccount.value = true;
      } else {
        print('SAHAr: ❌ No Stripe Account found');
        _hasStripeAccount.value = false;
      }
    } catch (e) {
      print('SAHAr: ❌ Error checking Stripe account: $e');
      _hasStripeAccount.value = false;
    } finally {
      _isCheckingStripeAccount.value = false;
      print('SAHAr: ========================================');
    }
  }

  /// Public method to recheck Stripe account (called after setup completion)
  Future<void> recheckStripeAccount() async {
    await _checkStripeAccount();
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

      // Then check Stripe account
      if (_isCheckingStripeAccount.value) {
        return _buildCheckingStripeScreen(context, isDark);
      }

      if (!_hasStripeAccount.value) {
        return const SetupPaymentAccountScreen();
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
  /// Build checking Stripe account screen
  Widget _buildCheckingStripeScreen(BuildContext context, bool isDark) {
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  color: MColor.primaryNavy,
                  strokeWidth: 3,
                ),
                const SizedBox(height: 24),
                Text(
                  'Checking payment setup...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please wait',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
