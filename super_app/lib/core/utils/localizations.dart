import 'package:flutter/widgets.dart';
import 'package:superapp_user/generated/l10n/app_localizations.dart';

extension LocalizationsExtension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
  AppLocalizations get localization => AppLocalizations.of(this)!;
}