import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/playback/open/playback_start_trace.dart';

void main() {
  group('PlaybackStartTrace', () {
    late int now;
    late List<String> lines;
    late PlaybackStartTrace trace;

    setUp(() {
      now = 1000;
      lines = [];
      trace = PlaybackStartTrace(
        enabled: true,
        nowMs: () => now,
        sink: lines.add,
      );
    });

    test('marks are recorded in order with monotonic offsets', () {
      trace.start();
      now += 120;
      trace.mark('plugin-list-ready');
      now += 30;
      trace.mark('race-start');
      now += 900;
      trace.finish('exo-first-frame');

      expect(trace.marks.map((m) => m.name).toList(), [
        'play-pressed',
        'plugin-list-ready',
        'race-start',
        'exo-first-frame',
      ]);
      expect(trace.marks.map((m) => m.ms).toList(), [0, 120, 150, 1050]);
      for (var i = 1; i < trace.marks.length; i++) {
        expect(trace.marks[i].ms, greaterThanOrEqualTo(trace.marks[i - 1].ms));
      }
      expect(lines.first, '[play-trace] play-pressed +0ms');
      expect(lines.last, '[play-trace] exo-first-frame +1050ms');
    });

    test('marks outside a session are dropped', () {
      trace.mark('race-start');
      expect(trace.marks, isEmpty);
      expect(lines, isEmpty);

      trace.start();
      trace.finish('exo-first-frame');
      now += 50;
      trace.mark('exo-open-called');
      expect(trace.marks.length, 2);
      expect(trace.isActive, isFalse);
    });

    test('markOnce records only the first hit per session', () {
      trace.start();
      trace.markOnce('first-plugin-done');
      now += 10;
      trace.markOnce('first-plugin-done');
      expect(trace.marks.where((m) => m.name == 'first-plugin-done').length, 1);

      trace.start();
      trace.markOnce('first-plugin-done');
      expect(trace.marks.where((m) => m.name == 'first-plugin-done').length, 1);
    });

    test('start resets the previous session and relabels the origin', () {
      trace.start();
      now += 500;
      trace.mark('race-start');
      trace.start(label: 'episode-switch');
      expect(trace.marks.length, 1);
      expect(trace.marks.single.name, 'play-pressed (episode-switch)');
      expect(trace.marks.single.ms, 0);
    });

    test('detail is appended to the printed line only', () {
      trace.start();
      trace.mark('plugin-list-ready', detail: 'n=3');
      expect(lines.last, '[play-trace] plugin-list-ready +0ms n=3');
      expect(trace.marks.last.name, 'plugin-list-ready');
    });

    test('abandon closes the session without a terminal mark', () {
      trace.start();
      trace.abandon();
      trace.mark('race-start');
      expect(trace.marks.length, 1);
      expect(trace.elapsedMs, 0);
    });

    test('disabled trace records and prints nothing', () {
      final off = PlaybackStartTrace(
        enabled: false,
        nowMs: () => now,
        sink: lines.add,
      );
      off.start();
      off.mark('race-start');
      off.finish('exo-first-frame');
      expect(off.marks, isEmpty);
      expect(off.isActive, isFalse);
      expect(lines, isEmpty);
    });
  });
}
