import 'package:flutter/widgets.dart';
import 'package:forja/l10n/app_localizations.dart';
import 'package:forja/l10n/app_localizations_en.dart';

export 'package:forja/l10n/app_localizations.dart';

extension AppLocalizationsContext on BuildContext {
  /// English when no localizations are in scope (separate windows, bare hosts).
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      AppLocalizationsEn();
}
