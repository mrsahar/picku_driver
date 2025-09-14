import 'package:get/get.dart';
import 'package:pick_u_driver/controllers/driver_profile_controller.dart';
import 'package:pick_u_driver/providers/api_provider.dart';
class DriverProfileBinding extends Bindings {
  @override
  void dependencies() {
    // Initialize ApiProvider if not already initialized
    if (!Get.isRegistered<ApiProvider>()) {
      Get.put<ApiProvider>(ApiProvider(), permanent: true);
    }

    // Initialize DriverProfileController
    Get.lazyPut<DriverProfileController>(
          () => DriverProfileController(),
    );
  }
}