import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/player/utils.dart';

void main() {
  group('normalizePlaybackStreamUrl', () {
    test('strips trailing slash after media extension', () {
      expect(
        normalizePlaybackStreamUrl(
          'https://cdn.example/get_file/x/video.mp4/',
        ),
        'https://cdn.example/get_file/x/video.mp4',
      );
      expect(
        normalizePlaybackStreamUrl('https://cdn.example/a.m3u8///'),
        'https://cdn.example/a.m3u8',
      );
    });

    test('leaves normal urls alone', () {
      expect(
        normalizePlaybackStreamUrl('https://cdn.example/video.mp4'),
        'https://cdn.example/video.mp4',
      );
      expect(
        normalizePlaybackStreamUrl('https://cdn.example/path/'),
        'https://cdn.example/path/',
      );
    });
  });

  group('resolvePlaybackHttpHeaders', () {
    test('always includes browser User-Agent', () {
      final h = resolvePlaybackHttpHeaders(null);
      expect(h['User-Agent'], contains('Mozilla/5.0'));
      expect(h['User-Agent'], contains('KHTML, like Gecko'));
    });

    test('preserves extractor Referer and fills Origin', () {
      final h = resolvePlaybackHttpHeaders({
        'Referer': 'https://fsst.example/',
        'User-Agent': 'CustomUA',
      });
      expect(h['User-Agent'], 'CustomUA');
      expect(h['Referer'], 'https://fsst.example/');
      expect(h['Origin'], 'https://fsst.example');
    });

    test('derives Referer from stream URL when missing', () {
      final h = resolvePlaybackHttpHeaders(
        null,
        streamUrl: 'https://cdn.example/file.mp4',
      );
      expect(h['Referer'], 'https://cdn.example/');
      expect(h['Origin'], 'https://cdn.example');
    });

    test('keeps extractor Referer over CDN-host fallback', () {
      final h = resolvePlaybackHttpHeaders(
        {'Referer': 'https://embed.example/play'},
        streamUrl: 'https://cdn.other/file.mp4',
      );
      expect(h['Referer'], 'https://embed.example/play');
      expect(h['Origin'], 'https://embed.example');
    });

    test('forwards Cookie and Authorization unchanged', () {
      final h = resolvePlaybackHttpHeaders({
        'Cookie': 'sid=abc',
        'Authorization': 'Bearer tok',
      });
      expect(h['Cookie'], 'sid=abc');
      expect(h['Authorization'], 'Bearer tok');
      expect(h['User-Agent'], contains('Mozilla/5.0'));
    });

    test('canonicalizes lowercase referer/user-agent keys', () {
      final h = resolvePlaybackHttpHeaders({
        'referer': 'https://embed.example/',
        'user-agent': 'Custom/1.0',
        'origin': 'https://embed.example',
      });
      expect(h['Referer'], 'https://embed.example/');
      expect(h['User-Agent'], 'Custom/1.0');
      expect(h['Origin'], 'https://embed.example');
      expect(h.containsKey('referer'), isFalse);
      expect(h.containsKey('user-agent'), isFalse);
      expect(h.containsKey('origin'), isFalse);
    });
  });
}
