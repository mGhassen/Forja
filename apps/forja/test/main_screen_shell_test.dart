import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shell/main_screen.dart';
import 'package:forja/shell/nav_config.dart';
import 'package:forja/shell/shell_bottom_nav.dart';
import 'package:forja/shell/shell_nav_rail.dart';
import 'package:forja/shell/shell_search_bar.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shared/design/src/shell_tab_header.dart';
import 'package:rust/rust.dart';

import 'helpers/rust_test_init.dart';

Future<void> _pumpMainScreen(
  WidgetTester tester, {
  required Size size,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: const MainScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> _tapNavId(WidgetTester tester, String navId) async {
  final dest = navDestinations[navId]!;
  final icons = find.byIcon(dest.icon);
  if (icons.evaluate().isNotEmpty) {
    await tester.tap(icons.first);
    return;
  }
  await tester.tap(find.byIcon(dest.activeIcon).first);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initEngineForTests();
  });

  tearDown(() {
    ShellBus.requestTab.value = null;
    ShellBus.clearHideGlobalNav();
  });

  testWidgets('desktop: rail visible and tab switch to Search', (tester) async {
    await _pumpMainScreen(
      tester,
      size: const Size(1200, 800),
    );

    expect(find.byType(ShellNavRail), findsOneWidget);
    expect(find.byType(ShellBottomNav), findsNothing);

    await _tapNavId(tester, 'search');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(ShellSearchBar), findsOneWidget);
  });

  testWidgets('mobile portrait: bottom nav on non-desktop host', (tester) async {
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      return;
    }

    await _pumpMainScreen(
      tester,
      size: const Size(400, 800),
    );

    expect(find.byType(ShellBottomNav), findsOneWidget);
    expect(find.byType(ShellNavRail), findsNothing);

    await tester.tap(find.text('Settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Settings', skipOffstage: false), findsWidgets);
  });

  testWidgets('ShellBus.requestTab switches to Search tab', (tester) async {
    await _pumpMainScreen(
      tester,
      size: const Size(1200, 800),
    );

    ShellBus.requestTab.value = 'search';
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(ShellSearchBar), findsOneWidget);
    expect(ShellBus.requestTab.value, isNull);
  });

  testWidgets('navbar config reorder persists after notifier', (tester) async {
    await SettingsService().setNavbarConfig(['search', 'home']);
    await _pumpMainScreen(
      tester,
      size: const Size(1200, 800),
    );

    expect(find.byIcon(Icons.search), findsWidgets);

    await SettingsService().setNavbarConfig(['home', 'search']);
    SettingsService.navbarChangeNotifier.value++;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.byIcon(Icons.home).evaluate().isNotEmpty ||
          find.byIcon(Icons.home_outlined).evaluate().isNotEmpty,
      isTrue,
    );
    expect(find.byIcon(Icons.search), findsWidgets);
  });

  testWidgets('desktop core tabs switch without duplicate shell chrome', (tester) async {
    await SettingsService().setNavbarConfig(['home', 'search', 'mylist']);
    await _pumpMainScreen(
      tester,
      size: const Size(1200, 800),
    );

    expect(find.byIcon(Icons.home), findsWidgets);
    expect(find.byIcon(Icons.bookmark_outline), findsWidgets);
    expect(find.byType(ShellNavRail), findsOneWidget);

    await _tapNavId(tester, 'search');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(ShellSearchBar), findsOneWidget);

    await _tapNavId(tester, 'mylist');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(ShellTabHeader), findsOneWidget);

    await _tapNavId(tester, 'settings');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(ShellTabHeader), findsOneWidget);
    expect(find.byType(ShellNavRail), findsOneWidget);
  });

  testWidgets('music desktop hides global rail when tab selected', (tester) async {
    if (!Platform.isMacOS && !Platform.isWindows && !Platform.isLinux) {
      return;
    }

    await SettingsService().setNavbarConfig(['home', 'search', 'music']);
    await _pumpMainScreen(
      tester,
      size: const Size(1200, 800),
    );

    ShellBus.hideGlobalNav.value = true;
    ShellBus.notifyShellChromeChanged();
    await tester.pump();
    expect(find.byType(ShellNavRail), findsNothing);

    ShellBus.clearHideGlobalNav();
    ShellBus.notifyShellChromeChanged();
    await tester.pump();
    expect(find.byType(ShellNavRail), findsOneWidget);
  });

  testWidgets('IPTV deep view hides global nav via ShellBus', (tester) async {
    ShellBus.hideGlobalNav.value = true;
    ShellBus.notifyShellChromeChanged();

    await _pumpMainScreen(
      tester,
      size: const Size(1200, 800),
    );

    expect(find.byType(ShellNavRail), findsNothing);

    ShellBus.clearHideGlobalNav();
    ShellBus.notifyShellChromeChanged();
    await tester.pump();

    expect(find.byType(ShellNavRail), findsOneWidget);
  });

  testWidgets('navbar hide evicts tab from mount set', (tester) async {
    await SettingsService().setNavbarConfig(['home', 'search', 'mylist', 'discover']);
    await _pumpMainScreen(tester, size: const Size(1200, 800));

    await _tapNavId(tester, 'discover');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await SettingsService().setNavbarConfig(['home', 'search', 'mylist']);
    SettingsService.navbarChangeNotifier.value++;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await SettingsService().setNavbarConfig(['home', 'search', 'mylist', 'discover']);
    SettingsService.navbarChangeNotifier.value++;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await _tapNavId(tester, 'discover');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('lazy mount: each configured nav tab builds once (R16-A05 smoke)', (tester) async {
    await SettingsService().setNavbarConfig([
      'home',
      'discover',
      'similar',
      'search',
      'mylist',
    ]);
    await _pumpMainScreen(tester, size: const Size(1200, 800));

    for (final id in ['discover', 'similar', 'search', 'mylist', 'home']) {
      await _tapNavId(tester, id);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byType(ShellNavRail), findsOneWidget);
    await _tapNavId(tester, 'settings');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(ShellTabHeader), findsOneWidget);
  });
}
