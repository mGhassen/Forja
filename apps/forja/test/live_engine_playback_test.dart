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

    test('watchfooty wfty.st playlists open direct', () {
      expect(
        liveEnginePreferDirectPlayback(
          'https://lb5.wfty.st/secure/tok/delta/live_foo/1/465/playlist.m3u8',
        ),
        isTrue,
      );
    });

    test('ppv indianservers playlists open direct', () {
      expect(
        liveEnginePreferDirectPlayback(
          'https://lb3.indianservers.st/secure/tok/fiba-africa/index.m3u8',
        ),
        isTrue,
      );
    });

    test('streamfree strmd and streamfree.top live open direct', () {
      expect(
        liveEnginePreferDirectPlayback(
          'https://lb14.strmd.st/secure/tok/streamfree/stream/foo/1/playlist.m3u8',
        ),
        isTrue,
      );
      expect(
        liveEnginePreferDirectPlayback(
          'https://streamfree.top/live/match1080p/index.m3u8?_e=1&_n=x&_t=y',
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
