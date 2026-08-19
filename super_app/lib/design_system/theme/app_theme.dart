import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:superapp_user/design_system/tokens/app_colors.dart';
import 'package:superapp_user/design_system/tokens/app_text_styles.dart';

const double _borderRadius = 22.0; // Modern Rounded Corners
const double _buttonBorderRadius = 24.0;
const double _buttonHeight = 56.0;

/// Poppins across every Material 3 text role, not just the handful named
/// below. Passing a sparse `TextTheme(displayLarge: ..., bodyMedium: ...)`
/// straight into `GoogleFonts.poppinsTextTheme` leaves every other role
/// (titleLarge, titleMedium, titleSmall, labelMedium, labelSmall, ...) null —
/// Material 3 widgets (AppBar titles, list tiles, chips, nav labels) that
/// read those roles then silently fall back to the platform default font,
/// which is why some headings looked like a different font from the rest.
TextTheme _poppinsTextTheme(Brightness brightness) {
  final platformDefault = (brightness == Brightness.dark ? ThemeData.dark() : ThemeData.light()).textTheme;
  final base = GoogleFonts.poppinsTextTheme(platformDefault);
  return base.copyWith(
    displayLarge: base.displayLarge?.merge(AppTextStyles.h1),
    displayMedium: base.displayMedium?.merge(AppTextStyles.h2),
    displaySmall: base.displaySmall?.merge(AppTextStyles.h3),
    headlineMedium: base.headlineMedium?.merge(AppTextStyles.h4),
    bodyLarge: base.bodyLarge?.merge(AppTextStyles.bodyLarge),
    bodyMedium: base.bodyMedium?.merge(AppTextStyles.bodyMedium),
    bodySmall: base.bodySmall?.merge(AppTextStyles.bodySmall),
    labelLarge: base.labelLarge?.merge(AppTextStyles.button),
  );
}

/// Built fresh on every call (never cached as a top-level `const`/`final`) so
/// it always reflects the current [AppColors.primary] — the whole point of
/// the dynamic app-theme-color feature. Call sites re-invoke this whenever
/// [themeColorProvider] changes, which is what makes every Material widget
/// that reads `Theme.of(context)` (buttons, switches, radios, progress
/// indicators, the bottom nav, etc.) update without an app restart.
ThemeData buildLightTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  scaffoldBackgroundColor: AppColors.backgroundLight,
  primaryColor: AppColors.primary,
  colorScheme: ColorScheme.light(
    primary: AppColors.primary,
    secondary: AppColors.primaryButton,
    surface: AppColors.surfaceLight,
    error: AppColors.error,
    onPrimary: Colors.white,
    onSurface: AppColors.textPrimaryLight,
  ),

  textTheme: _poppinsTextTheme(Brightness.light).apply(
    bodyColor: AppColors.textPrimaryLight,
    displayColor: AppColors.textPrimaryLight,
  ),

  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: AppColors.textPrimaryLight,
    elevation: 0,
    centerTitle: true,
    iconTheme: IconThemeData(color: AppColors.textPrimaryLight),
    titleTextStyle: TextStyle(
      color: AppColors.textPrimaryLight,
      fontSize: 18,
      fontWeight: FontWeight.w500,
    ),
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primaryButton,
      foregroundColor: Colors.white,
      minimumSize: const Size(double.infinity, _buttonHeight),
      textStyle: AppTextStyles.button,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_buttonBorderRadius),
      ),
      elevation: 0,
    ),
  ),

  cardTheme: CardThemeData(
    color: AppColors.cardLight,
    elevation: 20, // Match the 20px blur radius for shadow
    shadowColor: Colors.black.withValues(alpha: 0.08), // Match the 8% opacity spec
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_borderRadius),
      side: const BorderSide(color: AppColors.borderLight, width: 0.5), // Subtle border
    ),
    clipBehavior: Clip.antiAlias,
  ),

  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surfaceLight,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: AppColors.borderLight),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: AppColors.borderLight),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: AppColors.primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: AppColors.error, width: 1.5),
    ),
    hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondaryLight),
    labelStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimaryLight),
  ),

  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: AppColors.surfaceLight,
    selectedItemColor: AppColors.primary,
    unselectedItemColor: AppColors.textSecondaryLight,
    type: BottomNavigationBarType.fixed,
    elevation: 8,
  ),
);

// ==================== DARK THEME ====================
/// See [buildLightTheme] — same reasoning, built fresh per call.
ThemeData buildDarkTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.backgroundDark,
  primaryColor: AppColors.primary,
  colorScheme: ColorScheme.dark(
    primary: AppColors.primary,
    secondary: AppColors.primaryButton,
    surface: AppColors.surfaceDark,
    error: AppColors.error,
    onPrimary: Colors.white,
    onSurface: AppColors.textPrimaryDark,
  ),
  
  textTheme: _poppinsTextTheme(Brightness.dark).apply(
    bodyColor: AppColors.textPrimaryDark,
    displayColor: AppColors.textPrimaryDark,
  ),

  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: true,
    iconTheme: IconThemeData(color: Colors.white),
    titleTextStyle: TextStyle(
      color: Colors.white,
      fontSize: 18,
      fontWeight: FontWeight.w500,
    ),
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primaryButton,
      foregroundColor: Colors.white,
      minimumSize: const Size(double.infinity, _buttonHeight),
      textStyle: AppTextStyles.button,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_buttonBorderRadius),
      ),
      elevation: 0,
    ),
  ),

  cardTheme: CardThemeData(
    color: AppColors.cardDark,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_borderRadius),
      side: const BorderSide(color: AppColors.borderDark, width: 1),
    ),
    clipBehavior: Clip.antiAlias,
  ),

  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surfaceDark,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: AppColors.borderDark),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: AppColors.borderDark),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: AppColors.primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: AppColors.error, width: 1.5),
    ),
    hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondaryDark),
    labelStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimaryDark),
  ),

  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: AppColors.backgroundDark,
    selectedItemColor: AppColors.primary,
    unselectedItemColor: AppColors.textSecondaryDark,
    type: BottomNavigationBarType.fixed,
    elevation: 8,
  ),
);