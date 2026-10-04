import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/controls/chrome/player_next_episode_chip.dart';

Widget _host(Widget chip) => MaterialApp(
  home: Scaffold(body: Center(child: chip)),
);

void main() {
  testWidgets('countdown runs 10 to 1 then completes', (tester) async {
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
    expect(find.text('10'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1100));
    expect(find.text('9'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 7900));
    expect(find.text('1'), findsOneWidget);
    expect(done, 0);
    await tester.pump(const Duration(milliseconds: 1100));
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
    await tester.pump(const Duration(seconds: 15));
    expect(done, 0);
  });

  testWidgets('hover pauses the countdown', (tester) async {
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
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('Next Episode')));
    await tester.pump(const Duration(seconds: 15));
    expect(done, 0);
    expect(find.text('10'), findsOneWidget);

    await mouse.moveTo(Offset.zero);
    await tester.pump();
    await tester.pump(const Duration(seconds: 11));
    expect(done, 1);
  });

  testWidgets('user focus pauses; host auto-focus does not', (tester) async {
    var done = 0;
    final main = FocusNode();
    addTearDown(main.dispose);
    Widget chip({required bool pauseOnFocus}) => _host(
      PlayerNextEpisodeChip(
        onPressed: () {},
        countdown: true,
        onCountdownComplete: () => done++,
        onCancel: () {},
        focusNode: main,
        tvFocusable: true,
        pauseOnFocus: pauseOnFocus,
      ),
    );

    await tester.pumpWidget(chip(pauseOnFocus: true));
    main.requestFocus();
    await tester.pump();
    await tester.pump(const Duration(seconds: 15));
    expect(done, 0);

    // Host-claimed focus runs until the user presses a key on the chip.
    await tester.pumpWidget(chip(pauseOnFocus: false));
    await tester.pump(const Duration(seconds: 11));
    expect(done, 1);
  });

  testWidgets('a key on auto-focused chip pauses the countdown', (
    tester,
  ) async {
    var done = 0;
    final main = FocusNode();
    addTearDown(main.dispose);
    await tester.pumpWidget(
      _host(
        PlayerNextEpisodeChip(
          onPressed: () {},
          countdown: true,
          onCountdownComplete: () => done++,
          onCancel: () {},
          focusNode: main,
          tvFocusable: true,
          pauseOnFocus: false,
        ),
      ),
    );
    main.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump(const Duration(seconds: 15));
    expect(main.hasFocus, isTrue);
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
