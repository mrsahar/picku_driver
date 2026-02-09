// bindings/initial_binding.dart
import 'package:get/get.dart';
import 'package:pick_u_driver/core/background_tracking_service.dart';
import 'package:pick_u_driver/core/global_variables.dart';
import 'package:pick_u_driver/providers/api_provider.dart';

import '../core/chat_notification_service.dart';
import '../core/notification_sound_service.dart';
import '../core/ride_notification_service.dart';
import '../core/unified_signalr_service.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(GlobalVariables(), permanent: true);
    Get.put(ApiProvider(), permanent: true);
    // PermissionService removed - will be initialized after user grants permission
    // Get.put(PermissionService(), permanent: true);
    Get.put(ChatNotificationService(), permanent: true);
    Get.put(RideNotificationService(), permanent: true);
    Get.put(NotificationSoundService(), permanent: true);
    Get.put(BackgroundTrackingService(), permanent: true);
    Get.put(UnifiedSignalRService(), permanent: true);
  }
}