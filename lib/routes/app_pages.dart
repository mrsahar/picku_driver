import 'package:get/get.dart';
import 'package:pick_u_driver/authentication/forget_password_screen.dart';
import 'package:pick_u_driver/authentication/login_screen.dart';
import 'package:pick_u_driver/authentication/otp_screen.dart';
import 'package:pick_u_driver/authentication/reset_password_screen.dart';
import 'package:pick_u_driver/authentication/signup_screen.dart';
import 'package:pick_u_driver/bindings/forgot_password_binding.dart';
import 'package:pick_u_driver/bindings/login_binding.dart';
import 'package:pick_u_driver/bindings/otp_binding.dart';
import 'package:pick_u_driver/bindings/reset_password_binding.dart';
import 'package:pick_u_driver/bindings/shift_application_binding.dart';
import 'package:pick_u_driver/bindings/signup_binding.dart';
import 'package:pick_u_driver/routes/app_route_observer.dart';
import 'package:pick_u_driver/static_screen/main_map.dart';
import 'package:pick_u_driver/static_screen/shift_time.dart';
import 'app_routes.dart';

class AppPages {
  AppPages._();

  static const INITIAL = AppRoutes.shiftApplication;

  // Observer instance
  static final MyRouteObserver routeObserver = MyRouteObserver();

  static final List<GetPage> routes = [
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

    GetPage(
      name: AppRoutes.shiftApplication,
      page: () => ShiftApplicationPage(),
      binding: ShiftApplicationBinding(),
      transition: Transition.rightToLeft,
      transitionDuration: Duration(milliseconds: 300),
    ),

  ];
}