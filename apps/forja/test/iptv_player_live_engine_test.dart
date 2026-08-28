import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/iptv/iptv/screens/iptv_pt_player_screen.dart';
import 'package:forja/features/live_matches/live_matches_engine.dart';
import 'package:rust/rust.dart';

void main() {
  group('iptvPlayerDurationLooksVod', () {
    test('live matches engine ignores short HLS window', () {
      expect(
        iptvPlayerDurationLooksVod(
          vodPlayback: false,
          engineContext: BuiltInPlayerContext.live,
          liveSourceKind: IptvLiveSourceKind.liveEngine,
          duration: const Duration(seconds: 2),
        ),
        isFalse,
      );
    });

    test('catalog vod still uses duration heuristic', () {
      expect(
        iptvPlayerDurationLooksVod(
          vodPlayback: true,
          engineContext: BuiltInPlayerContext.iptv,
          liveSourceKind: null,
          duration: const Duration(seconds: 2),
        ),
        isTrue,
      );
    });
  });

  group('ppvEmbedStreamHeaders', () {
    test('uses embed path without query on Referer', () {
      final headers = ppvEmbedStreamHeaders(
        'https://embedindia.st/embed/fiba-africa/2026-08-28/cmr-tun?gid=abc',
      );
      expect(
        headers['Referer'],
        'https://embedindia.st/embed/fiba-africa/2026-08-28/cmr-tun',
      );
      expect(headers['Origin'], 'https://embedindia.st');
    });
  });

  group('IptvPlaySource live engine refresh', () {
    test('canRefreshLiveEngine when plugin + params present', () {
      const src = IptvPlaySource(
        url: 'http://127.0.0.1/hls-proxy?url=x',
        label: 'PPV',
        liveEnginePluginId: 'live-ppv',
        liveEngineResolveParams: {'embedUrl': 'https://embedindia.st/embed/x'},
      );
      expect(src.canRefreshLiveEngine, isTrue);
    });
  });
}
