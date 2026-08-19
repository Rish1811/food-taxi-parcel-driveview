import 'package:flutter/material.dart';
import 'package:food_user_application/core/constants/app_constants.dart';

class AppTheme {
  // Define core colors
  static const Color primaryColor = Color(
    0xFFFF7622,
  ); // Vibrant Orange
  static const Color darkBackground = Color(0xFF121212);
  static const Color lightBackground = Color(0xFFF8F9FA);

  static const Color darkCard = Color(0xFF1E1E1E);
  static const Color lightCard = Colors.white;

  static const Color darkNavBackground = Color(0xFF1C1C1E);
  static const Color lightNavBackground = Color(0xFF2C2C2E);

  static ThemeData get lightTheme {
    return ThemeData(
      fontFamily: AppConstants.fontFamily,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: lightBackground,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: Color(
          0xFFF3C623,
        ), // For the yellow "Submit Bank Details" card
        surface: lightCard,
        onSurface: Colors.black,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBackground,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
        titleTextStyle: TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: lightNavBackground,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      fontFamily: AppConstants.fontFamily,
      primaryColor: primaryColor,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: Color(0xFFF3C623),
        surface: darkCard,
        onSurface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkNavBackground,
      ),
    );
  }
}
