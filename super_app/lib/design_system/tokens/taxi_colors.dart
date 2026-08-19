import 'package:flutter/material.dart';

/// Single source of truth for the app's visual color tokens.
class TaxiColors {
  TaxiColors._();

  // Brand Colors (Vibrant Orange & Emerald Green)
  static const Color primaryOrange = Color(0xFFFF5C2B);
  static const Color orangeDark = Color(0xFFE04313);
  static const Color orangeLight = Color(0xFFFFF4EF);

  static const Color primary = Color(0xFFFF5C2B);
  static const Color primaryDark = Color(0xFFE04313);
  static const Color primaryLight = Color(0xFFFFF4EF);

  static const Color accent = Color(0xFF0F172A);
  static const Color accentDark = Color(0xFF020617);

  // Category Colors
  static const Color rideCategory = Color(0xFFFF5C2B);
  static const Color bikeCategory = Color(0xFFFF8A00);
  static const Color autoCategory = Color(0xFF10B981);
  static const Color parcelCategory = Color(0xFFF59E0B);
  static const Color rentalsCategory = Color(0xFF3B82F6);
  static const Color outstationCategory = Color(0xFF8B5CF6);

  // Semantic Colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Light Mode Surfaces & Text
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFF1F5F9);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);

  // Dark Mode Surfaces & Text
  static const Color darkBackground = Color(0xFF09121D);
  static const Color darkSurface = Color(0xFF111E2E);
  static const Color darkCard = Color(0xFF172639);
  static const Color darkBorder = Color(0xFF23354B);
  static const Color darkTextPrimary = Color(0xFFF9FAFB);
  static const Color darkTextSecondary = Color(0xFF9CA3AF);

  // Gradients
  static const List<Color> primaryGradient = [
    Color(0xFFFF5C2B),
    Color(0xFFE04313),
  ];

  static const List<Color> orangeBannerGradient = [
    Color(0xFFFFF0EA),
    Color(0xFFFFDFD3),
  ];

  static const List<Color> accentGradient = [
    Color(0xFF0F172A),
    Color(0xFF1E293B),
  ];

  static const List<Color> mapPulseGradient = [
    Color(0x33FF5C2B),
    Color(0x00FF5C2B),
  ];
}
