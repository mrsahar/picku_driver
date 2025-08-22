import 'package:get/get.dart';
import 'package:pick_u_driver/controllers/shift_application_controller.dart';
import 'package:pick_u_driver/providers/api_provider.dart';

class ShiftApplicationBinding extends Bindings {
  @override
  void dependencies() {
    // Initialize ApiProvider if not already initialized
    if (!Get.isRegistered<ApiProvider>()) {
      Get.put<ApiProvider>(ApiProvider(), permanent: true);
    }

    // Initialize ShiftApplicationController
    Get.lazyPut<ShiftApplicationController>(
          () => ShiftApplicationController(),
    );
  }
}