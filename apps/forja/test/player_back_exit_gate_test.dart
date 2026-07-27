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

  testWidgets('TV Back focuses player Back before exiting', (tester) async {
    var backFocused = false;
    PlayerBackExitGate.setTryFocusBack(() {
      if (backFocused) return false;
      backFocused = true;
      return true;
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

    shellOverlayNavigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const _FakePlayerRoute(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('player-body'), findsOneWidget);

    // First Back focuses Back control - stays in player.
    expect(ShellTvFocusCoordinator.handleShellBackKey(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('player-body'), findsOneWidget);
    expect(backFocused, isTrue);

    await tester.pump(const Duration(milliseconds: 450));

    // Second Back (Back already focused) exits.
    expect(ShellTvFocusCoordinator.handleShellBackKey(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('player-body'), findsNothing);
  });

  test('tryFocusBackStay stays then allows exit', () {
    ShellBus.enterPlayerSurface();
    addTearDown(ShellBus.leavePlayerSurface);

    var focused = false;
    PlayerBackExitGate.setTryFocusBack(() {
      if (focused) return false;
      focused = true;
      return true;
    });

    expect(PlayerBackExitGate.tryFocusBackStay(), isTrue);
    expect(focused, isTrue);
    expect(PlayerBackExitGate.tryFocusBackStay(), isFalse);
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
