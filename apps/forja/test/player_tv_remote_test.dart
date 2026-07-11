import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/controls/player_chrome_overlay.dart';
import 'package:forja/shared/player/controls/player_tv_remote.dart';
import 'package:forja/shared/theme/app_theme.dart';

void main() {
  group('PlayerTvRemoteKeyHandler', () {
    test('back key invokes onBack', () {
      var back = 0;
      final handler = PlayerTvRemoteKeyHandler(
        onBack: () => back++,
        onPlayPause: () {},
        onShowControls: () {},
        onSeekBack: () {},
        onSeekForward: () {},
        onVolumeUp: () {},
        onVolumeDown: () {},
        onToggleControls: () {},
      );

      final handled = handler.handle(
        KeyDownEvent(
          physicalKey: PhysicalKeyboardKey(0),
          logicalKey: LogicalKeyboardKey.goBack,
          timeStamp: Duration.zero,
        ),
        showControls: true,
      );

      expect(handled, isTrue);
      expect(back, 1);
    });

    test('select toggles play/pause when controls visible', () {
      var playPause = 0;
      final handler = PlayerTvRemoteKeyHandler(
        onBack: () {},
        onPlayPause: () => playPause++,
        onShowControls: () {},
        onSeekBack: () {},
        onSeekForward: () {},
        onVolumeUp: () {},
        onVolumeDown: () {},
        onToggleControls: () {},
      );

      final handled = handler.handle(
        KeyDownEvent(
          physicalKey: PhysicalKeyboardKey(0),
          logicalKey: LogicalKeyboardKey.select,
          timeStamp: Duration.zero,
        ),
        showControls: true,
      );

      expect(handled, isTrue);
      expect(playPause, 1);
    });

    test('menu key toggles controls', () {
      var toggled = 0;
      final handler = PlayerTvRemoteKeyHandler(
        onBack: () {},
        onPlayPause: () {},
        onShowControls: () {},
        onSeekBack: () {},
        onSeekForward: () {},
        onVolumeUp: () {},
        onVolumeDown: () {},
        onToggleControls: () => toggled++,
      );

      final handled = handler.handle(
        KeyDownEvent(
          physicalKey: PhysicalKeyboardKey(0),
          logicalKey: LogicalKeyboardKey.contextMenu,
          timeStamp: Duration.zero,
        ),
        showControls: false,
      );

      expect(handled, isTrue);
      expect(toggled, 1);
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
}
