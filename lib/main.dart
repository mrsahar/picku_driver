import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:get/get.dart';
import 'package:pick_u_driver/bindings/initial_binding.dart';
import 'package:pick_u_driver/routes/app_pages.dart';
import 'package:pick_u_driver/utils/theme/app_theme.dart';

import 'core/global_variables.dart';

void main() {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  // Initialize global variables
  Get.put(GlobalVariables());
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
      initialRoute: AppPages.INITIAL, // Keep this
      getPages: AppPages.routes,      // Keep this
      // Remove the home property completely
    );
  }
}