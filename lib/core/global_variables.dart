// lib/app/core/utils/global_variables.dart
import 'package:get/get.dart';

class GlobalVariables extends GetxController {
  static GlobalVariables get instance => Get.find<GlobalVariables>();

  //final _storage = GetStorage();

  // Reactive variables
  final RxString _userToken = ''.obs;
  final RxBool _isLoggedIn = false.obs;
  final RxString _baseUrl = 'https://jsonplaceholder.typicode.com'.obs;
  final RxBool _isLoading = false.obs;

  // Getters
  String get userToken => _userToken.value;
  bool get isLoggedIn => _isLoggedIn.value;
  String get baseUrl => _baseUrl.value;
  bool get isLoading => _isLoading.value;

  @override
  void onInit() {
    super.onInit();
    _loadStoredData();
  }

  void _loadStoredData() {

  }

  // Setters
  void setUserToken(String token) {
    _userToken.value = token;
  }

  void setLoginStatus(bool status) {
    _isLoggedIn.value = status;
  }

  void setBaseUrl(String url) {
    _baseUrl.value = url;
  }

  void setLoading(bool loading) {
    _isLoading.value = loading;
  }

  void clearUserData() {
    _userToken.value = '';
    _isLoggedIn.value = false;
  }
}