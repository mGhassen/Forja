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

    test('true near real end of a long title after enough confirmed time', () {
      expect(
        isNaturalPlaybackEnd(
          state(posMs: 3_599_500, durMs: 3_600_000),
          confirmedFor: const Duration(minutes: 50),
          hadMidPlayback: true,
        ),
        isTrue,
      );
    });

    test('false when EOF arrives seconds after confirm (torrent early EOF)', () {
      expect(
        isNaturalPlaybackEnd(
          state(posMs: 3_938_142, durMs: 3_938_142),
          confirmedFor: const Duration(seconds: 3),
        ),
        isFalse,
      );
    });

    test('false when stuck at EOF without mid-episode playback even after grace', () {
      expect(
        isNaturalPlaybackEnd(
          state(posMs: 3_938_142, durMs: 3_938_142),
          confirmedFor: const Duration(minutes: 2),
          hadMidPlayback: false,
        ),
        isFalse,
      );
    });
  });

  group('shouldPersistWatchProgress', () {
    final confirmed = DateTime(2026, 7, 16, 2, 57, 50);

    test('skips near-end progress within grace window', () {
      expect(
        shouldPersistWatchProgress(
          positionMs: 3_938_142,
          durationMs: 3_938_142,
          confirmedAt: confirmed,
          now: confirmed.add(const Duration(seconds: 5)),
        ),
        isFalse,
      );
    });

    test('allows mid-episode progress within grace window', () {
      expect(
        shouldPersistWatchProgress(
          positionMs: 120_000,
          durationMs: 3_600_000,
          confirmedAt: confirmed,
          now: confirmed.add(const Duration(seconds: 20)),
        ),
        isTrue,
      );
    });

    test('allows near-end progress after grace window', () {
      expect(
        shouldPersistWatchProgress(
          positionMs: 3_590_000,
          durationMs: 3_600_000,
          confirmedAt: confirmed,
          now: confirmed.add(const Duration(minutes: 55)),
        ),
        isTrue,
      );
    });
  });

  group('sourceRequiresVideoDecode', () {
    test('requires decode for local torrent stream URLs', () {
      expect(
        sourceRequiresVideoDecode(
          'http://127.0.0.1:52788/torrents/0/stream/0/ep.mp4',
        ),
        isTrue,
      );
      expect(
        sourceRequiresVideoDecode('https://cdn.example/video.mp4'),
        isFalse,
      );
    });
  });

  group('isOpenReadyForStream', () {
    PlayerState state({
      int? videoW,
      int? videoH,
      int bufferMs = 0,
      int durationMs = 0,
      int positionMs = 0,
      bool playing = false,
      double bufferingPercentage = 0,
    }) {
      return PlayerState().copyWith(
        videoParams: VideoParams(w: videoW, h: videoH),
        buffer: Duration(milliseconds: bufferMs),
        duration: Duration(milliseconds: durationMs),
        position: Duration(milliseconds: positionMs),
        playing: playing,
        bufferingPercentage: bufferingPercentage,
      );
    }

    test('local torrent ignores buffer/duration without decoded video', () {
      expect(
        isOpenReadyForStream(
          state(bufferMs: 5000, durationMs: 3_600_000, playing: true),
          localTorrent: true,
        ),
        isFalse,
      );
    });

    test('local torrent ready only after decoded video', () {
      expect(
        isOpenReadyForStream(
          state(videoW: 1920, videoH: 1080),
          localTorrent: true,
        ),
        isTrue,
      );
    });

    test('non-torrent still treats buffer as ready', () {
      expect(
        isOpenReadyForStream(state(bufferMs: 1000), localTorrent: false),
        isTrue,
      );
    });
  });
}
