import 'package:get/get.dart';
import 'package:pick_u_driver/controllers/earnings_controller.dart';

class EarningsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<EarningsController>(
          () => EarningsController(),
    );
  }
}
