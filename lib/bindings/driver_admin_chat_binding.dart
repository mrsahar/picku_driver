import 'package:get/get.dart';

import '../controllers/driver_admin_chat_controller.dart';

class DriverAdminChatBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DriverAdminChatController>(
          () => DriverAdminChatController(),
    );
  }
}