import 'package:get/get.dart';
import 'package:pick_u_driver/controllers/privacy_policy_controller.dart';

class PrivacyPolicyBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PrivacyPolicyController>(() => PrivacyPolicyController());
  }
}
