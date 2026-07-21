import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/telemetry/telemetry.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  group('scrubText', () {
    test('redacts https URLs to host only', () {
      final out = scrubText(
        'failed https://cdn.example.com/hls/abc123/index.m3u8?token=secret',
      );
      expect(out, contains('https://cdn.example.com/[redacted]'));
      expect(out, isNot(contains('token=secret')));
      expect(out, isNot(contains('abc123')));
    });

    test('redacts magnets', () {
      final out = scrubText(
        'open magnet:?xt=urn:btih:abcdef0123456789&dn=show',
      );
      expect(out, contains('magnet:[redacted]'));
      expect(out, isNot(contains('btih')));
    });

    test('redacts jwt-shaped strings', () {
      const jwt =
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0In0.signature';
      final out = scrubText('auth $jwt ok');
      expect(out, contains('[jwt-redacted]'));
      expect(out, isNot(contains('eyJhbGci')));
    });

    test('redacts authorization-style assignments', () {
      final out = scrubText('Authorization: Bearer abc.def.ghi');
      expect(out.toLowerCase(), contains('authorization:[redacted]'));
      expect(out, isNot(contains('Bearer')));
    });
  });

  group('scrubEvent', () {
    test('scrubs exception values and request url', () {
      final event = SentryEvent(
        exceptions: [
          SentryException(
            type: 'StateError',
            value: 'play https://stream.host/path?key=1',
          ),
        ],
        request: SentryRequest(
          url: 'https://api.host/v1/play?jwt=eyJhbGciOiJ.x.y',
          headers: const {
            'Authorization': 'Bearer secret',
            'Accept': 'application/json',
          },
        ),
      );

      final scrubbed = scrubEvent(event, Hint());
      expect(scrubbed, isNotNull);
      expect(
        scrubbed!.exceptions!.single.value,
        contains('https://stream.host/[redacted]'),
      );
      expect(scrubbed.request!.url, 'https://api.host/[redacted]');
      expect(scrubbed.request!.headers.containsKey('Authorization'), isFalse);
      expect(scrubbed.request!.headers['Accept'], 'application/json');
    });
  });

  group('Telemetry gate', () {
    test('inactive without init', () {
      expect(Telemetry.isActive, isFalse);
    });

    test('captureError no-ops when inactive', () async {
      await Telemetry.captureError(StateError('https://leak.example/x'));
    });
  });
}
