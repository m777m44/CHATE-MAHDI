import 'package:flutter/material.dart';

/// Instagram-inspired light & dark themes with polished, animated systems.
class AppTheme {
  AppTheme._();

  static const igBlue = Color(0xFF0095F6);
  static const igBgLight = Color(0xFFFFFFFF);
  static const igBgDark = Color(0xFF000000);
  static const igSurfaceDark = Color(0xFF121212);
  static const igBorderLight = Color(0xFFDBDBDB);
  static const igBorderDark = Color(0xFF262626);
  static const igTextSecondary = Color(0xFF737373);

  /// Brand gradient used across logos, buttons and update screens.
  static const brandGradient = LinearGradient(
    colors: [Color(0xFFF58529), Color(0xFFDD2A7B), Color(0xFF8134AF), igBlue],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  /// Shared page transition: smooth slide-up + fade everywhere.
  static const pageTransitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: _FadingSlideTransitionBuilder(),
      TargetPlatform.iOS: _FadingSlideTransitionBuilder(),
    },
  );

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorSchemeSeed: const Color(0xFF405DE6),
    );
    return base.copyWith(
      scaffoldBackgroundColor: igBgLight,
      pageTransitionsTheme: pageTransitions,
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
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: igBorderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: igBorderLight),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: igBlue,
        foregroundColor: Colors.white,
      ),
      cardTheme: const CardTheme(elevation: 0.5, clipBehavior: Clip.antiAlias),
      dialogTheme: const DialogTheme(shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(24)))),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
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
      pageTransitionsTheme: pageTransitions,
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
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: igBorderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: igBorderDark),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      cardTheme: const CardTheme(elevation: 0.5, clipBehavior: Clip.antiAlias),
      dialogTheme: const DialogTheme(shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(24)))),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
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

/// Custom MaterialPageRoute-style builder: fades in while sliding up slightly.
class _FadingSlideTransitionBuilder extends PageTransitionsBuilder {
  const _FadingSlideTransitionBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  }
}
