import 'package:flutter/material.dart';

import 'package:superapp_user/core/config/app_constants.dart';

/// Single source of truth for every environment-specific value the app needs
/// (backend host, map/Firebase keys, package identity). Update values here
/// only — nothing else in the codebase should hardcode these.
class TaxiConstants {
  TaxiConstants._();

  static const String title = 'UdanX';

  /// The standalone taxi backend is gone — everything is served by k9 now.
  /// These delegate to the single source of truth in core/config so there is
  /// no second host to drift.
  static const String baseUrl = AppConstants.baseUrl;
  static const String socketUrl = AppConstants.socketUrl;

  /// Google Maps key — delegates to core so the ride and food sides can never
  /// drift onto different keys (they were on different ones before the merge).
  static String get mapKey => AppConstants.mapKey;

  /// Razorpay publishable key — not yet provided.
  static const String stripPublishKey = '';

  static String get packageName => AppConstants.packageName;

  /// Release keystore signing key alias/password — not yet provided.
  static const String signKey = '';

  // --- App behaviour constants (unrelated to environment/build config) ---
  static const int otpLength = 4;
  static const int phoneLength = 10;
  static const double defaultZoomLevel = 16;
  static const Duration otpResendCooldown = Duration(seconds: 30);

  // --- Centralized Font Styles (matching Onboarding & App Theme) ---
  static const String fontFamily = 'Roboto';

  static const TextStyle fontStyleHeadline = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: Color(0xFF0F172A),
    letterSpacing: -0.5,
  );

  static const TextStyle fontStyleTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: Color(0xFF0F172A),
    letterSpacing: -0.3,
  );

  static const TextStyle fontStyleSubTitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: Color(0xFF0F172A),
  );

  static const TextStyle fontStyleBody = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w500,
    color: Color(0xFF64748B),
    height: 1.4,
  );

  static const TextStyle fontStyleCaption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: Color(0xFF94A3B8),
  );
}
