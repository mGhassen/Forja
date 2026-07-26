import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/player/controls/player_back_exit_gate.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';

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

  testWidgets('TV Back requires two presses to leave a player surface',
      (tester) async {
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

    shellOverlayNavigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const _FakePlayerRoute(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('player-body'), findsOneWidget);
    expect(ShellBus.playerSurfaceActive.value, isTrue);

    // First Back arms exit - stays in player.
    expect(ShellTvFocusCoordinator.handleShellBackKey(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('player-body'), findsOneWidget);
    expect(PlayerBackExitGate.isArmed, isTrue);

    // Past debounce so the confirming Back is not swallowed.
    await tester.pump(const Duration(milliseconds: 450));

    // Second Back exits.
    expect(ShellTvFocusCoordinator.handleShellBackKey(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('player-body'), findsNothing);
  });

  test('consumeFirstBackStay arms then allows exit', () {
    ShellBus.enterPlayerSurface();
    addTearDown(ShellBus.leavePlayerSurface);

    expect(
      PlayerBackExitGate.consumeFirstBackStay(enabled: true),
      isTrue,
    );
    expect(PlayerBackExitGate.isArmed, isTrue);

    expect(
      PlayerBackExitGate.consumeFirstBackStay(enabled: true),
      isFalse,
    );
    expect(PlayerBackExitGate.isArmed, isFalse);
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
