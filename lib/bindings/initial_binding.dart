// bindings/initial_binding.dart
import 'package:get/get.dart';
import 'package:pick_u_driver/core/background_tracking_service.dart';
import 'package:pick_u_driver/core/global_variables.dart';
import 'package:pick_u_driver/providers/api_provider.dart';

import '../core/location_service.dart';
import '../core/map_service.dart';
import '../core/permission_service.dart';
import '../core/unified_signalr_service.dart';
import '../core/chat_notification_service.dart';
import '../core/ride_notification_service.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(GlobalVariables(), permanent: true);
    Get.put(ApiProvider(), permanent: true);
    Get.put(PermissionService(), permanent: true);
    Get.put(LocationService(), permanent: true);
    Get.put(MapService(), permanent: true);
    Get.put(ChatNotificationService(), permanent: true);
    Get.put(RideNotificationService(), permanent: true);
    Get.put(BackgroundTrackingService(), permanent: true);
    // ActiveRideController removed - will be initialized after connection check
    // Unified SignalR service with JWT authentication
    Get.put(UnifiedSignalRService(), permanent: true);
  }
}