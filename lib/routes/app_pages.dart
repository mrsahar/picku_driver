import 'package:get/get.dart';
import 'package:pick_u_driver/authentication/driver_profile_page.dart';
import 'package:pick_u_driver/authentication/edit_profile_screen.dart';
import 'package:pick_u_driver/authentication/forget_password_screen.dart';
import 'package:pick_u_driver/authentication/login_screen.dart';
import 'package:pick_u_driver/authentication/otp_screen.dart';
import 'package:pick_u_driver/authentication/profile_screen.dart';
import 'package:pick_u_driver/authentication/reset_password_screen.dart';
import 'package:pick_u_driver/authentication/signup_screen.dart';
import 'package:pick_u_driver/bindings/chat_binding.dart';
import 'package:pick_u_driver/bindings/driver_admin_chat_binding.dart';
import 'package:pick_u_driver/bindings/driver_documents_binding.dart';
import 'package:pick_u_driver/bindings/driver_profile_binding.dart';
import 'package:pick_u_driver/bindings/earnings_binding.dart';
import 'package:pick_u_driver/bindings/edit_profile_binding.dart';
import 'package:pick_u_driver/bindings/forgot_password_binding.dart';
import 'package:pick_u_driver/bindings/login_binding.dart';
import 'package:pick_u_driver/bindings/otp_binding.dart';
import 'package:pick_u_driver/bindings/profile_binding.dart';
import 'package:pick_u_driver/bindings/reset_password_binding.dart';
import 'package:pick_u_driver/bindings/ride_history_binding.dart';
import 'package:pick_u_driver/bindings/scheduled_ride_history_binding.dart';
import 'package:pick_u_driver/bindings/shift_application_binding.dart';
import 'package:pick_u_driver/bindings/signup_binding.dart';
import 'package:pick_u_driver/driver_screen/chat_screen.dart';
import 'package:pick_u_driver/driver_screen/driver_admin_chat_screen.dart';
import 'package:pick_u_driver/driver_screen/driver_documents_page.dart';
import 'package:pick_u_driver/driver_screen/earnings_page.dart';
import 'package:pick_u_driver/driver_screen/history/history_screen.dart';
import 'package:pick_u_driver/driver_screen/main_map.dart';
import 'package:pick_u_driver/driver_screen/scheduled/scheduled_ride_history_page.dart';
import 'package:pick_u_driver/driver_screen/screens/help_center_screen.dart';
import 'package:pick_u_driver/driver_screen/screens/notification_screen.dart';
import 'package:pick_u_driver/driver_screen/screens/privacy_policy_screen.dart';
import 'package:pick_u_driver/driver_screen/screens/setting_screen.dart';
import 'package:pick_u_driver/driver_screen/screens/verify_message_screen.dart';
import 'package:pick_u_driver/driver_screen/screens/welcome_screen.dart';
import 'package:pick_u_driver/driver_screen/shift_time.dart';
import 'package:pick_u_driver/routes/app_route_observer.dart';
import 'app_routes.dart';

class AppPages {
  AppPages._();

  static const INITIAL = AppRoutes.WelcomeScreen;

  // Observer instance
  static final MyRouteObserver routeObserver = MyRouteObserver();

  static final List<GetPage> routes = [
    GetPage(
      name: AppRoutes.WelcomeScreen,
      page: () => const WelcomeScreen(),
    ),
    GetPage(
      name: AppRoutes.SIGNUP_SCREEN,
      page: () => const SignupScreen(),
      binding: SignUpBinding(),
    ),
    GetPage(
      name: AppRoutes.OTP_SCREEN,
      page: () => const OTPScreen(),
      binding: OtpBinding(),
    ),
    GetPage(
      name: AppRoutes.LOGIN_SCREEN,
      page: () => const LoginScreen(),
      binding: LoginBinding(), // Add login binding
    ),
    GetPage(
      name: AppRoutes.profileScreen,
      page: () => const ProfileScreen(),
      binding: ProfileBinding(), // Add login binding
    ),
    GetPage(
      name: AppRoutes.editProfile,
      page: () => const EditProfileScreen(),
      binding: EditProfileBinding(),
    ),
    GetPage(
      name: AppRoutes.MainMap,
      page: () => const MainMap(), // Make sure you have this screen
      // Add reset password binding if needed
    ),
    GetPage(
      name: AppRoutes.FORGOT_PASSWORD_SCREEN,
      page: () => const ForgotPasswordScreen(),
      binding: ForgotPasswordBinding(),
    ),
    GetPage(
      name: AppRoutes.Reset_Password,
      page: () => const ResetPasswordScreen(),
      binding: ResetPasswordBinding(),
    ),

// Driver Profile Routes
    GetPage(
      name: AppRoutes.shiftApplication,
      page: () => ShiftApplicationPage(),
      binding: ShiftApplicationBinding(),
      transition: Transition.rightToLeft,
      transitionDuration: Duration(milliseconds: 300),
    ),
    GetPage(
      name: AppRoutes.driverProfile,
      page: () => DriverProfilePage(),
      binding: DriverProfileBinding(),
      transition: Transition.rightToLeft,
      transitionDuration: Duration(milliseconds: 300),
    ),
    GetPage(
      name: AppRoutes.mainMap,
      page: () => const MainMap(),
    ),
    GetPage(
      name: AppRoutes.rideHistory,
      page: () => const RideHistoryPage(),
      binding: RideHistoryBinding(),
    ),
    GetPage(
      name: AppRoutes.scheduledRideHistory,
      page: () => const ScheduledRideHistoryPage(),
      binding: ScheduledRideHistoryBinding(),
    ),
    GetPage(
      name: AppRoutes.driveAdminChat,
      page: () => DriverAdminChatScreen(),
      binding: DriverAdminChatBinding(),
    ),

    // Extra
    GetPage(
      name: AppRoutes.notificationScreen,
      page: () => const NotificationScreen(),
    ),
    GetPage(
      name: AppRoutes.settingsScreen,
      page: () => const SettingsScreen(),
    ),
    GetPage(
      name: AppRoutes.helpCenterScreen,
      page: () => const HelpCenterScreen(),
    ),
    GetPage(
      name: AppRoutes.privacyPolicy,
      page: () => const PrivacyPolicyScreen(),
    ),
    GetPage(
      name: AppRoutes.chatScreen,
      page: () => const ChatScreen(),
      binding: ChatBinding(),
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AppRoutes.DRIVER_DOCUMENTS,
      page: () => DriverDocumentsPage(),
      binding: DriverDocumentsBinding(),
    ),

    GetPage(
      name: AppRoutes.EarningSCREEN,
      page: () => const EarningsPage(),
      binding: EarningsBinding(),
    ),

    GetPage(
      name: AppRoutes.VERIFY_MESSAGE,
      page: () => VerifyMessageScreen.fromArguments(),
    ),
  ];
}