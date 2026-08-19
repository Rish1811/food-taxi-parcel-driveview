import 'package:flutter/material.dart';

class AppColors {
  // ==================== BRAND COLORS ====================
  // Mutable (not const): reassigned by ThemeColorNotifier when the user picks
  // an app theme color, so every one of the hundreds of `AppColors.primary`
  // read sites app-wide picks up the new value on the next rebuild without
  // each of them needing to watch a provider individually.
  static Color primary = const Color(0xFFFF7A00);
  static Color primaryButton = const Color(0xFFFF8A1D);

  // ==================== DARK THEME COLORS ====================
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceDark = Color(0xFF1B1B1B);
  static const Color cardDark = Color(0xFF242424);
  static const Color darkContainer = Color(0xFF2A2A2A);
  static const Color darkBorder = Color(0xFF3D3D3D);
  
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFF9E9E9E);
  static const Color borderDark = Color(0xFF303030);

  // ==================== LIGHT THEME COLORS ====================
  static const Color backgroundLight = Color(0xFFF7F8FA); // Premium off-white
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color secondarySurfaceLight = Color(0xFFF4F5F7);
  static const Color lightContainer = Color(0xFFF9FAFB);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color stepperLightBg = Color(0xFFFFF7F2);
  static const Color lightGreyBg = Color(0xFFF0F0F0);
  static const Color lightOrangeBg = Color(0xFFFFF3E8);
  static const Color lightPeachBg = Color(0xFFFDF3E7);
  
  static const Color textPrimaryLight = Color(0xFF121212); // From spec
  static const Color textDark = Color(0xFF1E1E1E);
  static const Color textSecondaryLight = Color(0xFF6B7280); // From spec
  static const Color borderLight = Color(0xFFE9ECEF); // From spec
  static const Color borderSubtle = Color(0xFFE0E0E0);
  static const Color borderExtraSubtle = Color(0xFFEEEEEE);
  static const Color dividerLight = Color(0xFFF1F3F5); // From spec
  static const Color shadow1 = Color(0x14000000); // 0.08 opacity black
  static const Color shadow2 = Color(0x0A000000); // 0.04 opacity black

  // ==================== STATUS & ACCENT COLORS ====================
  static const Color success = Color(0xFF39C96B); 
  static const Color rating = Color(0xFFFFB01D); // Keeping rating star yellow/orange
  static const Color ratingStar = Color(0xFFFFC107);
  static const Color error = Color(0xFFFF6464);
  static const Color accentPurple = Color(0xFF5A4099);
  static const Color accentPink = Color(0xFFFF4B72);
  static const Color accentBlue = Color(0xFF4B7BFF);
}
