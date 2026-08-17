import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/player/post_seek_stall_watchdog.dart';

void main() {
  test('remounts once after stall, not again until new seek', () async {
    final remounts = <Duration>[];
    final w = PostSeekStallWatchdog(
      stallAfter: const Duration(milliseconds: 40),
      armWindow: const Duration(seconds: 5),
      onRemount: (t) async {
        remounts.add(t);
      },
    );

    w.noteSeek(const Duration(seconds: 100));
    w.onBuffering(true);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(remounts, [const Duration(seconds: 100)]);

    w.onBuffering(true);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(remounts, hasLength(1));

    w.noteSeek(const Duration(seconds: 120));
    w.onBuffering(true);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(remounts, [
      const Duration(seconds: 100),
      const Duration(seconds: 120),
    ]);

    w.dispose();
  });

  test('cancels when buffering clears before stall', () async {
    final remounts = <Duration>[];
    final w = PostSeekStallWatchdog(
      stallAfter: const Duration(milliseconds: 60),
      onRemount: (t) async {
        remounts.add(t);
      },
    );

    w.noteSeek(const Duration(seconds: 50));
    w.onBuffering(true);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    w.onBuffering(false);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(remounts, isEmpty);
    w.dispose();
  });

  test('clears arm when position advances near target', () async {
    final remounts = <Duration>[];
    final w = PostSeekStallWatchdog(
      stallAfter: const Duration(milliseconds: 40),
      onRemount: (t) async {
        remounts.add(t);
      },
    );

    w.noteSeek(const Duration(seconds: 80));
    w.onBuffering(true);
    w.onBuffering(false);
    w.onPosition(const Duration(seconds: 81));
    w.onBuffering(true);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(remounts, isEmpty);
    w.dispose();
  });
}
