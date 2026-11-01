import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';
import 'package:forja/l10n/app_localizations.dart';
import 'package:rust/rust.dart';

/// UI language: follows the device unless the user picked one in Settings.
abstract final class AppLocale {
  static const String system = 'system';

  /// Language names in their own language, so a user can always find theirs.
  static const Map<String, String> nativeNames = {
    'en': 'English',
    'fr': 'Français',
  };

  /// `null` follows the device language.
  static final ValueNotifier<Locale?> notifier = ValueNotifier<Locale?>(null);

  /// The saved choice: a language code, or [system].
  static String get code => notifier.value?.languageCode ?? system;

  /// Unknown or unsupported codes follow the device.
  static Locale? fromCode(String code) {
    for (final locale in AppLocalizations.supportedLocales) {
      if (locale.languageCode == code) return locale;
    }
    return null;
  }

  /// Messages in the app language, for code with no [BuildContext].
  static AppLocalizations get strings =>
      lookupAppLocalizations(Locale(activeCode));

  /// TMDB tag for each app language, used for titles, overviews and genres.
  static const Map<String, String> tmdbTags = {'en': 'en-US', 'fr': 'fr-FR'};

  /// The language the app shows now: the chosen one, else the device's when the
  /// app has it, else English.
  static String get activeCode {
    final chosen = notifier.value?.languageCode;
    if (chosen != null) return chosen;
    final device = _deviceLocale.languageCode;
    return fromCode(device) != null ? device : 'en';
  }

  /// The device locale. Falls back to the engine's own dispatcher when no
  /// widgets binding exists yet (plain Dart tests, early boot).
  static Locale get _deviceLocale {
    try {
      return WidgetsBinding.instance.platformDispatcher.locale;
    } catch (_) {
      return PlatformDispatcher.instance.locale;
    }
  }

  /// BCP 47 tag for APIs that can answer in the app language, e.g. `fr-FR`.
  static String get contentLocale =>
      tmdbTags[activeCode] ?? TmdbLanguage.fallback;

  static Future<void> init() async {
    notifier.value = fromCode(await SettingsService().getAppLanguage());
    TmdbLanguage.resolve = () => contentLocale;
  }

  static Future<void> select(String code) async {
    final locale = fromCode(code);
    notifier.value = locale;
    await SettingsService().setAppLanguage(locale?.languageCode ?? system);
  }
}
