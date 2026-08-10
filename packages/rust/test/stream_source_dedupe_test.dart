import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';

void main() {
  test('dedupeStreamSources collapses duplicate urls', () {
    final sources = [
      StreamSource(url: 'https://cdn/a.mp4', title: 'A', type: 'video'),
      StreamSource(url: 'https://cdn/a.mp4', title: 'A copy', type: 'video'),
      StreamSource(url: 'https://cdn/b.m3u8', title: 'B', type: 'video'),
    ];
    final deduped = dedupeStreamSources(sources);
    expect(deduped, hasLength(2));
    expect(deduped.first.url, 'https://cdn/b.m3u8');
    expect(deduped.last.url, 'https://cdn/a.mp4');
  });

  test('dedupeStreamSources deprioritizes h265', () {
    final sources = [
      StreamSource(
        url: 'https://cdn/resource/h265/x.mp4',
        title: 'HEVC',
        type: 'video',
      ),
      StreamSource(
        url: 'https://cdn/resource/h264/x.mp4',
        title: 'H264',
        type: 'video',
      ),
    ];
    final deduped = dedupeStreamSources(sources);
    expect(deduped.first.url, contains('h264'));
  });

  test('StreamSource toJson/fromJson round-trips headers', () {
    final source = StreamSource(
      url: 'https://cdn/a.m3u8',
      title: '1080p',
      type: 'hls',
      headers: {'Referer': 'https://example.com', 'User-Agent': 'Forja'},
    );
    final restored = StreamSource.fromJson(source.toJson());
    expect(restored.url, source.url);
    expect(restored.title, source.title);
    expect(restored.type, source.type);
    expect(restored.headers, source.headers);
  });
}
