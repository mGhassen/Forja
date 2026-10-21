import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';

void main() {
  group('LocalServerService proxy token', () {
    final service = LocalServerService();

    setUp(() => service.debugConfigure(port: 43123, token: 'abc123'));
    tearDown(() => service.debugConfigure(port: 0, token: ''));

    test('every media route URL carries proxy_token', () {
      final urls = [
        service.getHlsProxyUrl('https://cdn.example/a.m3u8', {'Referer': 'x'}),
        service.getHlsProxyUrl(
          'https://cdn.example/a.m3u8',
          const {},
          stripMode: 'png',
        ),
        service.getTokyProxyUrl('https://u', 'id', 'tok', 'src'),
        service.getComicProxyUrl('https://img'),
        service.getJellyfinProxyUrl('https://jf/stream', 'MediaBrowser Token'),
      ];
      for (final u in urls) {
        final uri = Uri.parse(u);
        expect(uri.host, '127.0.0.1', reason: u);
        expect(uri.port, 43123, reason: u);
        expect(
          uri.queryParameters[LocalServerService.proxyTokenQueryKey],
          'abc123',
          reason: u,
        );
      }
      expect(service.proxyToken, 'abc123');
    });

    test('strip mode survives the token suffix', () {
      final u = Uri.parse(
        service.getHlsProxyUrl(
          'https://cdn.example/a.m3u8',
          const {},
          stripMode: 'png',
        ),
      );
      expect(u.queryParameters['strip'], 'png');
      expect(u.queryParameters['url'], 'https://cdn.example/a.m3u8');
    });

    test('no token → URLs unchanged (older native library)', () {
      service.debugConfigure(port: 43123, token: '');
      final u = service.getComicProxyUrl('https://img');
      expect(u, 'http://127.0.0.1:43123/comic-proxy?url=https%3A%2F%2Fimg');
    });
  });

  group('withProxyTokenOnTranslateUrls', () {
    test('appends token to translate entries only', () {
      final out = withProxyTokenOnTranslateUrls([
        {'url': 'http://localhost:4/subtitlecat-translate?orig=a&tl=fr'},
        {'url': 'https://subtitlecat.example/en.srt'},
        {
          'url':
              'http://localhost:4/subtitlecat-translate?orig=b&proxy_token=z',
        },
      ], 'tok');
      expect(out[0]['url'], endsWith('&proxy_token=tok'));
      expect(out[1]['url'], 'https://subtitlecat.example/en.srt');
      expect(out[2]['url'], endsWith('proxy_token=z'));
    });

    test('empty token is a no-op', () {
      final input = [
        {'url': 'http://localhost:4/subtitlecat-translate?orig=a'},
      ];
      expect(withProxyTokenOnTranslateUrls(input, ''), same(input));
    });
  });
}
