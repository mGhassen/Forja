import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shell/bus/shell_bus.dart';
import 'package:forja/shell/routing/shell_overlay_navigator.dart';
import 'package:forja/shell/core/forja_shell_profile.dart';
import 'package:forja/shell/core/forja_shell_platform.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shared/player/controls/chrome/player_back_exit_gate.dart';
import 'package:forja/shell/tv/shell_tv_coordinator.dart';

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

  test('consumeChromeOrExit: media not started → one Back exits', () {
    var hidden = 0;
    // Chrome up or down makes no difference before the first frame.
    expect(
      PlayerBackExitGate.consumeChromeOrExit(
        chromeVisible: true,
        mediaStarted: false,
        hideChrome: () => hidden++,
      ),
      isFalse,
    );
    expect(
      PlayerBackExitGate.consumeChromeOrExit(
        chromeVisible: false,
        mediaStarted: false,
        hideChrome: () => hidden++,
      ),
      isFalse,
    );
    expect(hidden, 0);
  });

  test('consumeChromeOrExit: started once, re-buffering → hide, arm, exit', () {
    // Surfaces pass a session-level flag: a zap / source switch re-buffer
    // after the first frame is still "started".
    var startedOnce = false;
    var framesFlowing = false;
    void frame() {
      framesFlowing = true;
      startedOnce = true;
    }

    frame();
    framesFlowing = false; // zap: per-source flag reset, session flag kept
    var chrome = true;
    var armed = false;
    expect(
      PlayerBackExitGate.consumeChromeOrExit(
        chromeVisible: chrome,
        mediaStarted: startedOnce,
        hideChrome: () => chrome = false,
        exitArmed: armed,
        armExit: () => armed = true,
      ),
      isTrue,
    );
    expect(framesFlowing, isFalse);
    expect(
      PlayerBackExitGate.consumeChromeOrExit(
        chromeVisible: chrome,
        mediaStarted: startedOnce,
        hideChrome: () {},
        exitArmed: armed,
        armExit: () => armed = true,
      ),
      isTrue,
    );
    expect(armed, isTrue);
    expect(
      PlayerBackExitGate.consumeChromeOrExit(
        chromeVisible: chrome,
        mediaStarted: startedOnce,
        hideChrome: () {},
        exitArmed: armed,
        armExit: () => armed = true,
      ),
      isFalse,
    );
  });

  test(
    'consumeChromeOrExit: terminal failure after playback → one Back exits',
    () {
      const startedOnce = true;
      const terminalFailure = true;
      var hidden = 0;
      expect(
        PlayerBackExitGate.consumeChromeOrExit(
          chromeVisible: true,
          mediaStarted: startedOnce && !terminalFailure,
          hideChrome: () => hidden++,
        ),
        isFalse,
      );
      expect(hidden, 0);
    },
  );

  test('consumeChromeOrExit: playing → hide, arm, then exit', () {
    var chrome = true;
    var hidden = 0;
    var armed = false;

    expect(
      PlayerBackExitGate.consumeChromeOrExit(
        chromeVisible: chrome,
        mediaStarted: true,
        hideChrome: () {
          hidden++;
          chrome = false;
        },
        exitArmed: armed,
        armExit: () => armed = true,
      ),
      isTrue,
    );
    expect(hidden, 1);
    expect(chrome, isFalse);
    expect(armed, isFalse);

    expect(
      PlayerBackExitGate.consumeChromeOrExit(
        chromeVisible: chrome,
        mediaStarted: true,
        hideChrome: () => hidden++,
        exitArmed: armed,
        armExit: () => armed = true,
      ),
      isTrue,
    );
    expect(armed, isTrue);
    expect(hidden, 1);

    expect(
      PlayerBackExitGate.consumeChromeOrExit(
        chromeVisible: chrome,
        mediaStarted: true,
        hideChrome: () => hidden++,
        exitArmed: armed,
        armExit: () => armed = true,
      ),
      isFalse,
    );
    expect(hidden, 1);
  });

  test('consumeChromeOrExit: without armExit stays hide-then-leave', () {
    var chrome = true;
    expect(
      PlayerBackExitGate.consumeChromeOrExit(
        chromeVisible: chrome,
        mediaStarted: true,
        hideChrome: () => chrome = false,
      ),
      isTrue,
    );
    expect(
      PlayerBackExitGate.consumeChromeOrExit(
        chromeVisible: chrome,
        mediaStarted: true,
        hideChrome: () {},
      ),
      isFalse,
    );
  });

  testWidgets('TV Back while loading: single press exits the player', (
    tester,
  ) async {
    var chrome = true;
    PlayerBackExitGate.setTryFocusBack(() {
      return PlayerBackExitGate.consumeChromeOrExit(
        chromeVisible: chrome,
        mediaStarted: false,
        hideChrome: () => chrome = false,
      );
    });

    await _pumpShell(tester);
    await _pushFakePlayer(tester);
    expect(find.text('player-body'), findsOneWidget);

    expect(ShellTvFocusCoordinator.handleShellBackKey(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('player-body'), findsNothing);
    // Chrome was not touched — the press left, it did not hide.
    expect(chrome, isTrue);
  });

  testWidgets('TV Back while playing: hide → arm → exit; twins stay', (
    tester,
  ) async {
    var chrome = true;
    var armed = false;
    PlayerBackExitGate.setTryFocusBack(() {
      return PlayerBackExitGate.consumeChromeOrExit(
        chromeVisible: chrome,
        mediaStarted: true,
        hideChrome: () {
          chrome = false;
          armed = false;
        },
        exitArmed: armed,
        armExit: () => armed = true,
      );
    });

    await _pumpShell(tester);
    await _pushFakePlayer(tester);
    expect(find.text('player-body'), findsOneWidget);

    // 1) Hide chrome.
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
    expect(armed, isFalse);

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 450)),
    );

    // 2) Chrome hidden → arm exit hint.
    expect(ShellTvFocusCoordinator.handleShellBackKey(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('player-body'), findsOneWidget);
    expect(armed, isTrue);

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 450)),
    );

    // 3) Armed → leave.
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

  test('markStay swallows the exit on the overlay-dismiss twin', () async {
    ShellBus.enterPlayerSurface();
    addTearDown(ShellBus.leavePlayerSurface);

    var exitAsked = 0;
    PlayerBackExitGate.setTryFocusBack(() {
      exitAsked++;
      // Chrome already hidden while playing → would exit.
      return PlayerBackExitGate.consumeChromeOrExit(
        chromeVisible: false,
        mediaStarted: true,
        hideChrome: () {},
      );
    });

    PlayerBackExitGate.markStay();
    expect(PlayerBackExitGate.tryFocusBackStay(), isTrue);
    expect(exitAsked, 0);
  });
}

Future<void> _pumpShell(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(1920, 1080)),
        child: ShellScope(
          profile: ShellProfile.tv,
          config: shellPlatformConfigFor(ShellProfile.tv),
          child: const Stack(
            children: [SizedBox.expand(), ShellOverlayNavigator()],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pushFakePlayer(WidgetTester tester) async {
  Navigator.of(
    shellOverlayNavigatorKey.currentContext!,
    rootNavigator: true,
  ).push(MaterialPageRoute<void>(builder: (_) => const _FakePlayerRoute()));
  await tester.pumpAndSettle();
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
