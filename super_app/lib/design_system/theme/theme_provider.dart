import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(() {
  return ThemeNotifier();
});

class ThemeNotifier extends Notifier<ThemeMode> {
  static const _themeKey = 'app_theme_mode';

  @override
  ThemeMode build() {
    _loadTheme();
    return ThemeMode.light;
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString(_themeKey);
    if (savedTheme != null) {
      if (savedTheme == 'Light') {
        state = ThemeMode.light;
      } else if (savedTheme == 'Dark') {
        state = ThemeMode.dark;
      } else {
        state = ThemeMode.system;
      }
    }
  }

  Future<void> setTheme(String themeStr) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, themeStr);
    if (themeStr == 'Light') {
      state = ThemeMode.light;
    } else if (themeStr == 'Dark') {
      state = ThemeMode.dark;
    } else {
      state = ThemeMode.system;
    }
  }
}
