import 'package:superapp_user/core/storage/storage_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:superapp_user/core/storage/storage_keys.dart';

class LocaleNotifier extends Notifier<String> {
  @override
  String build() {
    final box = ref.read(localStorageServiceProvider).settings;
    return (box.get(StorageKeys.localeCode) as String?) ?? 'en';
  }

  void setLocale(String code) {
    state = code;
    ref.read(localStorageServiceProvider).settings.put(
          StorageKeys.localeCode,
          code,
        );
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, String>(LocaleNotifier.new);

/// NOTE: only `en` actually has strings today. The app ships no ARB files and
/// no `localizationsDelegates`, so selecting any other entry currently changes
/// a stored value and nothing else. Trim this list to what is really
/// translated before exposing the language screen — see docs/superapp Ch. 6.7.
const supportedLanguages = [
  {'code': 'en', 'label': 'English', 'native': 'English'},
  {'code': 'hi', 'label': 'Hindi', 'native': 'हिन्दी'},
  {'code': 'ta', 'label': 'Tamil', 'native': 'தமிழ்'},
  {'code': 'te', 'label': 'Telugu', 'native': 'తెలుగు'},
  {'code': 'kn', 'label': 'Kannada', 'native': 'ಕನ್ನಡ'},
];
