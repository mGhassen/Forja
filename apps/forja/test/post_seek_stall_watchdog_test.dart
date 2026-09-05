import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/player/post_seek_stall_watchdog.dart';
import 'package:forja/shared/player/player/utils.dart';
import 'package:media_kit/media_kit.dart';

void main() {
  test('remounts after prolonged buffering when position stuck', () async {
    final remounts = <Duration>[];
    final w = PostSeekStallWatchdog(
      stallAfter: const Duration(milliseconds: 40),
      armWindow: const Duration(seconds: 5),
      scaleStallWithDepth: false,
      onRemount: (t) async {
        remounts.add(t);
        return true;
      },
    );

    w.noteSeek(const Duration(seconds: 100));
    w.onBuffering(true);
    w.onPosition(const Duration(seconds: 100));
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(remounts, [const Duration(seconds: 100)]);

    w.dispose();
  });

  test('remounts once after silent freeze, not again until new seek', () async {
    final remounts = <Duration>[];
    final w = PostSeekStallWatchdog(
      stallAfter: const Duration(milliseconds: 40),
      armWindow: const Duration(seconds: 5),
      scaleStallWithDepth: false,
      onRemount: (t) async {
        remounts.add(t);
        return true;
      },
    );

    w.noteSeek(const Duration(seconds: 100));
    w.onPosition(const Duration(seconds: 100));
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(remounts, [const Duration(seconds: 100)]);

    w.onPosition(const Duration(seconds: 100));
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(remounts, hasLength(1));

    w.noteSeek(const Duration(seconds: 120));
    w.onPosition(const Duration(seconds: 120));
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(remounts, [
      const Duration(seconds: 100),
      const Duration(seconds: 120),
    ]);

    w.dispose();
  });

  test('remounts on silent freeze (no buffering) after seek', () async {
    final remounts = <Duration>[];
    final w = PostSeekStallWatchdog(
      stallAfter: const Duration(milliseconds: 40),
      scaleStallWithDepth: false,
      onRemount: (t) async {
        remounts.add(t);
        return true;
      },
    );

    w.noteSeek(const Duration(seconds: 90));
    w.onPosition(const Duration(seconds: 90));
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(remounts, [const Duration(seconds: 90)]);
    w.dispose();
  });

  test('does not remount when buffering clears and position advances', () async {
    final remounts = <Duration>[];
    final w = PostSeekStallWatchdog(
      stallAfter: const Duration(milliseconds: 60),
      scaleStallWithDepth: false,
      onRemount: (t) async {
        remounts.add(t);
        return true;
      },
    );

    w.noteSeek(const Duration(seconds: 50));
    w.onBuffering(true);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    w.onBuffering(false);
    w.onPosition(const Duration(seconds: 53));
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(remounts, isEmpty);
    w.dispose();
  });

  test('pause after seek cancels remount', () async {
    final remounts = <Duration>[];
    final w = PostSeekStallWatchdog(
      stallAfter: const Duration(milliseconds: 40),
      scaleStallWithDepth: false,
      onRemount: (t) async {
        remounts.add(t);
        return true;
      },
    );

    w.noteSeek(const Duration(seconds: 40));
    w.onPlaying(false);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(remounts, isEmpty);
    w.dispose();
  });

  test('failed remount allows another attempt on new seek', () async {
    final remounts = <Duration>[];
    var attempt = 0;
    final w = PostSeekStallWatchdog(
      stallAfter: const Duration(milliseconds: 40),
      scaleStallWithDepth: false,
      onRemount: (t) async {
        remounts.add(t);
        attempt++;
        return attempt > 1;
      },
    );

    w.noteSeek(const Duration(seconds: 60));
    w.onPosition(const Duration(seconds: 60));
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(remounts, [const Duration(seconds: 60)]);

    w.noteSeek(const Duration(seconds: 70));
    w.onPosition(const Duration(seconds: 70));
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(remounts, [
      const Duration(seconds: 60),
      const Duration(seconds: 70),
    ]);
    w.dispose();
  });

  test('remountPlaybackLooksLive rejects open-at-zero after a mid-film target', () {
    expect(
      remountPlaybackLooksLive(
        playing: true,
        buffering: false,
        position: Duration.zero,
        target: const Duration(seconds: 4399),
      ),
      isFalse,
    );
  });

  test('remountPlaybackLooksLive accepts buffering near target', () {
    expect(
      remountPlaybackLooksLive(
        playing: true,
        buffering: true,
        position: const Duration(seconds: 4399),
        target: const Duration(seconds: 4399),
      ),
      isTrue,
    );
  });

  test('remountPlaybackResumed rejects buffering without decoded video', () {
    final state = PlayerState().copyWith(
      playing: true,
      buffering: true,
      position: const Duration(seconds: 1426),
    );
    expect(
      remountPlaybackResumed(state, const Duration(seconds: 1426)),
      isFalse,
    );
  });

  test('remountPlaybackResumed rejects peakstorm buffering at target', () {
    final state = PlayerState().copyWith(
      playing: true,
      buffering: true,
      position: const Duration(seconds: 1108),
      videoParams: const VideoParams(w: 1920, h: 960),
    );
    const url = 'https://moon.peakstorm.top/vd/x/master.m3u8';
    expect(
      remountPlaybackResumed(
        state,
        const Duration(seconds: 1108),
        streamUrl: url,
      ),
      isFalse,
    );
    expect(
      remountPlaybackResumed(
        state.copyWith(buffering: false),
        const Duration(seconds: 1108),
        streamUrl: url,
      ),
      isTrue,
    );
  });

  test('remountPlaybackResumed rejects peakstorm stagnant PTS at target', () {
    const url = 'https://moon.peakstorm.top/vd/x/master.m3u8';
    const target = Duration(seconds: 587);
    final state = PlayerState().copyWith(
      playing: true,
      buffering: false,
      position: target,
      videoParams: const VideoParams(w: 1920, h: 960),
    );
    expect(
      remountPlaybackResumed(
        state,
        target,
        streamUrl: url,
        previousPosition: target,
      ),
      isFalse,
    );
    expect(
      remountPlaybackResumed(
        state,
        target,
        streamUrl: url,
        previousPosition: const Duration(seconds: 585),
      ),
      isTrue,
    );
  });

  test('clearPendingSeek cancels armed remount', () async {
    final remounts = <Duration>[];
    final w = PostSeekStallWatchdog(
      stallAfter: const Duration(milliseconds: 40),
      scaleStallWithDepth: false,
      onRemount: (t) async {
        remounts.add(t);
        return true;
      },
    );

    w.noteSeek(const Duration(seconds: 100));
    w.onBuffering(true);
    w.clearPendingSeek();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(remounts, isEmpty);
    w.dispose();
  });

  test('peakstormFmp4HlsAvoidHardSeek matches master and child playlists', () {
    expect(
      peakstormFmp4HlsAvoidHardSeek(
        'https://moon.peakstorm.top/vd/x/master.m3u8',
      ),
      isTrue,
    );
    expect(
      peakstormFmp4HlsAvoidHardSeek(
        'https://vod3.cf.dmcdn.net/sec2(x)/video/fmp4/1/h264_aac_hd/2/manifest.m3u8#cell=cf3',
      ),
      isTrue,
    );
    expect(
      peakstormFmp4HlsAvoidHardSeek(
        'https://example.com/vod/index.m3u8',
      ),
      isFalse,
    );
  });

  test('postSeekStallTimeoutForTarget scales with depth', () {
    expect(
      postSeekStallTimeoutForTarget(const Duration(minutes: 5)).inSeconds,
      15,
    );
    expect(
      postSeekStallTimeoutForTarget(const Duration(minutes: 49)).inSeconds,
      35,
    );
  });

  test('shouldSkipPostSeekStallArm during resume grace', () {
    final confirmed = DateTime.now().subtract(const Duration(seconds: 5));
    expect(
      shouldSkipPostSeekStallArm(
        target: const Duration(seconds: 2965),
        resumeStartPosition: const Duration(seconds: 2965),
        playbackConfirmedAt: confirmed,
      ),
      isTrue,
    );
    expect(
      shouldSkipPostSeekStallArm(
        target: const Duration(seconds: 2990),
        resumeStartPosition: const Duration(seconds: 2965),
        playbackConfirmedAt: confirmed,
      ),
      isFalse,
    );
  });

  test('remountResumeTimeoutForSeek scales with depth', () {
    expect(
      remountResumeTimeoutForSeek(const Duration(minutes: 5)).inSeconds,
      15,
    );
    expect(
      remountResumeTimeoutForSeek(const Duration(minutes: 59)).inSeconds,
      60,
    );
  });

  test('remountPlaybackLooksLive accepts playing near target', () {
    expect(
      remountPlaybackLooksLive(
        playing: true,
        buffering: false,
        position: const Duration(seconds: 4401),
        target: const Duration(seconds: 4399),
      ),
      isTrue,
    );
  });

  test('playerUiPosition adds peakstorm trim offset', () {
    peakstormPlaybackTimeOffset = const Duration(seconds: 1191);
    addTearDown(() => peakstormPlaybackTimeOffset = Duration.zero);
    expect(
      playerUiPosition(const Duration(seconds: 2)),
      const Duration(seconds: 1193),
    );
    expect(
      playerUiDuration(const Duration(seconds: 400)),
      const Duration(seconds: 1591),
    );
    peakstormPlaybackTimeOffset = Duration.zero;
    expect(
      playerUiPosition(const Duration(seconds: 2)),
      const Duration(seconds: 2),
    );
    expect(
      playerUiDuration(const Duration(seconds: 400)),
      const Duration(seconds: 400),
    );
  });
}
