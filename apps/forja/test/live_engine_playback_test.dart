import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/live/live_plugin_engine.dart';

void main() {
  group('liveEnginePreferDirectPlayback', () {
    test('always false — packs own directPlayback flag', () {
      expect(
        liveEnginePreferDirectPlayback(
          'https://lb1.strmd.st/secure/tok/delta/stream/foo/1/playlist.m3u8',
        ),
        isFalse,
      );
      expect(
        liveEnginePreferDirectPlayback(
          'https://lb3.indianservers.st/secure/tok/fiba-africa/index.m3u8',
        ),
        isFalse,
      );
      expect(
        liveEnginePreferDirectPlayback(
          'https://streamfree.top/live/match1080p/index.m3u8?_e=1&_n=x&_t=y',
        ),
        isFalse,
      );
    });
  });

  group('liveEngineOpenDirect', () {
    test('trusts pluginDirect except wfty / amazonaws', () {
      expect(
        liveEngineOpenDirect(
          'https://lb1.strmd.st/secure/tok/delta/stream/foo/1/playlist.m3u8',
          pluginDirect: true,
        ),
        isTrue,
      );
      expect(
        liveEngineOpenDirect(
          'https://lb1.strmd.st/secure/tok/delta/stream/foo/1/playlist.m3u8',
          pluginDirect: false,
        ),
        isFalse,
      );
      expect(
        liveEngineOpenDirect(
          'https://lb5.wfty.st/secure/tok/sigma/slug/2/1/1/playlist.m3u8',
          pluginDirect: true,
        ),
        isFalse,
      );
      expect(
        liveEngineOpenDirect(
          'https://foorja1.s3.eu-north-1.amazonaws.com/live/master.m3u8',
          pluginDirect: true,
        ),
        isFalse,
      );
    });

    test('CDN path alone is not enough without pluginDirect', () {
      expect(
        liveEngineOpenDirect(
          'https://lb14.strmd.st/secure/tok/streamfree/stream/foo/1/playlist.m3u8',
        ),
        isFalse,
      );
      expect(
        liveEngineOpenDirect(
          'https://lb1.strmd.st/secure/tok/rtmp/stream/id/1/playlist.m3u8',
        ),
        isFalse,
      );
    });
  });
}
