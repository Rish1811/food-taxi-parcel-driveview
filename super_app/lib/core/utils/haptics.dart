import 'package:flutter/services.dart';

/// Thin, semantic wrapper over [HapticFeedback] so every call site reaches
/// for an intent ("light tap", "confirmed action") instead of picking a raw
/// platform constant — keeps the feel consistent across the app and makes
/// it trivial to retune later in one place.
class Haptics {
  Haptics._();

  /// Instant tactile acknowledgement for a tap — buttons, +/-, opening a
  /// screen. Fired immediately on press so the UI always feels responsive,
  /// even before any async work behind it finishes.
  static void light() => HapticFeedback.lightImpact();

  /// A slightly stronger pulse for an action that just meaningfully changed
  /// state — item landed in the cart, favorite toggled, checkout completed.
  static void medium() => HapticFeedback.mediumImpact();

  /// Reserved for the big positive moments (order placed, payment success).
  /// Same weight as [medium] today — kept as its own name so call sites read
  /// with intent and can be retuned independently later.
  static void success() => HapticFeedback.mediumImpact();

  /// Rejection / validation failure.
  static void error() => HapticFeedback.heavyImpact();
}
