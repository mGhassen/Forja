import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/playback/sources/stream_playback_knobs.dart';

void main() {
  group('stream playback knobs', () {
    test('parses probe modes from pack fields', () {
      expect(streamProbeModeFrom('skip'), StreamProbeMode.skip);
      expect(streamProbeModeFrom('headOrRange'), StreamProbeMode.headOrRange);
      expect(
        streamProbeModeFrom('segmentPoisonSample'),
        StreamProbeMode.segmentPoisonSample,
      );
      expect(streamProbeModeFrom('masterOnly'), StreamProbeMode.masterOnly);
      expect(streamProbeModeFrom(''), isNull);
      expect(streamProbeModeFrom('not-a-mode'), isNull);
    });

    test('playlist heuristic is m3u8 or hls-proxy, not generic /api/proxy', () {
      expect(
        streamUrlLooksLikeHlsPlaylist('https://cdn.example/a.m3u8'),
        isTrue,
      );
      expect(
        streamUrlLooksLikeHlsPlaylist('https://app.example/hls-proxy?u=x'),
        isTrue,
      );
      expect(
        streamUrlLooksLikeHlsPlaylist(
          'https://cdn.example/api/proxy/TOKEN?headers=abc',
        ),
        isFalse,
      );
      expect(
        streamUrlLooksLikeHlsPlaylist('https://cdn.example/file.mp4'),
        isFalse,
      );
    });

    test('png strip defaults to never', () {
      expect(pngStripModeFrom(null), PngStripMode.never);
      expect(pngStripModeFrom('auto'), PngStripMode.auto);
      expect(pngStripModeFrom('force'), PngStripMode.force);
      expect(pngStripModeFrom('nope'), PngStripMode.never);
    });
  });
}
