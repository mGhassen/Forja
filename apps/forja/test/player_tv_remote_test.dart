import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/player/controls/player_chrome_overlay.dart';
import 'package:forja/shared/player/controls/player_tv_key_scope.dart';
import 'package:forja/shared/player/controls/player_tv_remote.dart';
import 'package:forja/shared/theme/app_theme.dart';

PlayerTvRemoteKeyHandler _handler({
  VoidCallback? onBack,
  VoidCallback? onPlayPause,
  VoidCallback? onShowControls,
  VoidCallback? onSeekBack,
  VoidCallback? onSeekForward,
  VoidCallback? onVolumeUp,
  VoidCallback? onVolumeDown,
  VoidCallback? onToggleControls,
  VoidCallback? onFocusBack,
  VoidCallback? onFocusPlay,
}) {
  return PlayerTvRemoteKeyHandler(
    onBack: onBack ?? () {},
    onPlayPause: onPlayPause ?? () {},
    onShowControls: onShowControls ?? () {},
    onSeekBack: onSeekBack ?? () {},
    onSeekForward: onSeekForward ?? () {},
    onVolumeUp: onVolumeUp ?? () {},
    onVolumeDown: onVolumeDown ?? () {},
    onToggleControls: onToggleControls ?? () {},
    onFocusBack: onFocusBack ?? () {},
    onFocusPlay: onFocusPlay ?? () {},
  );
}

KeyDownEvent _key(LogicalKeyboardKey key) {
  return KeyDownEvent(
    physicalKey: PhysicalKeyboardKey(0),
    logicalKey: key,
    timeStamp: Duration.zero,
  );
}

void main() {
  group('PlayerTvRemoteKeyHandler', () {
    test('back key invokes onBack', () {
      var back = 0;
      final handler = _handler(onBack: () => back++);

      final handled = handler.handle(
        _key(LogicalKeyboardKey.goBack),
        showControls: true,
      );

      expect(handled, isTrue);
      expect(back, 1);
    });

    test('select toggles play/pause when controls visible', () {
      var playPause = 0;
      final handler = _handler(onPlayPause: () => playPause++);

      final handled = handler.handle(
        _key(LogicalKeyboardKey.select),
        showControls: true,
      );

      expect(handled, isTrue);
      expect(playPause, 1);
    });

    test('menu key toggles controls', () {
      var toggled = 0;
      final handler = _handler(onToggleControls: () => toggled++);

      final handled = handler.handle(
        _key(LogicalKeyboardKey.contextMenu),
        showControls: false,
      );

      expect(handled, isTrue);
      expect(toggled, 1);
    });

    test('hardware volume keys always adjust volume', () {
      var up = 0;
      var down = 0;
      final handler = _handler(
        onVolumeUp: () => up++,
        onVolumeDown: () => down++,
      );

      expect(
        handler.handle(_key(LogicalKeyboardKey.audioVolumeUp), showControls: true),
        isTrue,
      );
      expect(
        handler.handle(
          _key(LogicalKeyboardKey.audioVolumeDown),
          showControls: true,
        ),
        isTrue,
      );
      expect(up, 1);
      expect(down, 1);
    });

    test('arrow left/right seek when chrome is hidden', () {
      var back = 0;
      var forward = 0;
      final handler = _handler(
        onSeekBack: () => back++,
        onSeekForward: () => forward++,
      );

      expect(
        handler.handle(_key(LogicalKeyboardKey.arrowLeft), showControls: false),
        isTrue,
      );
      expect(
        handler.handle(_key(LogicalKeyboardKey.arrowRight), showControls: false),
        isTrue,
      );
      expect(back, 1);
      expect(forward, 1);
    });

    test('arrow left/right always seek when handler runs', () {
      var back = 0;
      var forward = 0;
      final handler = _handler(
        onSeekBack: () => back++,
        onSeekForward: () => forward++,
      );

      expect(
        handler.handle(_key(LogicalKeyboardKey.arrowLeft), showControls: true),
        isTrue,
      );
      expect(
        handler.handle(_key(LogicalKeyboardKey.arrowRight), showControls: true),
        isTrue,
      );
      expect(back, 1);
      expect(forward, 1);
    });

    test('arrow up focuses back when chrome is hidden', () {
      var focusBack = 0;
      var volumeUp = 0;
      final handler = _handler(
        onFocusBack: () => focusBack++,
        onVolumeUp: () => volumeUp++,
      );

      expect(
        handler.handle(_key(LogicalKeyboardKey.arrowUp), showControls: false),
        isTrue,
      );
      expect(focusBack, 1);
      expect(volumeUp, 0);
    });

    test('arrow down focuses play when chrome is hidden', () {
      var focusPlay = 0;
      var volumeDown = 0;
      final handler = _handler(
        onFocusPlay: () => focusPlay++,
        onVolumeDown: () => volumeDown++,
      );

      expect(
        handler.handle(_key(LogicalKeyboardKey.arrowDown), showControls: false),
        isTrue,
      );
      expect(focusPlay, 1);
      expect(volumeDown, 0);
    });

    test('arrow up/down focus back/play even when chrome is visible', () {
      var focusBack = 0;
      var focusPlay = 0;
      final handler = _handler(
        onFocusBack: () => focusBack++,
        onFocusPlay: () => focusPlay++,
      );

      expect(
        handler.handle(_key(LogicalKeyboardKey.arrowUp), showControls: true),
        isTrue,
      );
      expect(
        handler.handle(_key(LogicalKeyboardKey.arrowDown), showControls: true),
        isTrue,
      );
      expect(focusBack, 1);
      expect(focusPlay, 1);
    });
  });

  testWidgets('tvFocusable chrome buttons expose FocusableControl', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayerFlatIconButton(
            icon: Icons.play_arrow_rounded,
            onPressed: () {},
            tvFocusable: true,
          ),
        ),
      ),
    );

    expect(find.byType(FocusableControl), findsOneWidget);
  });

  testWidgets('PlayerTvKeyScope seeks left/right when chrome is hidden', (
    tester,
  ) async {
    final keyFocus = FocusNode(debugLabel: 'test-player-tv-keys');
    final playFocus = FocusNode(debugLabel: 'test-play');
    var seekBack = 0;
    var seekForward = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayerTvKeyScope(
            enabled: true,
            focusNode: keyFocus,
            showControls: false,
            onBack: () {},
            onPlayPause: () {},
            onShowControls: () {},
            onSeekBack: () => seekBack++,
            onSeekForward: () => seekForward++,
            onVolumeUp: () {},
            onVolumeDown: () {},
            onToggleControls: () {},
            onFocusBack: () {},
            onFocusPlay: () {},
            child: FocusScope(
              debugLabel: 'player-chrome',
              child: Focus(
                focusNode: playFocus,
                child: const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(keyFocus.hasFocus, isTrue);
    expect(playFocus.hasFocus, isFalse);
    expect(playFocus.canRequestFocus, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(seekBack, 1);
    expect(seekForward, 1);

    keyFocus.dispose();
    playFocus.dispose();
  });

  testWidgets(
    'FocusableControl arrow moves focus inside full-screen player chrome scope',
    (tester) async {
      // Mirrors Exo/IPTV chrome: FocusScope expands to the full screen.
      // focusInDirection on the *scope* finds no neighbors (scope rect is the
      // whole display); the focused control node must drive traversal.
      final play = FocusNode(debugLabel: 'exo-player-play');
      final rewind = FocusNode(debugLabel: 'exo-player-rewind');

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1920, 1080)),
            child: ShellScope(
              profile: ShellProfile.tv,
              config: shellPlatformConfigFor(ShellProfile.tv),
              child: ShellInputPolicy.maybeWrapFocusTraversal(
                enabled: true,
                child: Scaffold(
                  body: SizedBox.expand(
                    child: FocusScope(
                      debugLabel: 'exo-player-chrome',
                      child: FocusTraversalGroup(
                        policy: ReadingOrderTraversalPolicy(),
                        child: Row(
                          children: [
                            FocusableControl(
                              focusNode: play,
                              autoFocus: true,
                              scaleOnFocus: 1.0,
                              onTap: () {},
                              child: const SizedBox(
                                width: 48,
                                height: 48,
                                child: Icon(Icons.play_arrow),
                              ),
                            ),
                            FocusableControl(
                              focusNode: rewind,
                              scaleOnFocus: 1.0,
                              onTap: () {},
                              child: const SizedBox(
                                width: 48,
                                height: 48,
                                child: Icon(Icons.replay_10),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(play.hasFocus, isTrue);
      expect(rewind.hasFocus, isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(rewind.hasFocus, isTrue, reason: '→ from Play must reach Rewind');
      expect(play.hasFocus, isFalse);

      play.dispose();
      rewind.dispose();
    },
  );
}
