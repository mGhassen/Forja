import 'package:api/playback/webstreamr_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resolveStreamUrl prefers direct url', () {
    expect(
      WebStreamrService.resolveStreamUrl({
        'url': 'https://cdn.example/stream.m3u8',
        'externalUrl': 'https://other.example',
        'ytId': 'abc',
      }),
      'https://cdn.example/stream.m3u8',
    );
  });

  test('resolveStreamUrl falls back to externalUrl', () {
    expect(
      WebStreamrService.resolveStreamUrl({
        'externalUrl': 'https://embed.example/play',
      }),
      'https://embed.example/play',
    );
  });

  test('resolveStreamUrl maps ytId to YouTube watch URL', () {
    expect(
      WebStreamrService.resolveStreamUrl({'ytId': 'dQw4w9WgXcQ'}),
      'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
    );
  });

  test('resolveStreamUrl returns null when no playable fields', () {
    expect(WebStreamrService.resolveStreamUrl({'name': 'WebStreamr'}), isNull);
  });

  test('multi-stream JSON entries all resolve playable urls', () {
    final streams = [
      {'url': 'https://cdn.example/a.m3u8', 'name': 'A'},
      {'url': 'https://cdn.example/b.m3u8', 'name': 'B'},
      {'ytId': 'xyz123'},
    ];
    final urls = streams
        .map((s) => WebStreamrService.resolveStreamUrl(s))
        .whereType<String>()
        .toList();
    expect(urls, hasLength(3));
    expect(urls.last, contains('youtube.com/watch?v=xyz123'));
  });
}
