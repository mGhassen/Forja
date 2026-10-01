import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/playback/open/engine_auto_play.dart';

void main() {
  group('preferSavedEngineStreamRow', () {
    test('moves matching catalog identity to front', () {
      final rows = [
        {'url': 'https://cdn.example/a.m3u8'},
        {'url': 'https://cdn.example/b.m3u8'},
        {'url': 'https://cdn.example/c.m3u8'},
      ];
      final out = preferSavedEngineStreamRow(
        rows,
        'http://127.0.0.1:9/hls-proxy?url=${Uri.encodeComponent('https://cdn.example/b.m3u8')}',
      );
      expect(out.map((r) => r['url']), [
        'https://cdn.example/b.m3u8',
        'https://cdn.example/a.m3u8',
        'https://cdn.example/c.m3u8',
      ]);
    });

    test('leaves order when no match', () {
      final rows = [
        {'url': 'https://cdn.example/a.m3u8'},
        {'url': 'https://cdn.example/b.m3u8'},
      ];
      expect(
        preferSavedEngineStreamRow(rows, 'https://cdn.example/z.m3u8'),
        rows,
      );
    });
  });
}
