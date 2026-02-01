// lib/app/core/utils/global_variables.dart
import 'package:get/get.dart';
import 'package:pick_u_driver/core/sharePref.dart';

class GlobalVariables extends GetxController {
  static GlobalVariables get instance => Get.find<GlobalVariables>();

  //final _storage = GetStorage();

  // Reactive variables
  final RxString _userToken = ''.obs;
  final RxBool _isLoggedIn = false.obs;
  final RxString _baseUrl = 'http://api.pickurides.com'.obs;
  final RxBool _isLoading = false.obs;
  final RxString _userEmail = ''.obs;
  final RxString _userId = ''.obs;

  // Getters
  String get userToken => _userToken.value;
  bool get isLoggedIn => _isLoggedIn.value;
  String get baseUrl => _baseUrl.value;
  bool get isLoading => _isLoading.value;
  String get userEmail => _userEmail.value;
  String get userId => _userId.value;

  RxString get userEmailRx => _userEmail;

  @override
  void onInit() {
    super.onInit();
    _loadStoredData();
  }

  void setUserEmail(String email) { // ✅ Added email setter
    _userEmail.value = email;
  }

  void setUserId(String id) { // ✅ Added userId setter
    _userId.value = id;
  }

  /// Load stored user data from SharedPreferences on app startup
  Future<void> _loadStoredData() async {
    try {
      print('🔄 SAHAr Loading stored user data...');

      final userData = await SharedPrefsService.getUserData();
      final token = userData['token'];
      final email = userData['email'];
      final userId = userData['userId'];
      final isLoggedInStr = userData['isLoggedIn'];

      if (token != null && token.isNotEmpty) {
        _userToken.value = token;
        print('✅ SAHAr Token loaded from storage: ${token.substring(0, 20)}...');
      } else {
        print('⚠️ SAHAr No token found in storage');
      }

      if (email != null && email.isNotEmpty) {
        _userEmail.value = email;
        print('✅ SAHAr Email loaded: $email');
      }

      if (userId != null && userId.isNotEmpty) {
        _userId.value = userId;
        print('✅ SAHAr User ID loaded: $userId');
      }

      if (isLoggedInStr == 'true') {
        _isLoggedIn.value = true;
        print('✅ SAHAr Login status: true');
      }

      print('✅ SAHAr GlobalVariables initialized with stored data');
    } catch (e) {
      print('❌ SAHAr Error loading stored data: $e');
    }
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
    _userId.value = '';
  }
  bool get hasUserEmail => _userEmail.value.isNotEmpty;

  void logout() {
    clearUserData();
  }
}