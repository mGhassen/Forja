import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shell/nav_config.dart';
import 'package:forja/shell/shell_body.dart';
import 'package:forja/shell/shell_bottom_nav.dart';
import 'package:forja/shell/shell_nav_rail.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shell/shell_scaffold.dart';
import 'package:forja/shell/home_top_bar.dart';
import 'package:forja/shared/design/src/forja_buttons.dart';
import 'package:forja/shared/design/src/shell_tokens.dart';
import 'package:rust/src/settings_service.dart';

void main() {
  const visibleIds = ['home', 'search', 'settings'];

  setUp(() {
    ShellBus.homeCategory.value = null;
    ShellBus.homeSelectedGenreId.value = null;
    ShellBus.homeHeroHeight.value = 0;
    ShellBus.selectedWatchProviderId.value = null;
    ShellBus.requestTab.value = null;
  });

  Future<void> pumpScaffold(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(400, 800),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: child,
        ),
      ),
    );
  }

  ShellScaffold desktopScaffold({
    bool hideGlobalNav = false,
    Widget? shellTopBar,
  }) {
    return ShellScaffold(
      useNavRail: true,
      isDesktop: true,
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
        isDesktop: false,
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
        isDesktop: false,
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
    );

    expect(ShellBus.homeCategory.value, isNull);

    await tester.tap(find.text('Films'));
    await tester.pumpAndSettle();

    expect(ShellBus.homeCategory.value, ShellHomeCategory.films);

    await tester.tap(find.text('Films'));
    await tester.pumpAndSettle();

    expect(ShellBus.homeCategory.value, isNull);
  });

  testWidgets('ShellNavRail uses fixed width without hover expand', (tester) async {
    await pumpScaffold(
      tester,
      desktopScaffold(),
      size: const Size(1200, 800),
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
    );

    final searchIcon = find.byIcon(Icons.search);
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
  });

  testWidgets('ShellScaffold body is inset by fixed rail width', (tester) async {
    await pumpScaffold(
      tester,
      desktopScaffold(),
      size: const Size(1200, 800),
    );

    final bodyBox = tester.renderObject<RenderBox>(find.byType(ShellBody));
    expect(bodyBox.size.width, 1200 - ShellTokens.navRailWidth);
  });

  testWidgets('ShellScaffold hides rail when hideGlobalNav is true', (tester) async {
    await pumpScaffold(
      tester,
      desktopScaffold(hideGlobalNav: true),
      size: const Size(1200, 800),
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

  testWidgets('ShellBottomNav is flat without BackdropFilter', (tester) async {
    await pumpScaffold(
      tester,
      ShellScaffold(
        useNavRail: false,
        isDesktop: false,
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

  test('navDestinations includes default shell tabs', () {
    expect(navDestinations.containsKey('home'), isTrue);
    expect(navDestinations.containsKey('search'), isTrue);
    expect(navDestinations.containsKey('mylist'), isTrue);
    expect(navDestinations.containsKey('settings'), isTrue);
    expect(SettingsService.defaultVisibleNavIds, ['home', 'search', 'mylist']);
  });
}
