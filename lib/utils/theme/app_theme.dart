import 'package:flutter/material.dart';
import 'package:pick_u_driver/utils/theme/text_theme.dart';

class MAppTheme {
  MAppTheme._();

  // Client's color scheme
  static const Color primaryNavyBlue = Color(0xFF1A2A44);
  static const Color trackingOrange = Color(0xFFF5A623);
  static const Color backgroundWhite = Color(0xFFFFFFFF);

  // Additional colors for better theming
  static const Color lightGrey = Color(0xFFFfFfFf);
  static const Color darkGrey = Color(0xFF2C2C2C);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryNavyBlue,
      brightness: Brightness.light,
    ).copyWith(
      primary: primaryNavyBlue,
      secondary: trackingOrange,
      surface: backgroundWhite,
      background: backgroundWhite,
      onPrimary: backgroundWhite, // White text on navy blue
      onSecondary: primaryNavyBlue, // Navy text on orange
      onSurface: primaryNavyBlue, // Dark text on light surfaces
      onBackground: primaryNavyBlue, // Dark text on light backgrounds
    ),
    scaffoldBackgroundColor: backgroundWhite,
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryNavyBlue,
      foregroundColor: backgroundWhite,
      elevation: 2,
      centerTitle: true,
      surfaceTintColor: Colors.transparent, // Prevents scroll tint
      titleTextStyle: TextStyle(
        color: backgroundWhite,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFFE0E0E0),
      thickness: 0.7,
    ),
    textTheme: MTextTheme.lightTextTheme,
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: trackingOrange,
      foregroundColor: backgroundWhite,
      elevation: 4,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: backgroundWhite,
        backgroundColor: primaryNavyBlue,
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryNavyBlue,
        side: const BorderSide(color: primaryNavyBlue, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    // Special button theme for tracking/navigation features
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: trackingOrange,
        backgroundColor: Colors.transparent,
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: lightGrey,
      hintStyle: TextStyle(color: primaryNavyBlue.withValues(alpha:0.6)),
      labelStyle: const TextStyle(color: primaryNavyBlue),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryNavyBlue),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryNavyBlue.withValues(alpha:0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryNavyBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: backgroundWhite,
      selectedItemColor: primaryNavyBlue,
      unselectedItemColor: Color(0xFF757575),
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600),
    ),
    cardTheme: CardThemeData(
      color: backgroundWhite,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.all(8),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      textColor: primaryNavyBlue, // Ensures proper text color
      iconColor: primaryNavyBlue, // Ensures proper icon color
    ),
    chipTheme: ChipThemeData(
      backgroundColor: lightGrey,
      selectedColor: trackingOrange,
      labelStyle: const TextStyle(color: primaryNavyBlue),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return trackingOrange;
        }
        return Colors.grey;
      }),
      trackColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return trackingOrange.withValues(alpha:0.3);
        }
        return Colors.grey.withValues(alpha:0.3);
      }),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryNavyBlue,
      brightness: Brightness.dark,
    ).copyWith(
      primary: primaryNavyBlue,
      secondary: trackingOrange,
      surface: darkGrey,
      onPrimary: backgroundWhite, // White text on navy blue
      onSecondary: primaryNavyBlue, // Navy text on orange
      onSurface: backgroundWhite, // Light text on dark surfaces
      onBackground: backgroundWhite, // Light text on dark backgrounds
    ),
    scaffoldBackgroundColor: const Color(0xFF121212),
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryNavyBlue,
      foregroundColor: backgroundWhite,
      elevation: 2,
      centerTitle: true,
      surfaceTintColor: Colors.transparent, // Prevents scroll tint
      titleTextStyle: TextStyle(
        color: backgroundWhite,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFF3A3A3A),
      thickness: 0.7,
    ),
    textTheme: MTextTheme.darkTextTheme,
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: trackingOrange,
      foregroundColor: backgroundWhite,
      elevation: 4,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: backgroundWhite,
        backgroundColor: primaryNavyBlue,
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: trackingOrange,
        side: BorderSide(color: trackingOrange.withValues(alpha:0.8), width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: trackingOrange,
        backgroundColor: Colors.transparent,
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkGrey,
      hintStyle: const TextStyle(color: Colors.white70),
      labelStyle: const TextStyle(color: Colors.white),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: trackingOrange),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: trackingOrange.withValues(alpha:0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: trackingOrange, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: darkGrey,
      selectedItemColor: trackingOrange,
      unselectedItemColor: Colors.white70,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
    ),
    cardTheme: CardThemeData(
      color: darkGrey,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.all(8),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      textColor: backgroundWhite, // Ensures proper text color
      iconColor: backgroundWhite, // Ensures proper icon color
    ),
    chipTheme: ChipThemeData(
      backgroundColor: darkGrey,
      selectedColor: trackingOrange,
      labelStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return trackingOrange;
        }
        return Colors.grey;
      }),
      trackColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return trackingOrange.withValues(alpha:0.3);
        }
        return Colors.grey.withValues(alpha:0.3);
      }),
    ),
  );
}

