import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/player/post_seek_stall_watchdog.dart';
import 'package:forja/shared/player/player/utils.dart';

void main() {
  test('does not remount during active buffering after seek', () async {
    final remounts = <Duration>[];
    final w = PostSeekStallWatchdog(
      stallAfter: const Duration(milliseconds: 40),
      armWindow: const Duration(seconds: 5),
      onRemount: (t) async {
        remounts.add(t);
        return true;
      },
    );

    w.noteSeek(const Duration(seconds: 100));
    w.onBuffering(true);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(remounts, isEmpty);

    w.onBuffering(false);
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

  test('remountPlaybackLooksLive rejects still buffering', () {
    expect(
      remountPlaybackLooksLive(
        playing: true,
        buffering: true,
        position: const Duration(seconds: 4399),
        target: const Duration(seconds: 4399),
      ),
      isFalse,
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
}
