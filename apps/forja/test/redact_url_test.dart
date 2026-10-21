import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/utils/redact_url.dart';

void main() {
  group('redactUrlCredentials', () {
    test('masks userinfo', () {
      expect(
        redactUrlCredentials('https://alice:s3cret@cdn.example/a.m3u8'),
        'https://***@cdn.example/a.m3u8',
      );
    });

    test('masks credential query values, keeps the rest', () {
      final out = redactUrlCredentials(
        'https://cdn.example/a.m3u8?token=abc&password=p&key=k&expires=99',
      );
      expect(out, contains('token=***'));
      expect(out, contains('password=***'));
      expect(out, contains('key=***'));
      expect(out, contains('expires=99'));
      expect(out, isNot(contains('abc')));
    });

    test('masks Xtream user/pass path segments', () {
      expect(
        redactUrlCredentials(
          'http://portal.example:8080/live/bob/hunter2/123.ts',
        ),
        'http://portal.example:8080/live/***/***/123.ts',
      );
      expect(
        redactUrlCredentials('http://portal.example/bob/hunter2/123.m3u8'),
        'http://portal.example/***/***/123.m3u8',
      );
      expect(
        redactUrlCredentials(
          'http://portal.example/get.php?username=bob&password=hunter2&type=m3u',
        ),
        'http://portal.example/get.php?username=***&password=***&type=m3u',
      );
    });

    test('plain stream url is unchanged', () {
      const u = 'https://cdn.example/path/master.m3u8?quality=1080';
      expect(redactUrlCredentials(u), u);
    });

    test('non-http schemes that carry payloads collapse', () {
      expect(redactUrlCredentials('magnet:?xt=urn:btih:abc'), 'magnet:***');
      expect(redactUrlCredentials(''), '');
    });
  });

  group('headers', () {
    test('describeHeaderNames prints names only', () {
      expect(
        describeHeaderNames({'Cookie': 'a=b', 'Authorization': 'Bearer x'}),
        'Cookie, Authorization',
      );
      expect(describeHeaderNames(null), '(none)');
    });

    test('redactHeaderValues masks sensitive values', () {
      final out = redactHeaderValues({
        'Cookie': 'session=abc',
        'Authorization': 'Bearer xyz',
        'Referer': 'https://site.example/?token=t',
        'User-Agent': 'Forja/1',
      });
      expect(out['Cookie'], isNot(contains('abc')));
      expect(out['Authorization'], isNot(contains('xyz')));
      expect(out['Referer'], contains('token=***'));
      expect(out['User-Agent'], 'Forja/1');
    });
  });
}
