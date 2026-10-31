import 'package:forja/l10n/app_localizations_en.dart';
import 'package:forja/l10n/l10n.dart';
import 'package:forja/shell/routing/shell_overlay_navigator.dart';

/// Localizations for code that has no BuildContext (services, toasts raised
/// from helpers). Read at call time, so it follows the current app language;
/// English when the shell is not mounted (tests, separate windows).
AppLocalizations get shellAmbientL10n {
  try {
    return shellOverlayNavigatorKey.currentContext?.l10n ??
        AppLocalizationsEn();
  } catch (_) {
    // No widgets binding yet (plain Dart tests, early boot): reading the key's
    // context throws instead of returning null.
    return AppLocalizationsEn();
  }
}
