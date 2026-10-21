import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/controls/chrome/player_chrome_overlays.dart';
import 'package:forja/shared/player/controls/chrome/player_status_roulette.dart';
import 'package:forja/shared/player/controls/tv/player_tv_key_scope.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shell/core/forja_shell_platform.dart';
import 'package:forja/shell/core/forja_shell_profile.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja_foundation/components/button.dart';
import 'package:forja_foundation/widgets/feedback/loading_state.dart';

/// Mirrors the Exo mount: controls chrome in its own `player-chrome` scope,
/// the status overlay as a sibling, both under [PlayerTvKeyScope] which
/// re-claims Play whenever focus is lost.
Widget _tvPlayer({
  required PlayerStatusController controller,
  required FocusNode keyFocus,
  required FocusNode play,
  bool playbackStarted = true,
  bool failed = false,
  VoidCallback? onRetry,
  VoidCallback? onBack,
  FocusNode? failedRetryFocusNode,
  VoidCallback? onFailedStageUp,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(size: Size(1920, 1080)),
      child: ShellScope(
        profile: ShellProfile.tv,
        config: shellPlatformConfigFor(ShellProfile.tv),
        child: Scaffold(
          backgroundColor: Colors.black,
          body: PlayerTvKeyScope(
            enabled: true,
            focusNode: keyFocus,
            showControls: true,
            onBack: () {},
            onPlayPause: () {},
            onShowControls: () {},
            onSeekBack: () {},
            onSeekForward: () {},
            onToggleControls: () {},
            onFocusBack: () {},
            onFocusPlay: play.requestFocus,
            // Same shape as the Exo screen's `_claimPlayFocus`.
            onClaimPlayFocus: () {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!play.canRequestFocus) return;
                if (playerChromeOverlayBlocksFocusClaim()) return;
                play.requestFocus();
              });
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                FocusScope(
                  debugLabel: 'player-chrome',
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: FocusableControl(
                      focusNode: play,
                      scaleOnFocus: 1.0,
                      onTap: () {},
                      child: const SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(Icons.play_arrow),
                      ),
                    ),
                  ),
                ),
                PlayerStatusOverlay(
                  controller: controller,
                  header: 'Checking sources',
                  playbackStarted: playbackStarted,
                  failed: failed,
                  tvFocusable: true,
                  onRetry: onRetry,
                  onBack: onBack,
                  failedRetryFocusNode: failedRetryFocusNode,
                  onFailedStageUp: onFailedStageUp,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('PlayerStatusOverlay — centered loading stage', () {
    testWidgets('before the first frame: centered indicator + source label', (
      tester,
    ) async {
      final controller = PlayerStatusController();
      addTearDown(controller.dispose);
      controller.upsert('source-0', 'Server A · English');
      final keyFocus = FocusNode(debugLabel: 'key');
      final play = FocusNode(debugLabel: 'play');
      addTearDown(keyFocus.dispose);
      addTearDown(play.dispose);

      await tester.pumpWidget(
        _tvPlayer(
          controller: controller,
          keyFocus: keyFocus,
          play: play,
          playbackStarted: false,
        ),
      );
      await tester.pump();

      expect(find.byType(ForjaLoadingState), findsOneWidget);
      expect(find.text('Checking sources'), findsWidgets);
      // Source label is painted both in the centered stage and the roulette.
      expect(find.text('Server A · English'), findsNWidgets(2));
      expect(find.byType(StatusRouletteView), findsOneWidget);
    });

    testWidgets('after the first frame only the right-side roulette stays', (
      tester,
    ) async {
      final controller = PlayerStatusController();
      addTearDown(controller.dispose);
      controller.upsert('source-0', 'Server A · English');
      final keyFocus = FocusNode(debugLabel: 'key');
      final play = FocusNode(debugLabel: 'play');
      addTearDown(keyFocus.dispose);
      addTearDown(play.dispose);

      await tester.pumpWidget(
        _tvPlayer(
          controller: controller,
          keyFocus: keyFocus,
          play: play,
          playbackStarted: true,
        ),
      );
      await tester.pump();

      expect(find.byType(ForjaLoadingState), findsNothing);
      expect(find.byType(StatusRouletteView), findsOneWidget);
    });

    testWidgets('centered loading does not take D-pad focus', (tester) async {
      final controller = PlayerStatusController();
      addTearDown(controller.dispose);
      controller.upsert('source-0', 'Server A');
      final keyFocus = FocusNode(debugLabel: 'key');
      final play = FocusNode(debugLabel: 'play');
      addTearDown(keyFocus.dispose);
      addTearDown(play.dispose);

      await tester.pumpWidget(
        _tvPlayer(
          controller: controller,
          keyFocus: keyFocus,
          play: play,
          playbackStarted: false,
        ),
      );
      // Indeterminate spinner never settles — pump a few frames instead.
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(play.hasFocus, isTrue);
      expect(find.byType(ForjaLoadingState), findsOneWidget);
    });
  });

  group('PlayerStatusOverlay — terminal failure stage (TV)', () {
    testWidgets('Retry takes focus even though the key scope re-claims Play', (
      tester,
    ) async {
      final controller = PlayerStatusController();
      addTearDown(controller.dispose);
      controller.upsert(
        'playback-failed',
        kPlayerStreamFailedLabel,
        kind: StatusRouletteKind.failed,
      );
      final keyFocus = FocusNode(debugLabel: 'key');
      final play = FocusNode(debugLabel: 'play');
      addTearDown(keyFocus.dispose);
      addTearDown(play.dispose);

      await tester.pumpWidget(
        _tvPlayer(
          controller: controller,
          keyFocus: keyFocus,
          play: play,
          failed: true,
          onRetry: () {},
          onBack: () {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(PlayerStreamFailedStage.retryLabel), findsOneWidget);
      expect(find.text(PlayerStreamFailedStage.backLabel), findsOneWidget);
      expect(find.text(kPlayerStreamFailedLabel), findsWidgets);
      expect(find.text('Press Back to leave'), findsOneWidget);

      final retry = find.ancestor(
        of: find.text(PlayerStreamFailedStage.retryLabel),
        matching: find.byType(FocusableControl),
      );
      expect(retry, findsOneWidget);
      expect(
        tester.widget<FocusableControl>(retry).focusNode!.hasFocus,
        isTrue,
        reason: 'Retry must own D-pad focus when the failure stage appears',
      );
      expect(play.hasFocus, isFalse);
    });

    testWidgets('→ moves to Back, ← returns to Retry, OK fires the action', (
      tester,
    ) async {
      final controller = PlayerStatusController();
      addTearDown(controller.dispose);
      controller.upsert(
        'playback-failed',
        kPlayerStreamFailedLabel,
        kind: StatusRouletteKind.failed,
      );
      final keyFocus = FocusNode(debugLabel: 'key');
      final play = FocusNode(debugLabel: 'play');
      addTearDown(keyFocus.dispose);
      addTearDown(play.dispose);
      var retries = 0;
      var backs = 0;

      await tester.pumpWidget(
        _tvPlayer(
          controller: controller,
          keyFocus: keyFocus,
          play: play,
          failed: true,
          onRetry: () => retries++,
          onBack: () => backs++,
        ),
      );
      await tester.pumpAndSettle();

      final retry = tester.widget<FocusableControl>(
        find.ancestor(
          of: find.text(PlayerStreamFailedStage.retryLabel),
          matching: find.byType(FocusableControl),
        ),
      );
      final back = tester.widget<FocusableControl>(
        find.ancestor(
          of: find.text(PlayerStreamFailedStage.backLabel),
          matching: find.byType(FocusableControl),
        ),
      );
      expect(retry.focusNode!.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(back.focusNode!.hasFocus, isTrue);
      expect(play.hasFocus, isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(retry.focusNode!.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(retries, 1);
      expect(backs, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(backs, 1);
    });

    testWidgets(
      'manual-switch abort: source title is the detail, never the title',
      (tester) async {
        final controller = PlayerStatusController();
        addTearDown(controller.dispose);
        // exo_player_sources abort paths upsert the failed row with the
        // source title.
        controller.upsert(
          'source-3',
          'Server A · English',
          kind: StatusRouletteKind.failed,
        );
        final keyFocus = FocusNode(debugLabel: 'key');
        final play = FocusNode(debugLabel: 'play');
        addTearDown(keyFocus.dispose);
        addTearDown(play.dispose);

        await tester.pumpWidget(
          _tvPlayer(
            controller: controller,
            keyFocus: keyFocus,
            play: play,
            failed: true,
            onRetry: () {},
            onBack: () {},
          ),
        );
        await tester.pumpAndSettle();

        final stage = tester.widget<ForjaLoadingState>(
          find.descendant(
            of: find.byType(PlayerStreamFailedStage),
            matching: find.byType(ForjaLoadingState),
          ),
        );
        expect(stage.title, kPlayerStreamFailedLabel);
        expect(stage.detail, 'Server A · English');
      },
    );

    testWidgets('host-owned Retry node lands focus; ↑ routes to the host', (
      tester,
    ) async {
      final controller = PlayerStatusController();
      addTearDown(controller.dispose);
      controller.upsert(
        'playback-failed',
        kPlayerStreamFailedLabel,
        kind: StatusRouletteKind.failed,
      );
      final keyFocus = FocusNode(debugLabel: 'key');
      final play = FocusNode(debugLabel: 'play');
      final hostRetry = FocusNode(debugLabel: 'host-retry');
      addTearDown(keyFocus.dispose);
      addTearDown(play.dispose);
      addTearDown(hostRetry.dispose);
      var ups = 0;

      await tester.pumpWidget(
        _tvPlayer(
          controller: controller,
          keyFocus: keyFocus,
          play: play,
          failed: true,
          onRetry: () {},
          onBack: () {},
          failedRetryFocusNode: hostRetry,
          onFailedStageUp: () => ups++,
        ),
      );
      await tester.pumpAndSettle();

      expect(hostRetry.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(ups, 1);

      // ↓ from the top bar: the host re-focuses the same node.
      hostRetry.requestFocus();
      await tester.pumpAndSettle();
      expect(hostRetry.hasFocus, isTrue);
    });

    testWidgets('failed without onRetry keeps today\'s roulette-only paint', (
      tester,
    ) async {
      final controller = PlayerStatusController();
      addTearDown(controller.dispose);
      controller.upsert(
        'playback-failed',
        kPlayerStreamFailedLabel,
        kind: StatusRouletteKind.failed,
      );
      final keyFocus = FocusNode(debugLabel: 'key');
      final play = FocusNode(debugLabel: 'play');
      addTearDown(keyFocus.dispose);
      addTearDown(play.dispose);

      await tester.pumpWidget(
        _tvPlayer(
          controller: controller,
          keyFocus: keyFocus,
          play: play,
          failed: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PlayerStreamFailedStage), findsNothing);
      expect(find.byType(StatusRouletteView), findsOneWidget);
    });
  });

  group('PlayerStatusOverlay — terminal failure stage (pointer)', () {
    testWidgets('Retry and Back are tappable buttons without TV focus', (
      tester,
    ) async {
      final controller = PlayerStatusController();
      addTearDown(controller.dispose);
      controller.upsert(
        'playback-failed',
        kPlayerStreamFailedLabel,
        kind: StatusRouletteKind.failed,
      );
      var retries = 0;
      var backs = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: ShellScope(
            profile: ShellProfile.mobile,
            config: shellPlatformConfigFor(ShellProfile.mobile),
            child: Scaffold(
              body: PlayerStatusOverlay(
                controller: controller,
                failed: true,
                onRetry: () => retries++,
                onBack: () => backs++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FocusableControl), findsNothing);
      expect(find.byType(Button), findsNWidgets(2));
      expect(find.text('Press Back to leave'), findsNothing);
      await tester.tap(find.text(PlayerStreamFailedStage.retryLabel));
      await tester.tap(find.text(PlayerStreamFailedStage.backLabel));
      expect(retries, 1);
      expect(backs, 1);
    });
  });
}
