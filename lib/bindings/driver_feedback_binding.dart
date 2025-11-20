import 'package:get/get.dart';
import '../controllers/driver_feedback_controller.dart';

class DriverFeedbackBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DriverFeedbackController>(
          () => DriverFeedbackController(),
    );
  }
}