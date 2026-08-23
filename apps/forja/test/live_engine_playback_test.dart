import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/live_matches/live_matches_engine.dart';

void main() {
  group('liveEnginePreferDirectPlayback', () {
    test('delta and echo media playlists open direct', () {
      expect(
        liveEnginePreferDirectPlayback(
          'https://lb1.strmd.st/secure/tok/delta/stream/foo/1/playlist.m3u8',
        ),
        isTrue,
      );
      expect(
        liveEnginePreferDirectPlayback(
          'https://lb1.strmd.st/secure/tok/echo/stream/bar/1/playlist.m3u8',
        ),
        isTrue,
      );
    });

    test('admin rtmp master stays on hls-proxy', () {
      expect(
        liveEnginePreferDirectPlayback(
          'https://lb1.strmd.st/secure/tok/rtmp/stream/id/1/playlist.m3u8',
        ),
        isFalse,
      );
    });
  });
}
