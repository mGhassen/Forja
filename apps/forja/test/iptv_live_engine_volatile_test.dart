import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/iptv/screens/iptv_pt_player_screen.dart';

void main() {
  group('iptvLiveEngineUrlVolatile', () {
    test('flags OK.ru / Livepeer / S3 / Foorja hosts', () {
      expect(
        iptvLiveEngineUrlVolatile(
          'https://oklive1.vkuser.net/video.m3u8?expires=1',
        ),
        isTrue,
      );
      expect(
        iptvLiveEngineUrlVolatile(
          'https://playback.livepeer.studio/hls/abc/index.m3u8',
        ),
        isTrue,
      );
      expect(
        iptvLiveEngineUrlVolatile(
          'https://foorja1.s3.eu-north-1.amazonaws.com/live/master.m3u8',
        ),
        isTrue,
      );
      expect(
        iptvLiveEngineUrlVolatile('https://cdn.example.com/stable/index.m3u8'),
        isFalse,
      );
    });
  });

  group('iptvLiveEngineCanForceRefresh', () {
    test('needs liveEngine kind + matchId in resolve params', () {
      expect(
        iptvLiveEngineCanForceRefresh(
          const IptvPlaySource(
            url: 'https://okcdn.ru/x.m3u8',
            label: 't',
            liveSourceKind: IptvLiveSourceKind.liveEngine,
            liveEngineResolveParams: {'matchId': 'mk_abc'},
          ),
        ),
        isTrue,
      );
      expect(
        iptvLiveEngineCanForceRefresh(
          const IptvPlaySource(
            url: 'https://okcdn.ru/x.m3u8',
            label: 't',
            liveSourceKind: IptvLiveSourceKind.liveEngine,
            liveEngineResolveParams: {'matchId': ''},
          ),
        ),
        isFalse,
      );
      expect(
        iptvLiveEngineCanForceRefresh(
          const IptvPlaySource(
            url: 'https://okcdn.ru/x.m3u8',
            label: 't',
            liveSourceKind: IptvLiveSourceKind.iptvXtream,
            liveEngineResolveParams: {'matchId': 'mk_abc'},
          ),
        ),
        isFalse,
      );
    });
  });

  group('iptvLiveEngineShouldForceRefreshOnRecovery', () {
    const stable = IptvPlaySource(
      url: 'https://cdn.example.com/stable/index.m3u8',
      label: 't',
      liveSourceKind: IptvLiveSourceKind.liveEngine,
      liveEngineResolveParams: {'matchId': 'mk_abc'},
    );
    const volatile = IptvPlaySource(
      url: 'https://okcdn.ru/x.m3u8',
      label: 't',
      liveSourceKind: IptvLiveSourceKind.liveEngine,
      liveEngineResolveParams: {'matchId': 'mk_abc'},
    );

    test('soft buffering keeps stable URL', () {
      expect(
        iptvLiveEngineShouldForceRefreshOnRecovery(
          stable,
          reason: 'buffering 5s, cache empty',
        ),
        isFalse,
      );
    });

    test('volatile CDN re-unlocks on soft recovery', () {
      expect(
        iptvLiveEngineShouldForceRefreshOnRecovery(
          volatile,
          reason: 'buffering 5s, cache empty',
        ),
        isTrue,
      );
    });

    test('hard open fail re-unlocks', () {
      expect(
        iptvLiveEngineShouldForceRefreshOnRecovery(
          stable,
          reason: 'error: Failed to open http://127.0.0.1/hls-proxy',
        ),
        isTrue,
      );
    });
  });

  group('iptvIsLiveResolveStatusBanner', () {
    test('matches unlock / prepare copy', () {
      expect(iptvIsLiveResolveStatusBanner('Preparing playback…'), isTrue);
      expect(iptvIsLiveResolveStatusBanner('Unlocking source…'), isTrue);
      expect(iptvIsLiveResolveStatusBanner('Refreshing stream…'), isTrue);
      expect(iptvIsLiveResolveStatusBanner('Reconnecting…'), isFalse);
      expect(iptvIsLiveResolveStatusBanner(null), isFalse);
    });
  });
}
