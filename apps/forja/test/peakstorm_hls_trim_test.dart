import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/screens/peakstorm_hls_trim.dart';

void main() {
  test('trimMediaPlaylistFromTarget keeps map and trims segments', () {
    const body = '''
#EXTM3U
#EXT-X-VERSION:6
#EXT-X-TARGETDURATION:4
#EXT-X-MAP:URI="init.m4s"
#EXT-X-MEDIA-SEQUENCE:0
#EXTINF:4.000,
seg-0.m4s
#EXTINF:4.000,
seg-1.m4s
#EXTINF:4.000,
seg-2.m4s
#EXTINF:4.000,
seg-3.m4s
#EXT-X-ENDLIST
''';
    final out = trimMediaPlaylistFromTarget(
      body: body,
      baseUrl: 'https://moon.peakstorm.top/vd/x/index.m3u8',
      target: const Duration(seconds: 9),
    );
    expect(out, isNotNull);
    expect(
      out!,
      contains('#EXT-X-MAP:URI="https://moon.peakstorm.top/vd/x/init.m4s"'),
    );
    expect(out, contains('#EXT-X-MEDIA-SEQUENCE:1'));
    expect(out, contains('https://moon.peakstorm.top/vd/x/seg-1.m4s'));
    expect(out, isNot(contains('seg-0.m4s')));
    expect(out, contains('#EXT-X-ENDLIST'));
  });

  test('trimMediaPlaylistFromTarget absolutizes dmcdn init.mp4 MAP', () {
    const body = '''
#EXTM3U
#EXT-X-VERSION:7
#EXT-X-TARGETDURATION:3
#EXT-X-MAP:URI="init.mp4"
#EXT-X-MEDIA-SEQUENCE:0
#EXTINF:3.000,
0.m4s
#EXTINF:3.000,
1.m4s
#EXTINF:3.000,
2.m4s
#EXT-X-ENDLIST
''';
    final out = trimMediaPlaylistFromTarget(
      body: body,
      baseUrl:
          'https://vod3.cf.dmcdn.net/sec2(x)/video/fmp4/1/h264_aac_hd/2/manifest.m3u8#cell=cf3',
      target: const Duration(seconds: 5),
    );
    expect(out, isNotNull);
    expect(
      out!,
      contains(
        '#EXT-X-MAP:URI="https://vod3.cf.dmcdn.net/sec2(x)/video/fmp4/1/h264_aac_hd/2/init.mp4"',
      ),
    );
    expect(out, contains('/2/1.m4s'));
    expect(out, isNot(contains('URI="init.mp4"')));
  });

  test('peakstormPickVariantUrl prefers DEFAULT then non-HDR', () {
    const master = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=20000000,RESOLUTION=3840x2160,VIDEO-RANGE=PQ,CODECS="hvc1.2.4.L150.B0,mp4a.40.2"
video_4k_hdr.m3u8
#EXT-X-STREAM-INF:DEFAULT=YES,BANDWIDTH=6000000,RESOLUTION=1920x1080,CODECS="avc1.4D4032,mp4a.40.2"
video_1080p.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=3000000,RESOLUTION=1280x720,CODECS="avc1.4D4020,mp4a.40.2"
video_720p.m3u8
''';
    expect(
      peakstormPickVariantUrl(
        master,
        'https://ok.solarpanelcleaning.cc/playlist/x.m3u8',
      ),
      'https://ok.solarpanelcleaning.cc/playlist/video_1080p.m3u8',
    );
  });

  test('peakstormPickVariantUrl falls back to highest non-HDR bandwidth', () {
    const master = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=20000000,RESOLUTION=3840x2160,VIDEO-RANGE=PQ,CODECS="hvc1.2.4.L150.B0"
hdr.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=6000000,RESOLUTION=1920x1080,CODECS="avc1.4D4032"
mid.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=900000,RESOLUTION=640x360,CODECS="avc1.4D401E"
low.m3u8
''';
    expect(
      peakstormPickVariantUrl(master, 'https://cdn.example/master.m3u8'),
      'https://cdn.example/mid.m3u8',
    );
  });
}
