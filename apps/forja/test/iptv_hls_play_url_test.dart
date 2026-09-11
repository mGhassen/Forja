import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/iptv/iptv_hls_play_url.dart';

void main() {
  group('iptvStripHlsAdPlaceholders', () {
    test('drops [TOKEN] query values, keeps real params', () {
      final out = iptvStripHlsAdPlaceholders(
        'https://cdn.example/hls/playlist.m3u8'
        '?ads.xumo_channelId=999'
        '&ads._fw_did=[IFA]'
        '&ads.os=[OS]'
        '&keep=ok',
      );
      expect(out, contains('ads.xumo_channelId=999'));
      expect(out, contains('keep=ok'));
      expect(out, isNot(contains('[IFA]')));
      expect(out, isNot(contains('[OS]')));
    });
  });

  group('iptvPickHlsMediaPlaylistUrl', () {
    const master = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=441000,RESOLUTION=400x224
low.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=2249000,RESOLUTION=960x540
mid.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=5980000,RESOLUTION=1920x1080
hi.m3u8
''';

    test('picks highest under maxBandwidth', () {
      final url = iptvPickHlsMediaPlaylistUrl(
        masterBody: master,
        masterUrl: 'https://dai.example/event/master.m3u8',
        maxBandwidth: 3_500_000,
      );
      expect(url, 'https://dai.example/event/mid.m3u8');
    });

    test('falls back to lowest when all above cap', () {
      final url = iptvPickHlsMediaPlaylistUrl(
        masterBody: master,
        masterUrl: 'https://dai.example/event/master.m3u8',
        maxBandwidth: 100_000,
      );
      expect(url, 'https://dai.example/event/low.m3u8');
    });

    test('returns master when already a media playlist', () {
      const media = '#EXTM3U\n#EXTINF:4,\nseg.ts\n';
      expect(
        iptvPickHlsMediaPlaylistUrl(
          masterBody: media,
          masterUrl: 'https://cdn.example/media.m3u8',
        ),
        'https://cdn.example/media.m3u8',
      );
    });
  });

  group('iptvResolveHlsPlayUrl', () {
    test('resolves master via injected fetch', () async {
      const body = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=1500000
variant.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=5000000
hi.m3u8
''';
      final out = await iptvResolveHlsPlayUrl(
        url:
            'https://dai.example/master.m3u8?ads._fw_did=[IFA]&id=1',
        fetchBody: (url, _) async {
          expect(url, isNot(contains('[IFA]')));
          expect(url, contains('id=1'));
          return body;
        },
      );
      expect(out, 'https://dai.example/variant.m3u8');
    });
  });
}
