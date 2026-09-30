import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/live/pt_player_screen.dart';
import 'package:forja/shared/player/live_sports/live_sports_player_screen.dart';

void main() {
  group('iptvStreamLavfO', () {
    test('HLS / progressive → same lavf reconnect (ipdigi)', () {
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

    test('HLS playlist omits reconnect_at_eof', () {
      final proxy = liveSportsStreamLavfO(
        streamUrl:
            'http://127.0.0.1:9/hls-proxy?url=${Uri.encodeComponent('https://cdn.example/a.m3u8')}',
      );
      final direct = liveSportsStreamLavfO(
        streamUrl: 'https://cdn.example/live/index.m3u8',
      );
      expect(proxy.contains('reconnect_at_eof'), isFalse);
      expect(direct.contains('reconnect_at_eof'), isFalse);
      expect(proxy, contains('reconnect=1'));
      expect(proxy, contains('reconnect_on_network_error=1'));
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
