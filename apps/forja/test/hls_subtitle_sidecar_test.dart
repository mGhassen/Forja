import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/downloads/hls_subtitle_sidecar.dart';

void main() {
  test('keeps the subtitle group named by the chosen variant', () {
    const master = '''
#EXTM3U
#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="sub-hi",NAME="Hindi",LANGUAGE="hi",URI="hi.m3u8"
#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="sub-en",NAME="English",LANGUAGE="en",URI="en.m3u8"
#EXT-X-STREAM-INF:BANDWIDTH=1000,SUBTITLES="sub-en"
low.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=8000,SUBTITLES="sub-hi"
high.m3u8
''';
    final picked = hlsSubtitleRenditions(
      playlist: master,
      playlistUri: Uri.parse('https://cdn.example/master.m3u8'),
      variantUri: Uri.parse('https://cdn.example/high.m3u8'),
    );
    expect(picked, hasLength(1));
    expect(picked.single.language, 'hi');
    expect(picked.single.uri.toString(), 'https://cdn.example/hi.m3u8');
  });

  test('shifts a reset cue clock and a timestamp map onto one file', () {
    const first = '''
WEBVTT

00:00:00.000 --> 00:00:01.000
Hello
''';
    const mapped = '''
WEBVTT
X-TIMESTAMP-MAP=MPEGTS:90000,LOCAL:00:00:00.000

00:00:00.000 --> 00:00:01.000
There
''';
    final merged = mergeWebVttParts([
      const HlsSubtitleSegmentPart(duration: 2, body: first),
      const HlsSubtitleSegmentPart(duration: 2, body: mapped),
    ]);
    expect(merged, contains('00:00:00.000 --> 00:00:01.000'));
    expect(merged, contains('Hello'));
    expect(merged, contains('00:00:01.000 --> 00:00:02.000'));
    expect(merged, contains('There'));
  });

  test('adds playlist duration when the next segment starts again at zero', () {
    const cue = '''
WEBVTT

00:00:00.000 --> 00:00:01.000
Again
''';
    final merged = mergeWebVttParts([
      const HlsSubtitleSegmentPart(duration: 4, body: cue),
      const HlsSubtitleSegmentPart(duration: 4, body: cue),
    ]);
    expect(merged, contains('00:00:00.000 --> 00:00:01.000'));
    expect(merged, contains('00:00:04.000 --> 00:00:05.000'));
  });
}