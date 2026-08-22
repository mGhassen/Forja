import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/iptv/iptv/screens/iptv_pt_player_screen.dart';

void main() {
  group('iptvExoUrlLooksLive', () {
    test('Xtream live path is live', () {
      expect(
        iptvExoUrlLooksLive(
          'http://portal.example/live/user/pass/1234.ts',
        ),
        isTrue,
      );
    });

    test('Xtream movie / series are not live', () {
      expect(
        iptvExoUrlLooksLive(
          'http://portal.example/movie/user/pass/99.mp4',
        ),
        isFalse,
      );
      expect(
        iptvExoUrlLooksLive(
          'http://portal.example/series/user/pass/55.mkv',
        ),
        isFalse,
      );
    });

    test('M3U / unknown URLs default to live', () {
      expect(
        iptvExoUrlLooksLive('http://cdn.example/channel1/index.m3u8'),
        isTrue,
      );
    });
  });

  group('IptvLiveSourceKind', () {
    test('iptvXtream uses continuity proxy', () {
      expect(IptvLiveSourceKind.iptvXtream.useContinuityProxy, isTrue);
    });

    test('stremio and liveEngine open directly', () {
      expect(IptvLiveSourceKind.stremio.useContinuityProxy, isFalse);
      expect(IptvLiveSourceKind.liveEngine.useContinuityProxy, isFalse);
    });
  });

  group('iptvIsHardOpenFail', () {
    test('Failed to open', () {
      expect(
        iptvIsHardOpenFail(
          'Failed to open http://x/movie/u/p/1.mp4.',
        ),
        isTrue,
      );
    });

    test('benign seek noise is not hard open', () {
      expect(iptvIsHardOpenFail('Cannot seek'), isFalse);
    });

    test('Exo Source error / HTTP 403 is hard open', () {
      expect(iptvIsHardOpenFail('Source error'), isTrue);
      expect(
        iptvIsHardOpenFail(
          'HttpDataSource\$InvalidResponseCodeException: Response code: 403',
        ),
        isTrue,
      );
      expect(
        iptvIsHardOpenFail(
          'Source error: UnexpectedLoaderException: ArrayIndexOutOfBoundsException',
        ),
        isTrue,
      );
    });
  });

  group('iptvIsDeadEndpointFail', () {
    test('TCP timeout rotates', () {
      expect(
        iptvIsDeadEndpointFail(
          'tcp: Connection to tcp://skybeyondplus.mine.nu:25461 failed: Operation timed out',
        ),
        isTrue,
      );
      expect(
        iptvIsDeadEndpointFail(
          'Failed to open http://skybeyondplus.mine.nu:25461/live/u/p/1.m3u8.',
        ),
        isTrue,
      );
    });

    test('benign seek is not dead endpoint', () {
      expect(iptvIsDeadEndpointFail('Cannot seek'), isFalse);
    });
  });
}
