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

  test('isLocalHlsPlayUrl only matches the local proxy', () {
    expect(
      isLocalHlsPlayUrl('http://127.0.0.1:9/hls-proxy?url=https%3A%2F%2Fx'),
      isTrue,
    );
    expect(isLocalHlsPlayUrl('https://cdn.example/master.m3u8'), isFalse);
  });
}
