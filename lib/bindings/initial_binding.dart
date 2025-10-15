// bindings/initial_binding.dart
import 'package:get/get.dart';
import 'package:pick_u_driver/core/background_tracking_service.dart';
import 'package:pick_u_driver/core/global_variables.dart';
import 'package:pick_u_driver/providers/api_provider.dart';

import '../core/location_service.dart';
import '../core/map_service.dart';
import '../core/permission_service.dart';
import '../core/signalr_service.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(GlobalVariables(), permanent: true);
    Get.put(ApiProvider(), permanent: true);
    Get.put(PermissionService(), permanent: true);
    Get.put(LocationService(), permanent: true);
    Get.put(MapService(), permanent: true);
    Get.put(BackgroundTrackingService(), permanent: true);
    // ActiveRideController removed - will be initialized after connection check
    // remove this line if not using SignalR
    Get.put(SignalRService(), permanent: true);
  }
}