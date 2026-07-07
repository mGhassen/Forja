import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shell/nav_config.dart';
import 'package:forja/shell/shell_body.dart';
import 'package:forja/shell/shell_bottom_nav.dart';
import 'package:forja/shell/shell_nav_rail.dart';
import 'package:forja/shell/shell_scaffold.dart';
import 'package:forja/shared/design/src/shell_tokens.dart';
import 'package:rust/rust.dart';

void main() {
  const visibleIds = ['home', 'search', 'settings'];

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

  ShellScaffold desktopScaffold({bool hideGlobalNav = false}) {
    return ShellScaffold(
      useNavRail: true,
      isDesktop: true,
      visibleIds: visibleIds,
      selectedIndex: 1,
      mountedTabIds: const {'home', 'search'},
      onDestinationSelected: (_) {},
      tabFor: (id) => Center(child: Text(id)),
      hideGlobalNav: hideGlobalNav,
    );
  }

  testWidgets('ShellScaffold shows rail on desktop layout', (tester) async {
    await pumpScaffold(
      tester,
      desktopScaffold(),
      size: const Size(1200, 800),
    );

    expect(find.byType(ShellNavRail), findsOneWidget);
    expect(find.byType(ShellBottomNav), findsNothing);
    expect(find.text('Search'), findsNothing);
  });

  testWidgets('ShellNavRail expands on hover and shows labels', (tester) async {
    await pumpScaffold(
      tester,
      desktopScaffold(),
      size: const Size(1200, 800),
    );

    final railFinder = find.byType(ShellNavRail);
    expect(tester.getSize(railFinder).width, ShellTokens.navRailCollapsedWidth);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();
    await gesture.moveTo(tester.getCenter(railFinder));
    await tester.pump();
    await tester.pump(ShellTokens.navRailExpandDuration);

    expect(tester.getSize(railFinder).width, ShellTokens.navRailExpandedWidth);
    expect(find.text('Search'), findsOneWidget);
  });

  testWidgets('ShellScaffold body is full width with overlay rail', (tester) async {
    await pumpScaffold(
      tester,
      desktopScaffold(),
      size: const Size(1200, 800),
    );

    final bodyBox = tester.renderObject<RenderBox>(find.byType(ShellBody));
    expect(bodyBox.size.width, 1200);
  });

  testWidgets('ShellScaffold hides rail when hideGlobalNav is true', (tester) async {
    await pumpScaffold(
      tester,
      desktopScaffold(hideGlobalNav: true),
      size: const Size(1200, 800),
    );

    expect(find.byType(ShellNavRail), findsNothing);
  });

  testWidgets('ShellScaffold has flat background without ambient glows', (tester) async {
    await pumpScaffold(
      tester,
      desktopScaffold(),
      size: const Size(1200, 800),
    );

    expect(find.byType(Positioned), findsNWidgets(2));
  });

  test('navDestinations includes default shell tabs', () {
    expect(navDestinations.containsKey('home'), isTrue);
    expect(navDestinations.containsKey('search'), isTrue);
    expect(navDestinations.containsKey('mylist'), isTrue);
    expect(navDestinations.containsKey('settings'), isTrue);
    expect(SettingsService.defaultVisibleNavIds, ['home', 'search', 'mylist']);
  });
}
