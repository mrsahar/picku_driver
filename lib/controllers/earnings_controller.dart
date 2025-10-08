import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pick_u_driver/core/global_variables.dart';
import 'package:pick_u_driver/core/sharePref.dart';
import 'package:pick_u_driver/models/earnings_model.dart';
import 'package:pick_u_driver/providers/api_provider.dart';

class EarningsController extends GetxController {
  final ApiProvider _apiProvider = ApiProvider();

  final RxBool isLoading = false.obs;
  final RxBool hasError = false.obs;
  final Rx<String> errorMessage = ''.obs;
  final Rxn<EarningsResponse> earningsData = Rxn<EarningsResponse>();

  @override
  void onInit() {
    super.onInit();
    fetchEarnings();
  }

  Future<void> fetchEarnings() async {
    try {
      print('SAHAr: Starting fetchEarnings');
      isLoading.value = true;
      hasError.value = false;
      errorMessage.value = '';

      final driverId = await SharedPrefsService.getUserId();
      print('SAHAr: Retrieved driverId = $driverId');


      final endpoint = '/api/Payment/driver-transaction/$driverId';
      print('SAHAr: API endpoint = $endpoint');

      final response = await _apiProvider.getData(endpoint);
      print('SAHAr: API response status = ${response.statusCode}, isOk = ${response.isOk}');
      print('SAHAr: API response body = ${response.body}');

      if (response.isOk) {
        final data = EarningsResponse.fromJson(response.body);
        earningsData.value = data;
        print('SAHAr: Earnings data loaded successfully');
      } else {
        hasError.value = true;
        errorMessage.value = response.statusText ?? 'Failed to load earnings';
        print('SAHAr: Error loading earnings - ${errorMessage.value}');
      }
    } catch (e) {
      hasError.value = true;
      errorMessage.value = 'Error: $e';
      print('SAHAr: Exception occurred - $e');
    } finally {
      isLoading.value = false;
      print('SAHAr: fetchEarnings completed');
    }
  }


  Future<void> refreshEarnings() async {
    await fetchEarnings();
  }

  String formatTime(dynamic date) {
    DateTime dt = date is String ? DateTime.parse(date) : date;
    return DateFormat('hh:mm a').format(dt);
  }


  String formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  String formatCurrency(dynamic amount) {
    try {
      if (amount == null) return '\$0.00';

      double numericAmount;
      if (amount is String) {
        // If it's a string, try to parse it as double
        numericAmount = double.tryParse(amount) ?? 0.0;
      } else if (amount is num) {
        // If it's already a number, convert to double
        numericAmount = amount.toDouble();
      } else {
        // Fallback for any other type
        numericAmount = 0.0;
      }

      return '\$${numericAmount.toStringAsFixed(2)}';
    } catch (e) {
      print('SAHAr: Error formatting currency for value: $amount, error: $e');
      return '\$0.00';
    }
  }
}