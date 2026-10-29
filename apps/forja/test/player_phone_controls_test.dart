import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/controls/chrome/player_chrome_overlay.dart';
import 'package:forja/shared/player/controls/chrome/player_phone_controls.dart';
import 'package:forja/shared/player/controls/menus/player_popup_panel.dart';
import 'package:forja/shared/player/platform/phone_player_system_ui.dart';
import 'package:forja/shell/core/forja_shell_platform.dart';
import 'package:forja/shell/core/forja_shell_profile.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja_foundation/tokens/player_phone_tokens.dart';

/// Landscape phone player surface (dp).
const _phone = Size(914, 411);

Widget _host(Widget child, {ShellProfile profile = ShellProfile.mobile}) {
  return MaterialApp(
    home: ShellScope(
      profile: profile,
      config: shellPlatformConfigFor(profile),
      child: Scaffold(backgroundColor: Colors.black, body: child),
    ),
  );
}

Future<void> _setSurface(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _row({bool? playing, VoidCallback? onNext}) {
  return Align(
    alignment: Alignment.bottomCenter,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: PlayerPhoneTransportRow(
        time: const Text('0:22 / 28:28'),
        playing: playing,
        onPlayPause: () {},
        onNextEpisode: onNext ?? () {},
        source: const SizedBox(
          key: ValueKey('synthetic-source'),
          width: 120,
          height: PlayerPhoneTokens.touchTarget,
        ),
        onEpisodes: (_) {},
        onAudioSubtitles: (_) {},
        onMore: (_) {},
      ),
    ),
  );
}

void main() {
  group('PlayerTapSeekBurst', () {
    final t0 = DateTime(2026, 1, 1, 12);
    const dur = Duration(minutes: 30);
    const pos = Duration(minutes: 5);

    test('first double tap seeks one 10 s step from the tap position', () {
      final b = PlayerTapSeekBurst();
      expect(
        b.doubleTap(forward: true, now: t0, position: pos, duration: dur),
        pos + const Duration(seconds: 10),
      );
      expect(b.totalSeconds, 10);
      expect(
        PlayerTapSeekBurst().doubleTap(
          forward: false,
          now: t0,
          position: pos,
          duration: dur,
        ),
        pos - const Duration(seconds: 10),
      );
    });

    test('repeated taps on the same side accumulate from the burst start', () {
      final b = PlayerTapSeekBurst();
      b.doubleTap(forward: true, now: t0, position: pos, duration: dur);
      // Player position has not caught up yet — burst still adds up.
      final t1 = t0.add(const Duration(milliseconds: 400));
      expect(
        b.doubleTap(forward: true, now: t1, position: pos, duration: dur),
        pos + const Duration(seconds: 30),
      );
      final t2 = t1.add(const Duration(milliseconds: 500));
      expect(
        b.singleTap(forward: true, now: t2, duration: dur),
        pos + const Duration(seconds: 40),
      );
      expect(b.totalSeconds, 40);
    });

    test('single tap outside a live burst is an ordinary tap', () {
      final b = PlayerTapSeekBurst();
      expect(b.singleTap(forward: true, now: t0, duration: dur), isNull);
      b.doubleTap(forward: true, now: t0, position: pos, duration: dur);
      // Other side → toggle chrome, not seek.
      expect(
        b.singleTap(
          forward: false,
          now: t0.add(const Duration(milliseconds: 300)),
          duration: dur,
        ),
        isNull,
      );
      // Window elapsed → ordinary tap.
      expect(
        b.singleTap(
          forward: true,
          now: t0.add(PlayerPhoneTokens.seekBurstWindow * 2),
          duration: dur,
        ),
        isNull,
      );
    });

    test('opposite side or expired window starts a new burst', () {
      final b = PlayerTapSeekBurst();
      b.doubleTap(forward: true, now: t0, position: pos, duration: dur);
      final back = b.doubleTap(
        forward: false,
        now: t0.add(const Duration(milliseconds: 200)),
        position: pos + const Duration(seconds: 10),
        duration: dur,
      );
      expect(back, pos);
      expect(b.forward, isFalse);
      expect(b.totalSeconds, 10);
    });

    test('targets clamp to 0 and duration', () {
      expect(
        PlayerTapSeekBurst().doubleTap(
          forward: false,
          now: t0,
          position: const Duration(seconds: 4),
          duration: dur,
        ),
        Duration.zero,
      );
      expect(
        PlayerTapSeekBurst().doubleTap(
          forward: true,
          now: t0,
          position: dur - const Duration(seconds: 3),
          duration: dur,
        ),
        dur,
      );
    });
  });

  group('PlayerPhoneTransportRow', () {
    testWidgets('landscape phone: labeled actions, all ≥ 48 dp, no overflow', (
      tester,
    ) async {
      await _setSurface(tester, _phone);
      await tester.pumpWidget(_host(_row()));
      await tester.pump();

      expect(tester.takeException(), isNull);
      for (final key in [
        PlayerPhoneKeys.nextEpisode,
        PlayerPhoneKeys.episodes,
        PlayerPhoneKeys.audioSubtitles,
        PlayerPhoneKeys.more,
      ]) {
        final size = tester.getSize(find.byKey(key));
        expect(size.width, greaterThanOrEqualTo(PlayerPhoneTokens.touchTarget));
        expect(
          size.height,
          greaterThanOrEqualTo(PlayerPhoneTokens.touchTarget),
        );
      }
      expect(find.text('Episodes'), findsOneWidget);
      expect(find.text('Audio & subtitles'), findsOneWidget);
      expect(find.text('Next episode'), findsOneWidget);

      // Center cluster owns play/pause and ±10 while it is visible.
      expect(find.byKey(PlayerPhoneKeys.playPause), findsNothing);
      expect(find.byIcon(Icons.replay_10_rounded), findsNothing);
      expect(find.byIcon(Icons.forward_10_rounded), findsNothing);
    });

    testWidgets('narrow phone: icon-only actions still fit and stay 48 dp', (
      tester,
    ) async {
      await _setSurface(tester, const Size(640, 360));
      await tester.pumpWidget(_host(_row()));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Audio & subtitles'), findsNothing);
      final size = tester.getSize(find.byKey(PlayerPhoneKeys.audioSubtitles));
      expect(size.width, greaterThanOrEqualTo(PlayerPhoneTokens.touchTarget));
    });

    testWidgets(
      'tight Flexible slot: stream picker collapses to icon, no overflow',
      (tester) async {
        await _setSurface(tester, _phone);
        await tester.pumpWidget(
          _host(
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                // Matches the log that overflowed at ~64 dp before collapse.
                width: 64,
                child: PlayerStreamPickerButton(
                  label: 'Anizone',
                  server: 'mirror-1',
                  size: PlayerPhoneTokens.touchTarget,
                  iconSize: PlayerPhoneTokens.actionIconSize,
                  maxWidth: PlayerPhoneTokens.sourceButtonMaxWidth,
                  labelMaxWidth: PlayerPhoneTokens.sourcePickerLabelMaxWidth,
                  padH: PlayerPhoneTokens.sourcePadH,
                  iconGap: PlayerPhoneTokens.sourceIconGap,
                  labeledMinWidth: PlayerPhoneTokens.sourceLabeledMinWidth,
                  onPressedWithContext: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('Anizone'), findsNothing);
        expect(find.byIcon(Icons.layers_outlined), findsOneWidget);
      },
    );

    testWidgets('play/pause appears when the center cluster is covered', (
      tester,
    ) async {
      await _setSurface(tester, _phone);
      await tester.pumpWidget(_host(_row(playing: true)));
      await tester.pump();

      final play = find.byKey(PlayerPhoneKeys.playPause);
      expect(play, findsOneWidget);
      expect(
        tester.getSize(play).height,
        greaterThanOrEqualTo(PlayerPhoneTokens.touchTarget),
      );
      expect(
        find.descendant(of: play, matching: find.byIcon(Icons.pause_rounded)),
        findsOneWidget,
      );
    });
  });

  group('phone action menu', () {
    tearDown(PlayerPopupPanel.dismiss);

    testWidgets('More rows close the menu and run against the same anchor', (
      tester,
    ) async {
      await _setSurface(tester, _phone);
      BuildContext? opened;
      await tester.pumpWidget(
        _host(
          Align(
            alignment: Alignment.bottomRight,
            child: Builder(
              builder: (anchor) => TextButton(
                onPressed: () => showPlayerPhoneActionMenu(
                  context: anchor,
                  anchorContext: anchor,
                  title: 'More',
                  icon: Icons.more_horiz_rounded,
                  entries: [
                    PlayerPhoneMenuEntry(
                      icon: Icons.lock_outline_rounded,
                      title: 'Lock controls',
                      onSelected: (a) => opened = a,
                    ),
                  ],
                ),
                child: const Text('more'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('more'));
      await tester.pumpAndSettle();
      expect(find.text('Lock controls'), findsOneWidget);

      await tester.tap(find.text('Lock controls'));
      await tester.pumpAndSettle();
      expect(PlayerPopupPanel.isShowing, isFalse);
      expect(opened, isNotNull);
    });
  });

  group('popup panel clearance', () {
    Future<double> panelTitleTop(
      WidgetTester tester,
      ShellProfile profile,
    ) async {
      await _setSurface(tester, _phone);
      await tester.pumpWidget(
        _host(
          profile: profile,
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 12, bottom: 8),
              child: Builder(
                builder: (anchor) => TextButton(
                  onPressed: () => PlayerPopupPanel.show(
                    context: anchor,
                    anchorContext: anchor,
                    title: 'Subtitles',
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (var i = 0; i < 30; i++)
                          SizedBox(height: 48, child: Text('row $i')),
                      ],
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final top = tester.getTopLeft(find.text('Subtitles')).dy;
      PlayerPopupPanel.dismiss();
      await tester.pumpAndSettle();
      return top;
    }

    testWidgets('phone: panel stays below the player top bar', (tester) async {
      final top = await panelTitleTop(tester, ShellProfile.mobile);
      expect(top, greaterThanOrEqualTo(PlayerPhoneTokens.panelTopClearance));
    });

    testWidgets('desktop: panel placement unchanged (may rise above)', (
      tester,
    ) async {
      final top = await panelTitleTop(tester, ShellProfile.desktop);
      expect(top, lessThan(PlayerPhoneTokens.panelTopClearance));
    });
  });

  testWidgets('double-tap feedback shows the accumulated seek', (tester) async {
    await _setSurface(tester, _phone);
    await tester.pumpWidget(
      _host(
        const PlayerDoubleTapSeekFeedback(
          forward: true,
          seconds: 30,
          tapPosition: Offset(700, 200),
          pulse: 3,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('+30 s'), findsOneWidget);
    expect(find.byIcon(Icons.fast_forward_rounded), findsOneWidget);
    await tester.pumpWidget(
      _host(
        const PlayerDoubleTapSeekFeedback(
          forward: false,
          seconds: 10,
          tapPosition: Offset(100, 200),
          pulse: 4,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('-10 s'), findsOneWidget);
  });

  group('PhonePlayerSystemUi', () {
    late List<MethodCall> calls;

    setUp(() {
      PhonePlayerSystemUi.debugReset();
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method.startsWith('SystemChrome.')) calls.add(call);
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
      PhonePlayerSystemUi.debugReset();
    });

    testWidgets('forced pop restores portrait, edge-to-edge, then unlocks', (
      tester,
    ) async {
      PhonePlayerSystemUi.attach();
      PhonePlayerSystemUi.detach(restore: true);
      await tester.pump(PlayerPhoneTokens.exitRotationSettle);
      await tester.pump(PlayerPhoneTokens.exitRotationSettle);
      await tester.pump(PlayerPhoneTokens.exitOrientationRelease);

      expect(calls.map((c) => c.method).toList(), [
        'SystemChrome.setPreferredOrientations',
        'SystemChrome.setEnabledSystemUIMode',
        'SystemChrome.setPreferredOrientations',
      ]);
      expect(calls[0].arguments, ['DeviceOrientation.portraitUp']);
      expect(calls[1].arguments, 'SystemUiMode.edgeToEdge');
      expect(calls[2].arguments, isEmpty);
    });

    testWidgets('episode hand-off keeps the player chrome (no restore)', (
      tester,
    ) async {
      PhonePlayerSystemUi.attach(); // current episode
      PhonePlayerSystemUi.attach(); // next episode mounts first
      PhonePlayerSystemUi.detach(restore: true); // old one disposes
      await tester.pump(PlayerPhoneTokens.exitRotationSettle * 3);
      await tester.pump(PlayerPhoneTokens.exitOrientationRelease);
      expect(calls, isEmpty);
      expect(PhonePlayerSystemUi.playerAlive, isTrue);
    });

    testWidgets('exit path release is cancelled when a new player mounts', (
      tester,
    ) async {
      PhonePlayerSystemUi.attach();
      PhonePlayerSystemUi.scheduleOrientationRelease();
      PhonePlayerSystemUi.detach(restore: false);
      PhonePlayerSystemUi.attach(); // user opened another title right away
      await tester.pump(PlayerPhoneTokens.exitOrientationRelease * 2);
      expect(calls, isEmpty);
    });
  });
}
