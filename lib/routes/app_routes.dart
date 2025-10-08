// lib/app/routes/app_routes.dart
abstract class AppRoutes {
  static const HOME = '/home';
  static const SIGNUP_SCREEN = '/signup';
  static const OTP_SCREEN = '/otp';
  static const LOGIN_SCREEN = '/login';
  static const WelcomeScreen = '/welcome_screen';
  static const MainMap = '/mainmap';
  static const FORGOT_PASSWORD_SCREEN = '/forgot-password';
  static const Reset_Password = '/reset-password';


  // Shift Management Routes
  static const String shiftApplication = '/shift-application';

  // Profile Routes
  static const String driverProfile = '/driver-profile';
  static const String mainMap = '/main';

  static const rideHistory = '/rideHistory';
  static const scheduledRideHistory = '/scheduledRideHistory';
  static const String profileScreen = '/profileScreen';
  static const editProfile = '/editProfile';
  static const String chatScreen = '/chatScreen';

  //Extra
  static const notificationScreen = '/notification';
  static const settingsScreen = '/settingsScreen';
  static const helpCenterScreen = '/helpCenter';
  static const String privacyPolicy = '/privacyPolicy';

  //verification pages of driver documents
  static const DRIVER_DOCUMENTS = '/driver-documents';
  static const VERIFY_MESSAGE = '/verify-message';
  static const EarningSCREEN = '/earnings';


  }