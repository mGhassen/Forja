import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/live/pt_player_screen.dart';
import 'package:forja/shared/player/live_sports/live_sports_player_screen.dart';

void main() {
  group('iptvStreamLavfO', () {
    test('HLS / progressive → same lavf reconnect', () {
      const expected = 'reconnect=1,'
          'reconnect_at_eof=1,'
          'reconnect_streamed=1,'
          'reconnect_on_network_error=1,'
          'reconnect_delay_max=5';
      expect(
        iptvStreamLavfO(streamUrl: 'https://cdn.example/live/index.m3u8'),
        expected,
      );
      expect(
        iptvStreamLavfO(
          streamUrl:
              'http://127.0.0.1:9/hls-proxy?url=${Uri.encodeComponent('https://cdn.example/a.m3u8')}',
        ),
        expected,
      );
      expect(
        iptvStreamLavfO(
          streamUrl: 'http://portal.example:8080/live/user/pass/1.ts',
        ),
        expected,
      );
      expect(iptvStreamLavfO(), expected);
    });
  });

  group('liveSportsStreamLavfO', () {
    test('Xtream TS uses the continuity proxy; HLS and Stremio stay direct', () {
      expect(
        liveSportsShouldUseContinuityProxy(
          kind: PortalLiveSourceKind.iptvXtream,
          url: 'http://portal.example:8080/live/user/pass/1.ts',
        ),
        isTrue,
      );
      expect(
        liveSportsShouldUseContinuityProxy(
          kind: PortalLiveSourceKind.iptvXtream,
          url: 'https://cdn.example/live/index.m3u8',
        ),
        isFalse,
      );
      expect(
        liveSportsShouldUseContinuityProxy(
          kind: PortalLiveSourceKind.stremio,
          url: 'http://cdn.example/live/1.ts',
        ),
        isFalse,
      );
    });

    test('continuity proxy turns lavf reconnect off', () {
      expect(
        liveSportsStreamLavfO(continuityProxy: true),
        'reconnect=0',
      );
    });

    test('progressive keeps reconnect_at_eof', () {
      final o = liveSportsStreamLavfO(
        streamUrl: 'http://portal.example:8080/live/user/pass/1.ts',
      );
      expect(o, contains('reconnect=1'));
      expect(o, contains('reconnect_at_eof=1'));
      expect(o, contains('reconnect_delay_max=30'));
      expect(o, contains('reconnect_on_http_error=4xx\\,5xx'));
      expect(liveSportsStreamLavfO(), contains('reconnect_at_eof=1'));
    });

    test('HLS playlist does not resume at EOF', () {
      final proxy = liveSportsStreamLavfO(
        streamUrl:
            'http://127.0.0.1:9/hls-proxy?url=${Uri.encodeComponent('https://cdn.example/a.m3u8')}',
      );
      final direct = liveSportsStreamLavfO(
        streamUrl: 'https://cdn.example/live/index.m3u8',
      );
      expect(proxy.contains('reconnect_at_eof'), isFalse);
      expect(direct.contains('reconnect_at_eof'), isFalse);
      expect(proxy, contains('reconnect=0'));
      expect(proxy, contains('reconnect_streamed=0'));
      expect(proxy, isNot(contains('reconnect=1')));
      expect(proxy, contains('reconnect_on_network_error=1'));
    });

    test('HLS cold cache stays inside the live window', () {
      final hls = liveSportsDesktopColdCache(hls: true);
      final progressive = liveSportsDesktopColdCache(hls: false);
      expect(hls.cacheSecs, 4);
      expect(hls.readaheadSecs, lessThan(progressive.readaheadSecs));
      expect(hls.label, 'live/sports/hls');
      expect(progressive.cacheSecs, 30);
      expect(progressive.readaheadSecs, 20);
      expect(
        liveSportsShouldReopenOnSocketEof(
          reason: 'error: tcp: ffurl_read returned 0xdfb9b0bb',
          url: 'https://cdn.example/live/index.m3u8',
        ),
        isTrue,
      );
      expect(
        liveSportsShouldReopenOnSocketEof(
          reason: 'error: tcp: ffurl_read returned 0xdfb9b0bb',
          url: 'http://portal.example/live/1.ts',
        ),
        isFalse,
      );
    });
  });

  group('iptvLiveSourceProbeUrl', () {
    test('stremio playlist is checked', () {
      const src = LivePlaySource(
        url: 'https://cdn.example/stream/channel.m3u8?t=token',
        label: 'Stream',
        liveSourceKind: PortalLiveSourceKind.stremio,
      );
      expect(iptvLiveSourceProbeUrl(src), src.url);
      expect(iptvLiveSourceProbeSkipped(src), isFalse);
    });

    test('stremio row with request headers is not bare-probed', () {
      const src = LivePlaySource(
        url: 'https://cdn.example/live.m3u8',
        label: 'Stream',
        headers: {'Referer': 'https://example/'},
        liveSourceKind: PortalLiveSourceKind.stremio,
      );
      expect(iptvLiveSourceProbeUrl(src), isNull);
      expect(iptvLiveSourceProbeSkipped(src), isTrue);
    });
  });

  group('iptvUrlLooksLikeHls', () {
    test('m3u8 and hls-proxy', () {
      expect(iptvUrlLooksLikeHls('https://x/a.m3u8'), isTrue);
      expect(iptvUrlLooksLikeHls('http://127.0.0.1/hls-proxy?url=x'), isTrue);
      expect(iptvUrlLooksLikeHls('http://x/live/1.ts'), isFalse);
    });
  });
}
