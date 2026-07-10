import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shell/nav_config.dart';
import 'package:forja/shell/shell_body.dart';
import 'package:forja/shell/shell_bottom_nav.dart';
import 'package:forja/shell/shell_nav_rail.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';
import 'package:forja/shell/shell_scaffold.dart';
import 'package:forja/shell/home_top_bar.dart';
import 'package:forja/shared/design/src/forja_buttons.dart';
import 'package:forja/shared/design/src/forja_shell_colors.dart';
import 'package:forja/shared/design/src/shell_tokens.dart';
import 'package:forja/shared/design/design.dart';
import 'package:rust/src/settings_service.dart';

Widget _wrapShellScope(
  Widget child, {
  ShellProfile profile = ShellProfile.desktop,
  Size size = const Size(1200, 800),
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: ShellScope(
        profile: profile,
        config: shellPlatformConfigFor(profile),
        child: child,
      ),
    ),
  );
}

void main() {
  const visibleIds = ['home', 'search', 'settings'];

  setUp(() {
    ShellBus.homeCategory.value = null;
    ShellBus.homeSelectedGenreId.value = null;
    ShellBus.homeHeroHeight.value = 0;
    ShellBus.selectedWatchProviderId.value = null;
    ShellBus.requestTab.value = null;
    ShellBus.shellOverlayHasPage.value = false;
  });

  Future<void> pumpScaffold(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(400, 800),
    ShellProfile profile = ShellProfile.mobile,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _wrapShellScope(child, profile: profile, size: size),
    );
  }

  ShellScaffold desktopScaffold({
    bool hideGlobalNav = false,
    Widget? shellTopBar,
  }) {
    return ShellScaffold(
      useNavRail: true,
      visibleIds: visibleIds,
      selectedIndex: 1,
      mountedTabIds: const {'home', 'search'},
      onDestinationSelected: (_) {},
      tabFor: (id) => Center(child: Text(id)),
      hideGlobalNav: hideGlobalNav,
      shellTopBar: shellTopBar,
    );
  }

  testWidgets('ShellScaffold shows bottom nav on portrait mobile', (tester) async {
    await pumpScaffold(
      tester,
      ShellScaffold(
        useNavRail: false,
        visibleIds: visibleIds,
        selectedIndex: 0,
        mountedTabIds: const {'home'},
        onDestinationSelected: (_) {},
        tabFor: (id) => Center(child: Text(id)),
      ),
    );

    expect(find.byType(ShellBottomNav), findsOneWidget);
    expect(find.byType(ShellNavRail), findsNothing);
  });

  testWidgets('ShellScaffold hides bottom nav when hideGlobalNav is true', (tester) async {
    await pumpScaffold(
      tester,
      ShellScaffold(
        useNavRail: false,
        visibleIds: visibleIds,
        selectedIndex: 0,
        mountedTabIds: const {'home'},
        onDestinationSelected: (_) {},
        tabFor: (id) => Center(child: Text(id)),
        hideGlobalNav: true,
      ),
    );

    expect(find.byType(ShellBottomNav), findsNothing);
  });

  testWidgets('ShellScaffold shows rail on desktop; top bar only when passed', (tester) async {
    await pumpScaffold(
      tester,
      desktopScaffold(),
      size: const Size(1200, 800),
      profile: ShellProfile.desktop,
    );

    expect(find.byType(ShellNavRail), findsOneWidget);
    expect(find.byType(HomeTopBar), findsNothing);
    expect(find.byType(ShellBottomNav), findsNothing);
    expect(find.text('Films'), findsNothing);
  });

  testWidgets('ShellScaffold shows home top bar when shellTopBar is set', (tester) async {
    await pumpScaffold(
      tester,
      desktopScaffold(shellTopBar: const HomeTopBar()),
      size: const Size(1200, 800),
      profile: ShellProfile.desktop,
    );

    expect(find.byType(HomeTopBar), findsOneWidget);
    expect(find.text('Films'), findsOneWidget);
    expect(find.text('TV Shows'), findsOneWidget);
  });

  testWidgets('HomeTopBar Categories menu sets genre filter', (tester) async {
    await pumpScaffold(
      tester,
      desktopScaffold(shellTopBar: const HomeTopBar()),
      size: const Size(1200, 800),
      profile: ShellProfile.desktop,
    );

    await tester.tap(find.text('Categories'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Action'));
    await tester.pumpAndSettle();

    expect(ShellBus.homeSelectedGenreId.value, 'action');
  });

  testWidgets('HomeTopBar Films tap toggles homeCategory filter', (tester) async {
    await pumpScaffold(
      tester,
      desktopScaffold(shellTopBar: const HomeTopBar()),
      size: const Size(1200, 800),
      profile: ShellProfile.desktop,
    );

    expect(ShellBus.homeCategory.value, isNull);

    await tester.tap(find.text('Films'));
    await tester.pumpAndSettle();

    expect(ShellBus.homeCategory.value, ShellHomeCategory.films);

    await tester.tap(find.text('Films'));
    await tester.pumpAndSettle();

    expect(ShellBus.homeCategory.value, isNull);
  });

  testWidgets('ShellScaffold hides home top bar when shell overlay has page',
      (tester) async {
    await pumpScaffold(
      tester,
      desktopScaffold(shellTopBar: const HomeTopBar()),
      size: const Size(1200, 800),
      profile: ShellProfile.desktop,
    );

    expect(find.text('Films'), findsOneWidget);

    shellOverlayNavigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Details')),
      ),
    );
    await tester.pumpAndSettle();

    expect(ShellBus.shellOverlayHasPage.value, isTrue);

    shellOverlayNavigatorKey.currentState!.pop();
    await tester.pumpAndSettle();

    expect(ShellBus.shellOverlayHasPage.value, isFalse);
  });

  testWidgets('ShellScaffold dismisses shell overlay when nav destination selected',
      (tester) async {
    await pumpScaffold(
      tester,
      desktopScaffold(),
      size: const Size(1200, 800),
      profile: ShellProfile.desktop,
    );

    shellOverlayNavigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Details')),
      ),
    );
    await tester.pumpAndSettle();

    expect(ShellBus.shellOverlayHasPage.value, isTrue);
    expect(find.text('Details'), findsOneWidget);

    await tester.tap(
      find.image(const AssetImage('assets/images/nav/home.png')),
    );
    await tester.pumpAndSettle();

    expect(ShellBus.shellOverlayHasPage.value, isFalse);
    expect(find.text('Details'), findsNothing);
  });

  testWidgets('ShellScaffold collapses nav rail to left menu on home when narrow', (tester) async {
    await pumpScaffold(
      tester,
      desktopScaffold(shellTopBar: const HomeTopBar()),
      size: const Size(800, 800),
    );

    expect(find.byType(ShellNavRail), findsNothing);
    expect(find.byIcon(Icons.menu_rounded), findsOneWidget);

    final menuCenter = tester.getCenter(find.byIcon(Icons.menu_rounded));
    expect(menuCenter.dx, lessThan(120));

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(ShellNavRail), findsOneWidget);
    expect(
      find.image(const AssetImage('assets/images/nav/search.png')),
      findsOneWidget,
    );
  });

  testWidgets('ShellNavRail uses fixed width without hover expand', (tester) async {
    await pumpScaffold(
      tester,
      desktopScaffold(),
      size: const Size(1200, 800),
      profile: ShellProfile.desktop,
    );

    final railFinder = find.byType(ShellNavRail);
    expect(tester.getSize(railFinder).width, ShellTokens.navRailWidth);
    expect(find.text('Search'), findsNothing);
  });

  testWidgets('ShellNavRail reveals label after sustained hover', (tester) async {
    await pumpScaffold(
      tester,
      desktopScaffold(),
      size: const Size(1200, 800),
      profile: ShellProfile.desktop,
    );

    final searchIcon =
        find.image(const AssetImage('assets/images/nav/search.png'));
    expect(searchIcon, findsOneWidget);
    expect(find.text('Search'), findsNothing);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();
    await gesture.moveTo(tester.getCenter(searchIcon));
    await tester.pump();
    await tester.pump(ShellTokens.navRailLabelRevealDelay);
    for (var i = 0; i < 12; i++) {
      await tester.pump(ShellTokens.navRailLabelLetterInterval);
    }
    await tester.pumpAndSettle();

    expect(find.text('Search'), findsOneWidget);

    final searchItem = find.ancestor(
      of: searchIcon,
      matching: find.byWidgetPredicate(
        (w) => w is SizedBox && w.height != null && w.width == ShellTokens.navRailWidth,
      ),
    );
    expect(searchItem, findsWidgets);
  });

  testWidgets('ShellScaffold body is inset by fixed rail width', (tester) async {
    await pumpScaffold(
      tester,
      desktopScaffold(),
      size: const Size(1200, 800),
      profile: ShellProfile.desktop,
    );

    final bodyBox = tester.renderObject<RenderBox>(find.byType(ShellBody));
    expect(bodyBox.size.width, 1200 - ShellTokens.navRailWidth);
  });

  testWidgets('ShellScaffold hides rail when hideGlobalNav is true', (tester) async {
    await pumpScaffold(
      tester,
      desktopScaffold(hideGlobalNav: true),
      size: const Size(1200, 800),
      profile: ShellProfile.desktop,
    );

    expect(find.byType(ShellNavRail), findsNothing);
    expect(find.byType(HomeTopBar), findsNothing);
  });

  testWidgets('ForjaGhostButton is text-only; ForjaPlainIcon has no border box', (tester) async {
    await pumpScaffold(
      tester,
      Scaffold(
        body: Row(
          children: [
            ForjaGhostButton(label: 'Watch Now', onTap: () {}),
            ForjaPlainIcon(icon: Icons.info_outline, onTap: () {}),
          ],
        ),
      ),
      size: const Size(600, 200),
    );

    expect(find.text('Watch Now'), findsOneWidget);
    expect(find.byType(ForjaPlainIcon), findsOneWidget);
    expect(find.byType(ForjaIconButton), findsNothing);
  });

  testWidgets('ForjaPlainIcon and ForjaCloseButton use circular hover, no border', (tester) async {
    await pumpScaffold(
      tester,
      const Scaffold(
        body: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ForjaPlainIcon(icon: Icons.tune_rounded, onTap: null),
            ForjaCloseButton(onTap: null),
          ],
        ),
      ),
      size: const Size(200, 120),
    );

    final borderFinder = find.byWidgetPredicate(
      (widget) =>
          widget is DecoratedBox &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).border != null,
    );
    expect(borderFinder, findsNothing);

    final circleFinder = find.byWidgetPredicate(
      (widget) =>
          widget is DecoratedBox &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).shape == BoxShape.circle,
    );
    expect(circleFinder, findsWidgets);
  });

  testWidgets('ShellBottomNav is flat without BackdropFilter', (tester) async {
    await pumpScaffold(
      tester,
      ShellScaffold(
        useNavRail: false,
        visibleIds: visibleIds,
        selectedIndex: 0,
        mountedTabIds: const {'home'},
        onDestinationSelected: (_) {},
        tabFor: (id) => Center(child: Text(id)),
      ),
    );

    expect(find.byType(ShellBottomNav), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  test('ForjaShellColors uses dark shell palette', () {
    expect(ForjaShellColors.textPrimary, const Color(0xFFE5E7EB));
    expect(ForjaShellColors.cinematic.textPrimary, const Color(0xFFE5E7EB));
  });

  test('navDestinations includes default shell tabs', () {
    expect(navDestinations.containsKey('home'), isTrue);
    expect(navDestinations.containsKey('search'), isTrue);
    expect(navDestinations.containsKey('asian_drama'), isTrue);
    expect(navDestinations.containsKey('anime'), isTrue);
    expect(navDestinations.containsKey('iptv'), isTrue);
    expect(navDestinations.containsKey('live_matches'), isTrue);
    expect(navDestinations.containsKey('mylist'), isTrue);
    expect(navDestinations.containsKey('settings'), isTrue);
    expect(SettingsService.defaultVisibleNavIds, [
      'home',
      'search',
      'asian_drama',
      'anime',
      'iptv',
      'live_matches',
      'mylist',
    ]);
  });
}
