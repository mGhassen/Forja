import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/settings/profile/language_group.dart';
import 'package:forja/l10n/app_localizations.dart';
import 'package:forja/shared/services/app/app_locale.dart';
import 'package:forja/shell/core/forja_shell_platform.dart';
import 'package:forja/shell/core/forja_shell_profile.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:rust/rust.dart';

import 'helpers/rust_engine.dart';

void main() {
  late Directory tmp;
  var storeCounter = 0;

  Future<void> openFreshStore() async {
    final path = '${tmp.path}/store_${storeCounter++}.json';
    RustLib.instance.storageOpen(path);
    AppLocale.notifier.value = null;
  }

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tmp = await Directory.systemTemp.createTemp('forja_app_language_');
    // Engine.init asks path_provider for a directory; no plugin runs in tests.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => tmp.path,
        );
    await initRustForAppTests();
    await Engine.init(storagePath: '${tmp.path}/init.json');
  });

  tearDownAll(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  setUp(openFreshStore);

  test('a fresh install follows the device language', () async {
    expect(await SettingsService().getAppLanguage(), AppLocale.system);
    await AppLocale.init();
    expect(AppLocale.notifier.value, isNull);
  });

  test('the chosen language survives a restart', () async {
    await AppLocale.select('fr');
    expect(AppLocale.notifier.value, const Locale('fr'));
    expect(await SettingsService().getAppLanguage(), 'fr');

    AppLocale.notifier.value = null; // a new process starts with nothing loaded
    await AppLocale.init();
    expect(AppLocale.notifier.value, const Locale('fr'));
  });

  test('choosing the device language is saved as such', () async {
    await AppLocale.select('fr');
    await AppLocale.select(AppLocale.system);
    expect(AppLocale.notifier.value, isNull);
    expect(await SettingsService().getAppLanguage(), AppLocale.system);
  });

  test(
    'a saved language the app does not ship falls back to the device',
    () async {
      await SettingsService().setAppLanguage('xx');
      await AppLocale.init();
      expect(AppLocale.notifier.value, isNull);
    },
  );

  testWidgets('the picker in Settings switches the screen to French', (
    tester,
  ) async {
    await tester.pumpWidget(
      ValueListenableBuilder<Locale?>(
        valueListenable: AppLocale.notifier,
        builder: (context, locale, _) => MaterialApp(
          locale: locale ?? const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ShellScope(
            profile: ShellProfile.desktop,
            config: shellPlatformConfigFor(ShellProfile.desktop),
            child: const Scaffold(body: SettingsLanguageGroup()),
          ),
        ),
      ),
    );
    expect(
      find.text('LANGUAGE'),
      findsOneWidget,
    ); // SettingsGroup uppercases labels
    expect(find.text('App language'), findsOneWidget);

    await tester.tap(find.text('System default'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Français').last);
    await tester.pumpAndSettle();

    expect(AppLocale.notifier.value, const Locale('fr'));
    expect(find.text('LANGUE'), findsOneWidget);
    expect(find.text("Langue de l'application"), findsOneWidget);
    expect(find.text('LANGUAGE'), findsNothing);
    expect(await SettingsService().getAppLanguage(), 'fr');
  });
}
