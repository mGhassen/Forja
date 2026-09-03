import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/catalog/kit/sources/live_schedule/play/live_embed_webview_proxy.dart';

void main() {
  group('liveEmbedRewriteM3u8Absolute', () {
    test('resolves relative segment URIs', () {
      const body = '#EXTM3U\n/seg.ts\n';
      final out = liveEmbedRewriteM3u8Absolute(
        body,
        'https://cdn.example/playlist.m3u8',
      );
      expect(out, contains('https://cdn.example/seg.ts'));
    });
  });

  group('liveEmbedRewriteM3u8ThroughProxy', () {
    test('wraps https lines with proxy prefix', () {
      const body = '#EXTM3U\nhttps://cdn.example/seg.ts\n';
      final out = liveEmbedRewriteM3u8ThroughProxy(
        body,
        proxyPrefix: 'http://127.0.0.1:9/u?url=',
      );
      expect(out, contains('http://127.0.0.1:9/u?url='));
    });
  });
}
