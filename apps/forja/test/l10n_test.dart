import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/settings/shell/catalog.dart';
import 'package:forja/features/settings/shell/visibility.dart';
import 'package:forja/l10n/app_localizations.dart';
import 'package:forja/shared/services/app/app_locale.dart';

Map<String, String> _messages(File arb) {
  final json = jsonDecode(arb.readAsStringSync()) as Map<String, dynamic>;
  return {
    for (final e in json.entries)
      if (!e.key.startsWith('@')) e.key: e.value as String,
  };
}

Set<String> _placeholders(String message) => {
  for (final m in RegExp(r'\{(\w+)\}').allMatches(message)) m.group(1)!,
};

void main() {
  final arbs = Directory('lib/l10n')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.arb'))
      .toList();
  final template = _messages(File('lib/l10n/app_en.arb'));

  group('message catalogs', () {
    test('there is a catalog besides the English template', () {
      expect(arbs.length, greaterThan(1));
    });

    for (final arb in arbs) {
      final name = arb.uri.pathSegments.last;
      test('$name has every key of the template, and no others', () {
        final messages = _messages(arb);
        expect(
          template.keys.toSet().difference(messages.keys.toSet()),
          isEmpty,
          reason: 'missing from $name',
        );
        expect(
          messages.keys.toSet().difference(template.keys.toSet()),
          isEmpty,
          reason: 'not in the template',
        );
      });

      test(
        '$name is reflected in the generated Dart (run flutter gen-l10n)',
        () {
          final lang = name.replaceAll(RegExp(r'^app_|\.arb$'), '');
          final generated = File('lib/l10n/app_localizations_$lang.dart')
              .readAsStringSync();
          for (final e in _messages(arb).entries) {
            if (e.value.contains('{')) continue;
            final literal = e.value
                .replaceAll(r'\', r'\\')
                .replaceAll("'", r"\'")
                .replaceAll(r'$', r'\$')
                .replaceAll('"', r'\"')
                .replaceAll('\n', r'\n');
            expect(
              generated,
              contains("'$literal'"),
              reason: '${e.key} in $name is stale in the generated file',
            );
          }
        },
      );

      test('$name keeps the template placeholders and has no empty text', () {
        final messages = _messages(arb);
        for (final e in messages.entries) {
          expect(e.value.trim(), isNotEmpty, reason: '${e.key} in $name');
          if (template.containsKey(e.key)) {
            expect(
              _placeholders(e.value),
              _placeholders(template[e.key]!),
              reason: '${e.key} in $name',
            );
          }
        }
      });
    }
  });

  test('every supported language has a name in its own language', () {
    for (final locale in AppLocalizations.supportedLocales) {
      expect(AppLocale.nativeNames, contains(locale.languageCode));
    }
  });

  test('every supported language has a TMDB language tag', () {
    for (final locale in AppLocalizations.supportedLocales) {
      expect(AppLocale.tmdbTags, contains(locale.languageCode));
    }
  });

  testWidgets('API language follows the chosen language, else the device', (
    tester,
  ) async {
    final dispatcher = tester.platformDispatcher;
    addTearDown(() {
      dispatcher.clearLocaleTestValue();
      AppLocale.notifier.value = null;
    });

    AppLocale.notifier.value = null;
    dispatcher.localeTestValue = const Locale('fr', 'FR');
    expect(AppLocale.contentLocale, 'fr-FR');
    dispatcher.localeTestValue = const Locale('de', 'DE');
    expect(AppLocale.contentLocale, 'en-US');
    dispatcher.localeTestValue = const Locale('en', 'GB');
    expect(AppLocale.contentLocale, 'en-US');

    AppLocale.notifier.value = const Locale('fr');
    dispatcher.localeTestValue = const Locale('en', 'US');
    expect(AppLocale.contentLocale, 'fr-FR');
    AppLocale.notifier.value = const Locale('en');
    dispatcher.localeTestValue = const Locale('fr', 'FR');
    expect(AppLocale.contentLocale, 'en-US');
  });

  test('an unsupported or unknown saved code follows the device', () {
    expect(AppLocale.fromCode('fr'), const Locale('fr'));
    expect(AppLocale.fromCode(AppLocale.system), isNull);
    expect(AppLocale.fromCode('xx'), isNull);
  });

  group('settings catalog follows the app language', () {
    const visibility = SettingsVisibility(
      playSourceTorrent: false,
      playSourceStremio: false,
      playSourceNuvio: false,
      playSourceEngine: false,
      showPlaySourceTorrentToggle: false,
      showPlaySourceStremioToggle: false,
      showPlaySourceNuvioToggle: false,
      showPlaySourceEngineToggle: false,
      lanPlaySourcesEditable: false,
      vodTab: false,
      iptvNav: false,
    );

    Future<String> profileTitleIn(WidgetTester tester, Locale locale) async {
      late String title;
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context);
              title = settingsCategoryById(
                SettingsCategoryId.profile,
                visibility,
              )!.titleOf(l10n);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return title;
    }

    testWidgets('English', (tester) async {
      expect(
        await profileTitleIn(tester, const Locale('en')),
        'Profile & account',
      );
    });

    testWidgets('French', (tester) async {
      expect(
        await profileTitleIn(tester, const Locale('fr')),
        'Profil et compte',
      );
    });
  });
}
