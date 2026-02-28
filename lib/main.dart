import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';
import 'package:pick_u_driver/core/background_service_initializer.dart';
import 'package:pick_u_driver/routes/app_pages.dart';
import 'package:pick_u_driver/utils/theme/app_theme.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:permission_handler/permission_handler.dart';

import 'bindings/initial_binding.dart';

Future<void> main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Load environment variables (Stripe keys)
  try {
    await dotenv.load(fileName: "assets/.env");
    print('SAHAr: ✅ Environment variables loaded successfully');
  } catch (e) {
    print('SAHAr: Make sure assets/.env exists with STRIPE_SECRET_KEY');
  }

  // Initialize background service (configures but does NOT auto-start)
  // Service is started explicitly after login when token is saved
  await initializeBackgroundService();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    initialState();
  }

  void initialState() async{
    await Future.delayed(const Duration(seconds: 3));
    FlutterNativeSplash.remove();
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PickU Driver',
      theme: MAppTheme.lightTheme,
      darkTheme: MAppTheme.darkTheme,
      themeMode: ThemeMode.system,
      initialBinding: InitialBinding(),
      navigatorObservers: [AppPages.routeObserver],
      initialRoute: AppPages.INITIAL,
      getPages: AppPages.routes,
    );
  }
}

// Request notification permission for Android 13 and above
Future<void> requestNotificationPermission() async {
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }
}
