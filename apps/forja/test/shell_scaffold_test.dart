import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shell/nav_config.dart';
import 'package:forja/shell/shell_bottom_nav.dart';
import 'package:forja/shell/shell_nav_rail.dart';
import 'package:forja/shell/shell_scaffold.dart';
import 'package:rust/rust.dart';

void main() {
  const visibleIds = ['home', 'search', 'settings'];

  Widget wrap(Widget child) {
    return MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(400, 800)),
        child: child,
      ),
    );
  }

  testWidgets('ShellScaffold shows bottom nav on portrait mobile', (tester) async {
    await tester.pumpWidget(
      wrap(
        ShellScaffold(
          useNavRail: false,
          isDesktop: false,
          visibleIds: visibleIds,
          selectedIndex: 0,
          mountedTabIds: const {'home'},
          onDestinationSelected: (_) {},
          tabFor: (id) => Center(child: Text(id)),
        ),
      ),
    );

    expect(find.byType(ShellBottomNav), findsOneWidget);
    expect(find.byType(ShellNavRail), findsNothing);
  });

  testWidgets('ShellScaffold hides bottom nav when hideGlobalNav is true', (tester) async {
    await tester.pumpWidget(
      wrap(
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
      ),
    );

    expect(find.byType(ShellBottomNav), findsNothing);
  });

  testWidgets('ShellScaffold shows rail on desktop layout', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1200, 800)),
          child: ShellScaffold(
            useNavRail: true,
            isDesktop: true,
            visibleIds: visibleIds,
            selectedIndex: 1,
            mountedTabIds: const {'home', 'search'},
            onDestinationSelected: (_) {},
            tabFor: (id) => Center(child: Text(id)),
          ),
        ),
      ),
    );

    expect(find.byType(ShellNavRail), findsOneWidget);
    expect(find.byType(ShellBottomNav), findsNothing);
    expect(find.text('search'), findsOneWidget);
  });

  testWidgets('ShellScaffold hides rail when hideGlobalNav is true', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1200, 800)),
          child: ShellScaffold(
            useNavRail: true,
            isDesktop: true,
            visibleIds: visibleIds,
            selectedIndex: 0,
            mountedTabIds: const {'home'},
            onDestinationSelected: (_) {},
            tabFor: (id) => Center(child: Text(id)),
            hideGlobalNav: true,
          ),
        ),
      ),
    );

    expect(find.byType(ShellNavRail), findsNothing);
  });

  test('navDestinations includes default shell tabs', () {
    expect(navDestinations.containsKey('home'), isTrue);
    expect(navDestinations.containsKey('search'), isTrue);
    expect(navDestinations.containsKey('mylist'), isTrue);
    expect(navDestinations.containsKey('settings'), isTrue);
    expect(SettingsService.defaultVisibleNavIds, ['home', 'search', 'mylist']);
  });
}
