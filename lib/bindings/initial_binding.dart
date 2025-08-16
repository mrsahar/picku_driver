// bindings/initial_binding.dart
import 'package:get/get.dart';
import 'package:pick_u_driver/core/global_variables.dart';
import 'package:pick_u_driver/providers/api_provider.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    // Initialize core services that are needed throughout the app
    Get.put(GlobalVariables(), permanent: true);
    Get.put(ApiProvider(), permanent: true);
  }
}