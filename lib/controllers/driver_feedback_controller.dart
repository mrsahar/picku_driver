import 'package:get/get.dart';
import '../core/sharePref.dart';
import '../models/feedback_response_model.dart';
import '../providers/api_provider.dart';

class DriverFeedbackController extends GetxController {
  final ApiProvider _apiProvider = Get.find<ApiProvider>();

  final RxBool isLoading = false.obs;
  final RxDouble averageRating = 0.0.obs;
  final RxList<FeedbackItem> feedbacks = <FeedbackItem>[].obs;
  final RxString errorMessage = ''.obs;

  String? _driverId;

  @override
  void onInit() {
    super.onInit();
    loadFeedbacks();
  }

  Future<void> loadFeedbacks() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      // Get driver ID from SharedPreferences
      _driverId = await SharedPrefsService.getUserId();

      if (_driverId == null || _driverId!.isEmpty) {
        errorMessage.value = 'Driver ID not found';
        isLoading.value = false;
        return;
      }

      // Call API
      final response = await _apiProvider.postData(
        '/api/feedback/driver/$_driverId',
        {},
      );

      if (response.statusCode == 200) {
        final feedbackResponse = FeedbackResponse.fromJson(response.body);
        averageRating.value = feedbackResponse.averageRating;
        feedbacks.value = feedbackResponse.feedbacks;
      } else {
        errorMessage.value = response.statusText ?? 'Failed to load feedbacks';
      }
    } catch (e) {
      errorMessage.value = 'Error: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshFeedbacks() async {
    await loadFeedbacks();
  }

  String formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  String formatDateTime(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }
}