import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/live_matches/live_embed_nav.dart';
import 'package:forja/features/live_matches/live_embed_webview_proxy.dart';

void main() {
  test('rewrites relative segment and KEY URI against playlist base', () {
    const body = '''
#EXTM3U
#EXT-X-KEY:METHOD=AES-128,URI="key.key"
#EXTINF:4.0,
seg0.ts
https://cdn.example/abs.ts
''';
    final out = liveEmbedRewriteM3u8Absolute(
      body,
      'https://lb6.strmd.st/secure/tok/1/playlist.m3u8',
    );
    expect(out, contains('URI="https://lb6.strmd.st/secure/tok/1/key.key"'));
    expect(out, contains('https://lb6.strmd.st/secure/tok/1/seg0.ts'));
    expect(out, contains('https://cdn.example/abs.ts'));
  });

  test('through-proxy wraps absolute http(s) lines', () {
    const body = '''
#EXTM3U
#EXTINF:4.0,
https://lb6.strmd.st/secure/tok/1/seg0.ts
''';
    final out = liveEmbedRewriteM3u8ThroughProxy(
      body,
      proxyPrefix: 'http://127.0.0.1:9/u?url=',
    );
    expect(
      out,
      contains(
        'http://127.0.0.1:9/u?url=${Uri.encodeComponent('https://lb6.strmd.st/secure/tok/1/seg0.ts')}',
      ),
    );
  });
}
