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

  List<RideItem> get rides => rideHistory?.items ?? [];
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
      print(' SAHAr : userId = $userId');

      if (userId == null || userId.isEmpty) {
        _errorMessage.value = 'User ID not found. Please login again.';
        print(' SAHAr : User ID is null or empty');
        return;
      }

      final endpoint = '/api/Ride/get-driver-rides-history?driverId=$userId';
      print(' SAHAr : endpoint = $endpoint');
      print(' SAHAr : full URL = ${_apiProvider.httpClient.baseUrl}$endpoint');

      // Debug the headers being sent
      print(' SAHAr : Base URL = ${_apiProvider.httpClient.baseUrl}');
      print(' SAHAr : User Token = ${GlobalVariables.instance.userToken}');

      final response = await _apiProvider.postData(endpoint,{});

      print(' SAHAr : response.statusCode = ${response.statusCode}');
      print(' SAHAr : response.statusText = ${response.statusText}');
      print(' SAHAr : response.headers = ${response.headers}');
      print(' SAHAr : response.body = ${response.body}');

      if (response.statusCode == 200) {
        // Check if response.body is a List or Map
        if (response.body is List) {
          // API returned a direct list of rides
          print(' SAHAr : API returned a List directly');
          final ridesList = (response.body as List)
              .map((item) => RideItem.fromJson(item as Map<String, dynamic>))
              .toList();

          // Calculate completed rides
          final completed = ridesList.where((ride) => ride.status.toLowerCase() == 'completed').length;

          // Calculate total fare
          final totalFareAmount = ridesList.fold<double>(0.0, (sum, ride) => sum + ride.fareFinal);

          // Create RideHistoryResponse manually
          _rideHistory.value = RideHistoryResponse(
            items: ridesList,
            completedRides: completed,
            totalFare: totalFareAmount,
          );
        } else {
          // API returned an object with items property
          print(' SAHAr : API returned a Map/Object');
          final historyResponse = RideHistoryResponse.fromJson(response.body);
          _rideHistory.value = historyResponse;
        }
        print(' SAHAr : ride history loaded successfully');
      } else if (response.statusCode == 405) {
        // Method not allowed - check if endpoint expects POST instead of GET
        print(' SAHAr : 405 Method Not Allowed - API might expect POST instead of GET');
        _errorMessage.value = 'API method not allowed. Contact support.';
      } else if (response.statusCode == 401) {
        // Unauthorized
        print(' SAHAr : 401 Unauthorized - check token');
        _errorMessage.value = 'Unauthorized. Please login again.';
      } else {
        _errorMessage.value = 'Failed to load ride history: ${response.statusText}';
        print(' SAHAr : failed with statusText = ${response.statusText}');
      }
    } catch (e) {
      _errorMessage.value = 'Error loading ride history: $e';
      print(' SAHAr : exception = $e');
      print(' SAHAr : exception type = ${e.runtimeType}');
    } finally {
      _isLoading.value = false;
      print(' SAHAr : loading finished');
    }
  }


  Future<void> refreshHistory() async {
    await fetchRideHistory();
  }
}