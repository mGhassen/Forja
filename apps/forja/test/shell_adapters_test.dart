import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shell/adapters/shell_host.dart';
import 'package:forja/shell/nav/shell_bottom_nav.dart';
import 'package:forja/shell/nav/shell_nav_rail.dart';
import 'package:forja/shell/core/forja_shell_profile.dart';
import 'package:forja/shell/core/forja_shell_platform.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';

Widget _wrapShellHost({
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

ShellHost _host() {
  return ShellHost(
    visibleIds: const ['home', 'search', 'settings'],
    selectedIndex: 0,
    mountedTabIds: const {'home'},
    onDestinationSelected: (_) {},
    tabFor: (id) => Center(child: Text(id)),
  );
}

void main() {
  testWidgets('ShellHost uses bottom nav for mobile profile', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrapShellHost(
        profile: ShellProfile.mobile,
        size: const Size(400, 800),
        child: _host(),
      ),
    );

    expect(find.byType(ShellBottomNav), findsOneWidget);
    expect(find.byType(ShellNavRail), findsNothing);
  });

  testWidgets('mobile profile keeps bottom nav on a landscape phone',
      (tester) async {
    const phoneLandscape = Size(915, 412);
    await tester.binding.setSurfaceSize(phoneLandscape);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrapShellHost(
        profile: ShellProfile.mobile,
        size: phoneLandscape,
        child: _host(),
      ),
    );

    expect(find.byType(ShellBottomNav), findsOneWidget);
    expect(find.byType(ShellNavRail), findsNothing);
  });

  testWidgets('mobile profile uses nav rail on a landscape tablet',
      (tester) async {
    const tabletLandscape = Size(1280, 800);
    await tester.binding.setSurfaceSize(tabletLandscape);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrapShellHost(
        profile: ShellProfile.mobile,
        size: tabletLandscape,
        child: _host(),
      ),
    );

    expect(find.byType(ShellNavRail), findsOneWidget);
    expect(find.byType(ShellBottomNav), findsNothing);
  });

  testWidgets('ShellHost uses nav rail for desktop profile', (tester) async {
    await tester.pumpWidget(
      _wrapShellHost(
        profile: ShellProfile.desktop,
        child: _host(),
      ),
    );

    expect(find.byType(ShellNavRail), findsOneWidget);
    expect(find.byType(ShellBottomNav), findsNothing);
  });

  testWidgets('ShellHost uses nav rail for tv profile', (tester) async {
    await tester.pumpWidget(
      _wrapShellHost(
        profile: ShellProfile.tv,
        child: _host(),
      ),
    );

    expect(find.byType(ShellNavRail), findsOneWidget);
    expect(find.byType(ShellBottomNav), findsNothing);
  });

  testWidgets('TV profile keeps nav rail on narrow logical width (1080p DPR)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrapShellHost(
        profile: ShellProfile.tv,
        size: const Size(900, 800),
        child: _host(),
      ),
    );

    expect(find.byType(ShellNavRail), findsOneWidget);
    expect(find.byType(ShellNavMenuButton), findsNothing);
  });
}
