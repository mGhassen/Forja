import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shell/shell_nav_rail.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/theme/app_theme.dart';

Widget _wrapProfile({
  required ShellProfile profile,
  required Widget child,
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

/// Same FittedBox gate as [HomeScreen._buildHeroActionRow].
Widget _heroActionRowHarness(BuildContext context) {
  final metrics = ShellScope.metricsOf(context);
  const row = Row(
    mainAxisSize: MainAxisSize.min,
    children: [SizedBox(width: 120, height: 40)],
  );
  if (metrics.heroActionUseFittedBox) {
    return const FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: row,
    );
  }
  return row;
}

/// Same mood-chip focus gate as [_MoodSection] in home_screen.dart.
Widget _moodChipHarness(BuildContext context) {
  const chip = Text('Action');
  if (ShellScope.inputPolicyOf(context).useFocusableMoodChips) {
    return FocusableControl(onTap: () {}, borderRadius: 24, child: chip);
  }
  return Material(
    color: Colors.transparent,
    child: InkWell(onTap: () {}, child: chip),
  );
}

Future<void> _focusNavItem(WidgetTester tester, String id) async {
  final focusFinder = find.byWidgetPredicate(
    (w) => w is Focus && w.debugLabel == 'nav-$id',
  );
  expect(focusFinder, findsOneWidget);
  final childFinder = find.descendant(
    of: focusFinder,
    matching: find.byType(GestureDetector),
  );
  expect(childFinder, findsOneWidget);
  final childElement = tester.element(childFinder);
  FocusScope.of(childElement).requestFocus(Focus.of(childElement));
  await tester.pumpAndSettle();
}

AnimatedScale _navItemScale(WidgetTester tester, String id) {
  final focusFinder = find.byWidgetPredicate(
    (w) => w is Focus && w.debugLabel == 'nav-$id',
  );
  final scaleFinder = find.descendant(
    of: focusFinder,
    matching: find.byType(AnimatedScale),
  );
  expect(scaleFinder, findsOneWidget);
  return tester.widget<AnimatedScale>(scaleFinder);
}

bool _navItemHasFocusRing(WidgetTester tester, String id) {
  final focusFinder = find.byWidgetPredicate(
    (w) => w is Focus && w.debugLabel == 'nav-$id',
  );
  for (final element
      in find.descendant(of: focusFinder, matching: find.byType(DecoratedBox)).evaluate()) {
    final decoration = (element.widget as DecoratedBox).decoration;
    if (decoration is BoxDecoration &&
        decoration.boxShadow != null &&
        decoration.boxShadow!.isNotEmpty) {
      return true;
    }
  }
  return false;
}

void main() {
  testWidgets('desktop hero action row has no FittedBox (R28-A08)', (tester) async {
    await tester.pumpWidget(
      _wrapProfile(
        profile: ShellProfile.desktop,
        child: Builder(builder: _heroActionRowHarness),
      ),
    );

    expect(find.byType(FittedBox), findsNothing);
  });

  testWidgets('tv hero action row wraps actions in FittedBox (R28-A09)', (tester) async {
    await tester.pumpWidget(
      _wrapProfile(
        profile: ShellProfile.tv,
        child: Builder(builder: _heroActionRowHarness),
      ),
    );

    expect(find.byType(FittedBox), findsOneWidget);
  });

  testWidgets('desktop nav rail scales on hover not keyboard focus (R28-A08)', (tester) async {
    await tester.pumpWidget(
      _wrapProfile(
        profile: ShellProfile.desktop,
        child: ShellNavRail(
          visibleIds: const ['home', 'search', 'settings'],
          selectedIndex: 0,
          onDestinationSelected: (_) {},
        ),
      ),
    );

    await _focusNavItem(tester, 'search');
    expect(_navItemScale(tester, 'search').scale, 1.0);
    expect(_navItemHasFocusRing(tester, 'search'), isFalse);

    final searchIcon =
        find.image(const AssetImage('assets/images/nav/search.png'));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(searchIcon));
    await tester.pumpAndSettle();

    expect(
      _navItemScale(tester, 'search').scale,
      ShellTokens.navRailIconHoverScale,
    );
  });

  testWidgets('tv nav rail scales and shows focus ring on keyboard focus (R28-A09)',
      (tester) async {
    await tester.pumpWidget(
      _wrapProfile(
        profile: ShellProfile.tv,
        child: ShellNavRail(
          visibleIds: const ['home', 'search', 'settings'],
          selectedIndex: 0,
          onDestinationSelected: (_) {},
        ),
      ),
    );

    await _focusNavItem(tester, 'search');
    expect(
      _navItemScale(tester, 'search').scale,
      ShellTokens.navRailIconHoverScale,
    );
    expect(_navItemHasFocusRing(tester, 'search'), isTrue);
  });

  testWidgets('tv mood chips use FocusableControl; desktop uses InkWell (R28-A09/A08)',
      (tester) async {
    await tester.pumpWidget(
      _wrapProfile(
        profile: ShellProfile.desktop,
        child: Builder(builder: _moodChipHarness),
      ),
    );
    expect(find.byType(FocusableControl), findsNothing);
    expect(find.byType(InkWell), findsOneWidget);

    await tester.pumpWidget(
      _wrapProfile(
        profile: ShellProfile.tv,
        child: Builder(builder: _moodChipHarness),
      ),
    );
    expect(find.byType(FocusableControl), findsOneWidget);
    expect(find.byType(InkWell), findsNothing);
  });

  test('maybeWrapFocusTraversal only wraps when enabled (R28-A10)', () {
    const child = Text('app');

    final plain = ShellInputPolicy.maybeWrapFocusTraversal(
      enabled: false,
      child: child,
    );
    expect(plain, same(child));

    final wrapped = ShellInputPolicy.maybeWrapFocusTraversal(
      enabled: true,
      child: child,
    );
    expect(wrapped, isA<Shortcuts>());
  });
}
