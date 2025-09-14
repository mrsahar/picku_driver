import 'package:get/get.dart';
import 'package:pick_u_driver/controllers/scheduled_ride_history_controller.dart';

class ScheduledRideHistoryBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ScheduledRideHistoryController>(() => ScheduledRideHistoryController());
  }
}