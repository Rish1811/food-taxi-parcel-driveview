import 'package:flutter/material.dart';

/// Per-module brand colour.
///
/// This is how the super app stays visually coherent while each module keeps
/// its own identity — the hub and shared screens use [hub], and entering a
/// module re-accents that route subtree only.
///
/// Note the two inherited brands were *different* oranges: K9 shipped
/// `0xFFFF7A00` and UdanX `0xFFFF5C2B`. Both are preserved here rather than
/// silently reconciled — which one (if either) becomes the super-app brand is
/// a product decision, not an architectural one.
enum ModuleAccent {
  /// Hub and shared surfaces (wallet, activity, profile, settings).
  hub(Color(0xFFFF7A00), Color(0xFFFF8A1D)),

  /// K9 orange.
  food(Color(0xFFFF7A00), Color(0xFFFF8A1D)),

  /// UdanX orange.
  taxi(Color(0xFFFF5C2B), Color(0xFFE04313)),

  parcel(Color(0xFFF59E0B), Color(0xFFD97706)),

  rental(Color(0xFF3B82F6), Color(0xFF2563EB));

  const ModuleAccent(this.primary, this.primaryVariant);

  /// Main brand colour for the module.
  final Color primary;

  /// Slightly shifted variant, used for buttons and pressed states.
  final Color primaryVariant;
}
