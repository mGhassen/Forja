import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shell/bus/shell_bus.dart';
import 'package:forja/shell/routing/shell_overlay_navigator.dart';
import 'package:forja/shared/foundation/primitives/shell/forja_shell_profile.dart';
import 'package:forja/shared/foundation/primitives/shell/forja_shell_platform.dart';
import 'package:forja/shared/foundation/primitives/shell/forja_shell_scope.dart';
import 'package:forja/shared/player/controls/chrome/player_back_exit_gate.dart';
import 'package:forja/shared/foundation/tv/shell_tv_coordinator.dart';

void main() {
  setUp(() {
    ShellTvFocusCoordinator.tvBackPolicyEnabled = true;
    ShellTvFocusCoordinator.resetBackDebounceForTest();
    PlayerBackExitGate.resetForTest();
  });

  tearDown(() {
    ShellTvFocusCoordinator.resetBackDebounceForTest();
    ShellTvFocusCoordinator.tvBackPolicyEnabled = false;
    PlayerBackExitGate.resetForTest();
  });

  test('consumeChromeOrArmExit hides without arming, then arms, then exits', () {
    var chrome = true;
    var armed = false;
    var hidden = 0;

    expect(
      PlayerBackExitGate.consumeChromeOrArmExit(
        chromeVisible: chrome,
        armed: armed,
        hideChrome: () {
          hidden++;
          chrome = false;
        },
        setArmed: (v) => armed = v,
      ),
      isTrue,
    );
    expect(hidden, 1);
    expect(chrome, isFalse);
    expect(armed, isFalse);

    expect(
      PlayerBackExitGate.consumeChromeOrArmExit(
        chromeVisible: chrome,
        armed: armed,
        hideChrome: () => hidden++,
        setArmed: (v) => armed = v,
      ),
      isTrue,
    );
    expect(hidden, 1);
    expect(armed, isTrue);

    expect(
      PlayerBackExitGate.consumeChromeOrArmExit(
        chromeVisible: chrome,
        armed: armed,
        hideChrome: () => hidden++,
        setArmed: (v) => armed = v,
      ),
      isFalse,
    );
    expect(hidden, 1);
    expect(armed, isFalse);
  });

  test('consumeChromeOrArmExit arms when chrome already hidden', () {
    var armed = false;

    expect(
      PlayerBackExitGate.consumeChromeOrArmExit(
        chromeVisible: false,
        armed: armed,
        hideChrome: () {},
        setArmed: (v) => armed = v,
      ),
      isTrue,
    );
    expect(armed, isTrue);

    expect(
      PlayerBackExitGate.consumeChromeOrArmExit(
        chromeVisible: false,
        armed: armed,
        hideChrome: () {},
        setArmed: (v) => armed = v,
      ),
      isFalse,
    );
    expect(armed, isFalse);
  });

  testWidgets('TV Back: hide → arm → exit; twins do not skip steps', (
    tester,
  ) async {
    var chrome = true;
    var armed = false;
    PlayerBackExitGate.setTryFocusBack(() {
      return PlayerBackExitGate.consumeChromeOrArmExit(
        chromeVisible: chrome,
        armed: armed,
        hideChrome: () => chrome = false,
        setArmed: (v) => armed = v,
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1920, 1080)),
          child: ShellScope(
            profile: ShellProfile.tv,
            config: shellPlatformConfigFor(ShellProfile.tv),
            child: const Stack(
              children: [
                SizedBox.expand(),
                ShellOverlayNavigator(),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Navigator.of(
      shellOverlayNavigatorKey.currentContext!,
      rootNavigator: true,
    ).push(
      MaterialPageRoute<void>(
        builder: (_) => const _FakePlayerRoute(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('player-body'), findsOneWidget);

    // 1) Hide chrome (not armed).
    expect(ShellTvFocusCoordinator.handleShellBackKey(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('player-body'), findsOneWidget);
    expect(chrome, isFalse);
    expect(armed, isFalse);

    // Twin under load must not arm/exit on the same physical press.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    expect(ShellTvFocusCoordinator.handleShellBackKey(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('player-body'), findsOneWidget);
    expect(chrome, isFalse);
    expect(armed, isFalse);

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 450)),
    );

    // 2) Arm while chrome already hidden.
    expect(ShellTvFocusCoordinator.handleShellBackKey(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('player-body'), findsOneWidget);
    expect(armed, isTrue);

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    expect(ShellTvFocusCoordinator.handleShellBackKey(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('player-body'), findsOneWidget);
    expect(armed, isTrue);

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 450)),
    );

    // 3) Confirm exit.
    expect(ShellTvFocusCoordinator.handleShellBackKey(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('player-body'), findsNothing);
  });

  test('tryFocusBackStay twin stays; later press exits', () async {
    ShellBus.enterPlayerSurface();
    addTearDown(ShellBus.leavePlayerSurface);

    var focused = false;
    PlayerBackExitGate.setTryFocusBack(() {
      if (focused) return false;
      focused = true;
      return true;
    });

    expect(PlayerBackExitGate.tryFocusBackStay(), isTrue);
    expect(PlayerBackExitGate.exitReady, isFalse);
    expect(focused, isTrue);
    // Same-press popRoute twin must not exit (including late twins).
    expect(PlayerBackExitGate.tryFocusBackStay(), isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(PlayerBackExitGate.tryFocusBackStay(), isTrue);

    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(PlayerBackExitGate.tryFocusBackStay(), isFalse);
  });

  test('markStay swallows armed exit on the overlay-dismiss twin', () async {
    ShellBus.enterPlayerSurface();
    addTearDown(ShellBus.leavePlayerSurface);

    var chrome = false;
    var armed = true;
    PlayerBackExitGate.setTryFocusBack(() {
      return PlayerBackExitGate.consumeChromeOrArmExit(
        chromeVisible: chrome,
        armed: armed,
        hideChrome: () => chrome = false,
        setArmed: (v) => armed = v,
      );
    });

    PlayerBackExitGate.markStay();
    expect(PlayerBackExitGate.tryFocusBackStay(), isTrue);
    expect(armed, isTrue);
  });
}

class _FakePlayerRoute extends StatefulWidget {
  const _FakePlayerRoute();

  @override
  State<_FakePlayerRoute> createState() => _FakePlayerRouteState();
}

class _FakePlayerRouteState extends State<_FakePlayerRoute> {
  @override
  void initState() {
    super.initState();
    ShellBus.enterPlayerSurface();
  }

  @override
  void dispose() {
    ShellBus.leavePlayerSurface();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('player-body')));
  }
}
