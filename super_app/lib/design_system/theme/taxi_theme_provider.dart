import 'package:superapp_user/core/storage/storage_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:superapp_user/core/storage/storage_keys.dart';

/// Riverpod 3: `build()` replaces the constructor and *returns* the initial
/// state rather than assigning it. It also re-runs on invalidation, so it must
/// stay side-effect free — reading persisted state is fine, writing is not.
///
/// Follow-up: this duplicates the app-wide `themeProvider` that came from food.
/// They collapse into one controller in the shared-settings pass; kept separate
/// for now so the migration stays mechanical and reviewable.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final box = ref.read(localStorageServiceProvider).settings;
    return switch (box.get(StorageKeys.themeMode) as String?) {
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.light,
    };
  }

  void setThemeMode(ThemeMode mode) {
    state = mode;
    ref.read(localStorageServiceProvider).settings.put(
          StorageKeys.themeMode,
          mode.name,
        );
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
