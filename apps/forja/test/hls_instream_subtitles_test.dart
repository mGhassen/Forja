import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/controls/menus/hls_instream_subtitles.dart';

void main() {
  test('parseForjaHlsSubtitles reads proxy comments and resolves relative uris', () {
    const body = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=1000
video.m3u8
#FORJA-SUB:lang=en&name=English&uri=subs/en.m3u8
#FORJA-SUB:lang=es&name=Espa%C3%B1ol&uri=http%3A%2F%2F127.0.0.1%3A9%2Fhls-proxy%3Furl%3Dhttps%253A%252F%252Fcdn%252Fes.m3u8
''';
    final playlist = Uri.parse('http://127.0.0.1:9/ext/abc/master.m3u8');
    final subs = parseForjaHlsSubtitles(body, playlistUri: playlist);
    expect(subs, hasLength(2));
    expect(subs[0].language, 'en');
    expect(subs[0].name, 'English');
    expect(subs[0].uri, 'http://127.0.0.1:9/ext/abc/subs/en.m3u8');
    expect(subs[1].language, 'es');
    expect(subs[1].name, 'Español');
    expect(subs[1].uri, contains('/hls-proxy?url='));
  });

  test('parseHlsInStreamSubtitles reads EXT-X-MEDIA subtitle renditions', () {
    const body = '''
#EXTM3U
#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",NAME="English",LANGUAGE="en",URI="subs/en.m3u8"
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="aud",NAME="English",URI="audio.m3u8"
#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",NAME="Thai",LANGUAGE=th,URI="https://cdn.example/th.vtt"
#EXT-X-STREAM-INF:BANDWIDTH=1000,SUBTITLES="subs"
video.m3u8
''';
    final playlist = Uri.parse('https://cdn.example/master.m3u8');
    final subs = parseHlsInStreamSubtitles(body, playlistUri: playlist);
    expect(subs, hasLength(2));
    expect(subs[0].language, 'en');
    expect(subs[0].name, 'English');
    expect(subs[0].uri, 'https://cdn.example/subs/en.m3u8');
    expect(subs[1].language, 'th');
    expect(subs[1].uri, 'https://cdn.example/th.vtt');
  });

  test('hlsInStreamFetchTarget unwraps the proxy and skips non-playlists', () {
    expect(
      hlsInStreamFetchTarget(
        'http://127.0.0.1:9/hls-proxy?url=${Uri.encodeComponent('https://cdn.example/master.m3u8')}',
      ),
      'https://cdn.example/master.m3u8',
    );
    expect(
      hlsInStreamFetchTarget('https://cdn.example/video.m3u8?token=1'),
      'https://cdn.example/video.m3u8?token=1',
    );
    expect(hlsInStreamFetchTarget('https://cdn.example/video.mp4'), isNull);
  });

  test('isLocalHlsPlayUrl only matches the local proxy', () {
    expect(
      isLocalHlsPlayUrl('http://127.0.0.1:9/hls-proxy?url=https%3A%2F%2Fx'),
      isTrue,
    );
    expect(isLocalHlsPlayUrl('https://cdn.example/master.m3u8'), isFalse);
  });
}
