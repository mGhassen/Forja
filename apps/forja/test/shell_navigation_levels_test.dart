import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/navigation/shell_navigation_levels.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';

void main() {
  testWidgets('resolveBackTarget prefers player over detail overlay', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (outerContext) {
            return Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (innerContext) {
                  return const Stack(
                    children: [
                      SizedBox.expand(),
                      ShellOverlayNavigator(),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final rootNav = shellOverlayNavigatorKey.currentContext!
        .findRootAncestorStateOfType<NavigatorState>()!;
    rootNav.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Player')),
      ),
    );
    shellOverlayNavigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Details')),
      ),
    );
    await tester.pumpAndSettle();

    expect(ShellNavigationLevels.resolveBackTarget(), ShellNavLevel.player);
  });

  testWidgets('resolveBackTarget reports menu when nav focused', (tester) async {
    final nav = FocusNode(debugLabel: 'nav-home');
    ShellTvFocus.registerNav('home', nav);
    addTearDown(() => ShellTvFocus.unregisterNav('home', nav));

    await tester.pumpWidget(
      MaterialApp(
        home: Focus(
          autofocus: true,
          focusNode: nav,
          child: const SizedBox(width: 40, height: 40),
        ),
      ),
    );
    await tester.pump();

    expect(ShellNavigationLevels.resolveBackTarget(), ShellNavLevel.menu);

    nav.dispose();
  });
}
