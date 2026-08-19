import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:superapp_user/design_system/tokens/taxi_colors.dart';

class TaxiTextStyles {
  TaxiTextStyles._();

  static TextTheme textTheme(Color primaryColor, Color secondaryColor) {
    final base = GoogleFonts.poppinsTextTheme();
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: primaryColor,
        letterSpacing: -0.5,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: primaryColor,
        fontSize: 28,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontWeight: FontWeight.w500,
        color: primaryColor,
        fontSize: 22,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontWeight: FontWeight.w500,
        color: primaryColor,
        fontSize: 18,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontWeight: FontWeight.w500,
        color: primaryColor,
        fontSize: 16,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        color: primaryColor,
        fontSize: 15,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        color: secondaryColor,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      bodySmall: base.bodySmall?.copyWith(
        color: secondaryColor,
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
    );
  }

  static const TextStyle price = TextStyle(
    fontWeight: FontWeight.w600,
    fontSize: 20,
    color: TaxiColors.primary,
  );
}
