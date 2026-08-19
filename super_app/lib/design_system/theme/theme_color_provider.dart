import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:superapp_user/design_system/tokens/app_colors.dart';

/// A preset brand color the user can pick from Profile → App Theme.
///
/// `orange` is the app's shipped default — its [color]/[buttonColor] match
/// [AppColors]' original hardcoded values exactly, so selecting it (or never
/// changing the theme at all) looks pixel-identical to before this feature.
enum AppThemeColor {
  orange('Orange', Color(0xFFFF7A00), Color(0xFFFF8A1D), '🟠'),
  green('Green', Color(0xFF2ECC71), Color(0xFF43D881), '🟢'),
  blue('Blue', Color(0xFF3B82F6), Color(0xFF5B95F8), '🔵'),
  red('Red', Color(0xFFE53935), Color(0xFFEB5C58), '🔴'),
  purple('Purple', Color(0xFF8E44AD), Color(0xFFA25FC0), '🟣'),
  pink('Pink', Color(0xFFEC4899), Color(0xFFF06CAA), '🩷');

  const AppThemeColor(this.label, this.color, this.buttonColor, this.emoji);

  final String label;
  final Color color;
  final Color buttonColor;
  final String emoji;
}

/// Persists and applies the selected [AppThemeColor].
///
/// Applying a color means reassigning the mutable [AppColors.primary] /
/// [AppColors.primaryButton] fields, then bumping [state] so every widget
/// watching [themeColorProvider] (currently just the app root, to rebuild
/// `MaterialApp`'s `theme`/`darkTheme`) rebuilds — which in turn makes every
/// `AppColors.primary` read across the app pick up the new value, since nothing
/// caches it.
final themeColorProvider =
    NotifierProvider<ThemeColorNotifier, AppThemeColor>(ThemeColorNotifier.new);

class ThemeColorNotifier extends Notifier<AppThemeColor> {
  static const _key = 'app_theme_color';

  @override
  AppThemeColor build() {
    unawaited(_load());
    return AppThemeColor.orange;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved == null) return;
    for (final option in AppThemeColor.values) {
      if (option.name == saved) {
        _apply(option);
        return;
      }
    }
  }

  Future<void> setColor(AppThemeColor color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, color.name);
    _apply(color);
  }

  void _apply(AppThemeColor color) {
    AppColors.primary = color.color;
    AppColors.primaryButton = color.buttonColor;
    state = color;
  }
}
