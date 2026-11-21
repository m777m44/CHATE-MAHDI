import 'package:flutter/material.dart';

/// Instagram-inspired light & dark themes.
class AppTheme {
  AppTheme._();

  static const igBlue = Color(0xFF0095F6);
  static const igBgLight = Color(0xFFFFFFFF);
  static const igBgDark = Color(0xFF000000);
  static const igSurfaceDark = Color(0xFF121212);
  static const igBorderLight = Color(0xFFDBDBDB);
  static const igBorderDark = Color(0xFF262626);
  static const igTextSecondary = Color(0xFF737373);

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorSchemeSeed: const Color(0xFF405DE6),
    );
    return base.copyWith(
      scaffoldBackgroundColor: igBgLight,
      appBarTheme: const AppBarTheme(
        backgroundColor: igBgLight,
        surfaceTintColor: igBgLight,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.black),
        titleTextStyle: TextStyle(
          color: Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      colorScheme: base.colorScheme.copyWith(
        primary: igBlue,
        secondary: igBlue,
        surface: igBgLight,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFAFAFA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: igBorderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: igBorderLight),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: igBlue,
        foregroundColor: Colors.white,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: igBgLight,
        indicatorColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith((states) =>
            IconThemeData(color: states.contains(WidgetState.selected) ? Colors.black : Colors.black)),
      ),
    );
  }

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: const Color(0xFF405DE6),
    );
    return base.copyWith(
      scaffoldBackgroundColor: igBgDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: igBgDark,
        surfaceTintColor: igBgDark,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      colorScheme: base.colorScheme.copyWith(
        primary: igBlue,
        secondary: igBlue,
        surface: igSurfaceDark,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF121212),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: igBorderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: igBorderDark),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: igBgDark,
        indicatorColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith((states) =>
            IconThemeData(color: states.contains(WidgetState.selected) ? Colors.white : Colors.grey.shade500)),
      ),
    );
  }
}
