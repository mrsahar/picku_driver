import 'package:get/get.dart';
import 'package:pick_u_driver/controllers/driver_documents_controller.dart';
class DriverDocumentsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DriverDocumentsController>(
          () => DriverDocumentsController(),
    );
  }
}