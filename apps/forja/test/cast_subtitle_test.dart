import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/casting/casting.dart';
import 'package:media_kit/media_kit.dart';

void main() {
  test('merges an HLS in-stream subtitle playlist into external WebVTT', () async {
    final fetched = <String>[];
    final track = SubtitleTrack.uri(
      'https://cdn.example/subs/en.m3u8',
      title: 'English',
      language: 'en',
    );
    final result = await castSubtitleFor(
      track,
      delaySeconds: 1,
      fetchText: (uri) async {
        fetched.add(uri.toString());
        if (uri.path.endsWith('en.m3u8')) {
          return '''
#EXTM3U
#EXT-X-TARGETDURATION:2
#EXTINF:2.0,
seg0.vtt
#EXTINF:2.0,
seg1.vtt
''';
        }
        if (uri.path.endsWith('seg0.vtt')) {
          return '''
WEBVTT

00:00:00.000 --> 00:00:01.000
Hello
''';
        }
        return '''
WEBVTT

00:00:00.000 --> 00:00:01.000
There
''';
      },
    );
    expect(result.kind, CastSubtitleKind.external);
    expect(result.language, 'en');
    expect(result.name, 'English');
    expect(result.vtt, contains('00:00:01.000 --> 00:00:02.000'));
    expect(result.vtt, contains('Hello'));
    expect(result.vtt, contains('00:00:03.000 --> 00:00:04.000'));
    expect(result.vtt, contains('There'));
    expect(fetched, [
      'https://cdn.example/subs/en.m3u8',
      'https://cdn.example/subs/seg0.vtt',
      'https://cdn.example/subs/seg1.vtt',
    ]);
  });

  test('keeps plain SRT/VTT as external without treating them as playlists', () async {
    final track = SubtitleTrack.uri(
      'https://cdn.example/en.vtt',
      title: 'English',
      language: 'en',
    );
    final result = await castSubtitleFor(
      track,
      fetchText: (_) async => 'WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nHi\n',
    );
    expect(result.kind, CastSubtitleKind.external);
    expect(result.vtt, contains('00:00:01.000 --> 00:00:02.000'));
    expect(result.vtt, contains('Hi'));
  });

  test('marks ASS and empty playlists unsupported', () async {
    final ass = await castSubtitleFor(
      SubtitleTrack.data('[Script Info]\nTitle: x', title: 'ASS'),
    );
    expect(ass.kind, CastSubtitleKind.unsupported);

    final emptyPlaylist = await castSubtitleFor(
      SubtitleTrack.uri('https://cdn.example/empty.m3u8'),
      fetchText: (_) async => '#EXTM3U\n#EXT-X-TARGETDURATION:2\n',
    );
    expect(emptyPlaylist.kind, CastSubtitleKind.unsupported);
  });
}
