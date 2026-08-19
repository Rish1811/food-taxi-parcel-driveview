import 'package:flutter/services.dart';

class HapticService {
  // Singleton pattern
  static final HapticService _instance = HapticService._internal();
  factory HapticService() => _instance;
  HapticService._internal();

  // Global flag to enable or disable haptics
  bool enabled = true;

  static void selection() {
    if (_instance.enabled) {
      HapticFeedback.selectionClick();
    }
  }

  static void light() {
    if (_instance.enabled) {
      HapticFeedback.lightImpact();
    }
  }

  static void medium() {
    if (_instance.enabled) {
      HapticFeedback.mediumImpact();
    }
  }

  static void heavy() {
   // print("HAPTIC SERVICE: Triggering Heavy Impact");
    if (_instance.enabled) {
      // Calling vibrate() as well because some Android skins (like Vivo) 
      // suppress or don't map heavyImpact() correctly.
      HapticFeedback.vibrate(); 
      HapticFeedback.heavyImpact();
    }
  }

  static void success() {
    if (_instance.enabled) {
      HapticFeedback.heavyImpact();
    }
  }

  static void error() {
    if (_instance.enabled) {
      HapticFeedback.vibrate();
    }
  }
}
