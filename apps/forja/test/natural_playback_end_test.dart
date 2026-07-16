import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/player/utils.dart';
import 'package:media_kit/media_kit.dart';

void main() {
  group('isNaturalPlaybackEnd', () {
    PlayerState state({required int posMs, required int durMs}) {
      return PlayerState().copyWith(
        position: Duration(milliseconds: posMs),
        duration: Duration(milliseconds: durMs),
      );
    }

    test('false for tiny probe durations (torrent false completed)', () {
      // dur=500ms + pos=0 → old formula `0 >= 500-1000` was true.
      expect(
        isNaturalPlaybackEnd(state(posMs: 0, durMs: 500)),
        isFalse,
      );
      expect(
        isNaturalPlaybackEnd(state(posMs: 0, durMs: 30_000)),
        isFalse,
      );
    });

    test('false at position zero even with long duration', () {
      expect(
        isNaturalPlaybackEnd(state(posMs: 0, durMs: 3_600_000)),
        isFalse,
      );
    });

    test('true near real end of a long title', () {
      expect(
        isNaturalPlaybackEnd(state(posMs: 3_599_500, durMs: 3_600_000)),
        isTrue,
      );
    });
  });
}
