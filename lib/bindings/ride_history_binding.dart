import 'package:get/get.dart';
import 'package:pick_u_driver/controllers/ride_history_controller.dart';

class RideHistoryBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<RideHistoryController>(() => RideHistoryController());
  }
}