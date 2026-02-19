// bindings/initial_binding.dart
import 'package:get/get.dart';
import 'package:pick_u_driver/controllers/active_ride_controller.dart';
import 'package:pick_u_driver/core/background_tracking_service.dart';
import 'package:pick_u_driver/core/database_helper.dart';
import 'package:pick_u_driver/core/driver_service.dart';
import 'package:pick_u_driver/core/global_variables.dart';
import 'package:pick_u_driver/core/internet_connectivity_service.dart';
import 'package:pick_u_driver/providers/api_provider.dart';

import '../core/chat_notification_service.dart';
import '../core/notification_sound_service.dart';
import '../core/ride_notification_service.dart';
import '../core/unified_signalr_service.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    // Initialize InternetConnectivityService FIRST - foundation for reconnection logic
    Get.put(InternetConnectivityService(), permanent: true);
    
    Get.put(GlobalVariables(), permanent: true);
    Get.put(ApiProvider(), permanent: true);
    Get.put(DriverService(), permanent: true); // Initialize DriverService for driver info management
    // PermissionService removed - will be initialized after user grants permission
    // Get.put(PermissionService(), permanent: true);
    Get.put(ChatNotificationService(), permanent: true);
    Get.put(RideNotificationService(), permanent: true);
    Get.put(NotificationSoundService(), permanent: true);
    Get.put(DatabaseHelper(), permanent: true);
    Get.put(BackgroundTrackingService(), permanent: true);
    Get.put(UnifiedSignalRService(), permanent: true);

    // ✅ FIX: Initialize ActiveRideController at app startup
    // This prevents navigation issues when background service initializes it later
    Get.put(ActiveRideController(), permanent: true);

    // Request battery optimization and related permissions early
    Future.microtask(() {
      try {
        BackgroundTrackingService.to.requestBackgroundPermissions();
      } catch (e) {
        // Ignore errors at startup, service can request again when going online
        print('⚠️ SAHAr Initial permission request failed: $e');
      }
    });
  }
}