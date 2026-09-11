import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/iptv/data/models.dart';
import 'package:forja/features/iptv/screens/iptv_pt_player_screen.dart';

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

    test('stremio, liveEngine, and iptvStalker open directly', () {
      expect(IptvLiveSourceKind.stremio.useContinuityProxy, isFalse);
      expect(IptvLiveSourceKind.liveEngine.useContinuityProxy, isFalse);
      expect(IptvLiveSourceKind.iptvStalker.useContinuityProxy, isFalse);
    });

    test('portal platform maps to live source kind', () {
      expect(
        iptvLiveSourceKindForPortal(IptvPortalPlatform.stalker),
        IptvLiveSourceKind.iptvStalker,
      );
      expect(
        iptvLiveSourceKindForPortal(IptvPortalPlatform.xtream),
        IptvLiveSourceKind.iptvXtream,
      );
      expect(
        iptvLiveSourceKindForPortal(IptvPortalPlatform.m3u),
        IptvLiveSourceKind.iptvXtream,
      );
    });
  });

  group('iptvShouldUseContinuityProxy', () {
    test('Xtream / M3U progressive TS uses proxy', () {
      expect(
        iptvShouldUseContinuityProxy(
          kind: IptvLiveSourceKind.iptvXtream,
          url: 'http://portal.example/live/user/pass/1234.ts',
        ),
        isTrue,
      );
      expect(
        iptvShouldUseContinuityProxy(
          kind: IptvLiveSourceKind.iptvXtream,
          url: 'http://portal.example/live/user/pass/1234',
        ),
        isTrue,
      );
    });

    test('HLS channel URLs skip proxy (XUMO / M3U .m3u8)', () {
      expect(
        iptvShouldUseContinuityProxy(
          kind: IptvLiveSourceKind.iptvXtream,
          url:
              'https://dbrb49pjoymg4.cloudfront.net/10001/99991635/hls/playlist.m3u8?ads.xumo_channelId=99991635',
        ),
        isFalse,
      );
      expect(
        iptvUrlLooksLikeHls(
          'https://dai.google.com/linear/hls/event/abc/master.m3u8',
        ),
        isTrue,
      );
    });

    test('Stalker / stremio / liveEngine never use proxy', () {
      expect(
        iptvShouldUseContinuityProxy(
          kind: IptvLiveSourceKind.iptvStalker,
          url: 'http://portal.example/live.php?mac=1&play_token=2',
        ),
        isFalse,
      );
      expect(
        iptvShouldUseContinuityProxy(
          kind: IptvLiveSourceKind.stremio,
          url: 'https://cdn.example/live/index.m3u8',
        ),
        isFalse,
      );
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
