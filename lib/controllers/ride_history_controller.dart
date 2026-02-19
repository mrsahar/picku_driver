import 'package:get/get.dart';
import 'package:pick_u_driver/core/global_variables.dart';
import 'package:pick_u_driver/core/sharePref.dart';
import 'package:pick_u_driver/models/ride_history_model.dart';
import 'package:pick_u_driver/providers/api_provider.dart';

class RideHistoryController extends GetxController {
  final ApiProvider _apiProvider = Get.find<ApiProvider>();

  // Observable variables
  final _rideHistory = Rxn<RideHistoryResponse>();
  final _isLoading = false.obs;
  final _errorMessage = ''.obs;

  // Getters
  RideHistoryResponse? get rideHistory => _rideHistory.value;
  bool get isLoading => _isLoading.value;
  String get errorMessage => _errorMessage.value;

  // Getter for rides sorted latest first
  List<RideItem> get rides {
    if (rideHistory?.items == null) return [];
    final list = List<RideItem>.from(rideHistory!.items);
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  int get totalRides => rides.length;
  int get completedRides => rideHistory?.completedRides ?? 0;
  int get cancelledRides => totalRides - completedRides;
  double get totalFare => rideHistory?.totalFare ?? 0.0;

  @override
  void onInit() {
    super.onInit();
    fetchRideHistory();
  }

  Future<void> fetchRideHistory() async {
    try {
      _isLoading.value = true;
      _errorMessage.value = '';

      final userId = await SharedPrefsService.getUserId();
      
      if (userId == null || userId.isEmpty) {
        _errorMessage.value = 'User ID not found. Please login again.';
        return;
      }

      final endpoint = '/api/Ride/get-driver-rides-history?driverId=$userId';

      final response = await _apiProvider.postData(endpoint, {});

      if (response.statusCode == 200) {
        if (response.body is List) {
          final ridesList = (response.body as List)
              .map((item) => RideItem.fromJson(item as Map<String, dynamic>))
              .toList();

          final completed = ridesList.where((ride) => ride.status.toLowerCase() == 'completed').length;
          final totalFareAmount = ridesList.fold<double>(0.0, (sum, ride) => sum + ride.fareFinal);

          _rideHistory.value = RideHistoryResponse(
            items: ridesList,
            completedRides: completed,
            totalFare: totalFareAmount,
          );
        } else {
          _rideHistory.value = RideHistoryResponse.fromJson(response.body);
        }
      } else {
        _errorMessage.value = 'Failed to load ride history: ${response.statusText}';
      }
    } catch (e) {
      _errorMessage.value = 'Error loading ride history: $e';
    } finally {
      _isLoading.value = false;
    }
  }

  Future<void> refreshHistory() async {
    await fetchRideHistory();
  }
}
