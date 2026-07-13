import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/playback/playback_engine.dart';
import 'package:rust/rust.dart';

void main() {
  test('PlaybackEngine dedupes sources by url', () {
    final sources = [
      StreamSource(url: 'https://a.m3u8', title: 'A', type: 'hls'),
      StreamSource(url: 'https://a.m3u8', title: 'B', type: 'hls'),
      StreamSource(url: 'https://b.m3u8', title: 'C', type: 'hls'),
    ];
    final out = PlaybackEngine.dedupeSourcesByUrl(sources);
    expect(out.length, 2);
    expect(out.first.url, 'https://a.m3u8');
  });
}
