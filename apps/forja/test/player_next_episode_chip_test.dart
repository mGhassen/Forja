import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/controls/chrome/player_next_episode_chip.dart';

Widget _host(Widget chip) => MaterialApp(
  home: Scaffold(body: Center(child: chip)),
);

void main() {
  testWidgets('countdown runs 3-2-1 then completes', (tester) async {
    var done = 0;
    await tester.pumpWidget(
      _host(
        PlayerNextEpisodeChip(
          onPressed: () {},
          countdown: true,
          onCountdownComplete: () => done++,
          onCancel: () {},
        ),
      ),
    );
    expect(find.text('3'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1100));
    expect(find.text('2'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.text('1'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1000));
    expect(done, 1);
  });

  testWidgets('paused countdown does not complete', (tester) async {
    var done = 0;
    await tester.pumpWidget(
      _host(
        PlayerNextEpisodeChip(
          onPressed: () {},
          countdown: true,
          countdownPaused: true,
          onCountdownComplete: () => done++,
          onCancel: () {},
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 5));
    expect(done, 0);
  });

  testWidgets('X cancels; no X without countdown', (tester) async {
    var cancelled = 0;
    await tester.pumpWidget(
      _host(
        PlayerNextEpisodeChip(
          onPressed: () {},
          countdown: true,
          onCancel: () => cancelled++,
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.close_rounded));
    expect(cancelled, 1);

    await tester.pumpWidget(
      _host(PlayerNextEpisodeChip(onPressed: () {}, onCancel: () {})),
    );
    expect(find.byIcon(Icons.close_rounded), findsNothing);
  });

  testWidgets('D-pad right focuses X, left returns to chip', (tester) async {
    final main = FocusNode();
    addTearDown(main.dispose);
    await tester.pumpWidget(
      _host(
        PlayerNextEpisodeChip(
          onPressed: () {},
          countdown: true,
          onCancel: () {},
          focusNode: main,
          tvFocusable: true,
        ),
      ),
    );
    main.requestFocus();
    await tester.pump();
    expect(main.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(main.hasFocus, isFalse);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'player-up-next-cancel',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(main.hasFocus, isTrue);
  });
}
