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
    });
  });
}
