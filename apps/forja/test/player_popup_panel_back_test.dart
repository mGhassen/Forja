import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/player/controls/player_back_exit_gate.dart';
import 'package:forja/shared/player/controls/player_chrome_overlays.dart';
import 'package:forja/shared/player/controls/player_popup_panel.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';

void main() {
  tearDown(() {
    PlayerPopupPanel.dismiss();
    ShellTvFocusCoordinator.resetBackDebounceForTest();
    ShellTvFocusCoordinator.tvBackPolicyEnabled = false;
  });

  testWidgets('popLayerOrDismiss reopens parent drill-in on Back', (tester) async {
    var rootOpens = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ShellScope(
          profile: ShellProfile.tv,
          config: shellPlatformConfigFor(ShellProfile.tv),
          child: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      PlayerPopupPanel.show(
                        context: context,
                        title: 'Speed',
                        onBack: () {
                          rootOpens++;
                          PlayerPopupPanel.show(
                            context: context,
                            title: 'Settings',
                            child: const Text('settings-body'),
                          );
                        },
                        child: const Text('speed-body'),
                      );
                    },
                    child: const Text('open'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('speed-body'), findsOneWidget);
    expect(PlayerPopupPanel.isShowing, isTrue);

    expect(PlayerPopupPanel.popLayerOrDismiss(), isTrue);
    await tester.pumpAndSettle();
    expect(rootOpens, 1);
    expect(find.text('settings-body'), findsOneWidget);
    expect(find.text('speed-body'), findsNothing);

    expect(dismissAnyPlayerChromeOverlay(), isTrue);
    await tester.pumpAndSettle();
    expect(PlayerPopupPanel.isShowing, isFalse);
    expect(find.text('settings-body'), findsNothing);
  });

  testWidgets(
    'Back dismisses stats overlay only — does not pop player (exitReady armed)',
    (tester) async {
      ShellTvFocusCoordinator.tvBackPolicyEnabled = true;
      ShellTvFocusCoordinator.resetBackDebounceForTest();
      ShellBus.enterPlayerSurface();
      addTearDown(ShellBus.leavePlayerSurface);

      var exitCalls = 0;
      PlayerBackExitGate.setTryFocusBack(() {
        exitCalls++;
        return false;
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
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  PlayerPopupPanel.show(
                    context: context,
                    title: 'Stream stats',
                    autofocusClose: true,
                    child: const Text('stats-body'),
                  );
                },
                child: const Text('open-stats'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('open-stats'));
      await tester.pumpAndSettle();
      expect(find.text('stats-body'), findsOneWidget);
      expect(PlayerPopupPanel.isShowing, isTrue);

      // Simulate armed exit from an earlier Back (debounce would have been
      // skipped before the overlay-first fix).
      PlayerBackExitGate.exitReady = true;

      expect(ShellTvFocusCoordinator.handleShellBackKey(), isTrue);
      await tester.pumpAndSettle();
      expect(find.text('stats-body'), findsNothing);
      expect(PlayerPopupPanel.isShowing, isFalse);
      expect(find.text('open-stats'), findsOneWidget);

      // Same-press duplicate (didPopRoute) must not run the exit ladder.
      expect(ShellTvFocusCoordinator.handleShellBackKey(), isTrue);
      await tester.pumpAndSettle();
      expect(exitCalls, 0);
      expect(find.text('open-stats'), findsOneWidget);
      expect(PlayerBackExitGate.exitReady, isFalse);
    },
  );

  testWidgets(
    'handleShellBackKey dismisses popup while shell overlay is open',
    (tester) async {
      ShellTvFocusCoordinator.tvBackPolicyEnabled = true;
      ShellTvFocusCoordinator.resetBackDebounceForTest();

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
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  PlayerPopupPanel.show(
                    context: context,
                    title: 'Player',
                    child: const Text('menu-body'),
                  );
                },
                child: const Text('open-menu'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('open-menu'), findsOneWidget);

      await tester.tap(find.text('open-menu'));
      await tester.pumpAndSettle();
      expect(find.text('menu-body'), findsOneWidget);
      expect(shellOverlayCanPop(), isTrue);

      // Overlay can pop (would be level=detail) - Back must close menu first.
      expect(ShellTvFocusCoordinator.handleShellBackKey(), isTrue);
      await tester.pumpAndSettle();
      expect(find.text('menu-body'), findsNothing);
      expect(find.text('open-menu'), findsOneWidget);
      expect(shellOverlayCanPop(), isTrue);
    },
  );

  testWidgets(
    'Back closes player showDialog without popping the player',
    (tester) async {
      ShellTvFocusCoordinator.tvBackPolicyEnabled = true;
      ShellTvFocusCoordinator.resetBackDebounceForTest();
      ShellBus.enterPlayerSurface();
      addTearDown(ShellBus.leavePlayerSurface);

      var exitCalls = 0;
      PlayerBackExitGate.setTryFocusBack(() {
        exitCalls++;
        return false;
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
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('torrent-dialog'),
                      actions: [
                        TextButton(
                          autofocus: true,
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('open-dialog'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('open-dialog'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('torrent-dialog'), findsOneWidget);

      expect(ShellTvFocusCoordinator.handleShellBackKey(), isTrue);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('torrent-dialog'), findsNothing);
      expect(find.text('open-dialog'), findsOneWidget);
      expect(exitCalls, 0);

      expect(ShellTvFocusCoordinator.handleShellBackKey(), isTrue);
      await tester.pump();
      expect(find.text('open-dialog'), findsOneWidget);
      expect(exitCalls, 0);
    },
  );
}
