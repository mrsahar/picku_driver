import 'package:get/get.dart';
import 'package:pick_u_driver/controllers/edit_profile_controller.dart';

class EditProfileBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<EditProfileController>(
          () => EditProfileController(),
    );
  }
}