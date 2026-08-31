import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/stream_crypto.dart';

void main() {
  group('StreamCrypto.decrypt', () {
    test('round-trips mvm1 JSON', () {
      const json = '{"sources":[{"url":"https://cdn.example/index.m3u8"}]}';
      const seed = 'test-seed-abc';
      const mediaId = '496243';
      final payload = StreamCrypto.encryptForTest(json, seed, mediaId);
      expect(StreamCrypto.decrypt(payload, seed, mediaId), json);
    });

    test('wrong seed fails magic', () {
      const json = '{"sources":[]}';
      final payload = StreamCrypto.encryptForTest(json, 'seed-a', '550');
      expect(
        () => StreamCrypto.decrypt(payload, 'seed-b', '550'),
        throwsA(isA<FormatException>()),
      );
    });

    test('garbage payload throws', () {
      expect(
        () => StreamCrypto.decrypt('!!!not-b64!!!', 'seed', '1'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => StreamCrypto.decrypt('', 'seed', '1'),
        throwsA(isA<FormatException>()),
      );
    });

    test('invalid media id throws', () {
      expect(
        () => StreamCrypto.decrypt('YWJjZA', 'seed', 'not-a-number'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('StreamCrypto.isPlayerUrl', () {
    test('accepts videasy.to / videasy.net player hosts', () {
      expect(
        StreamCrypto.isPlayerUrl('https://player.videasy.net/movie/496243'),
        isTrue,
      );
      expect(
        StreamCrypto.isPlayerUrl(
          'https://player.videasy.to/tv/1399/1/1',
        ),
        isTrue,
      );
    });

    test('rejects cinesrc / nxsha nested embeds', () {
      expect(
        StreamCrypto.isPlayerUrl(
          'https://cinesrc.st/embed/movie/496243',
        ),
        isFalse,
      );
      expect(
        StreamCrypto.isPlayerUrl(
          'https://web.nxsha.app/embed/movie/496243?server=AwsPly',
        ),
        isFalse,
      );
    });

    test('accepts configured origin host', () {
      expect(
        StreamCrypto.isPlayerUrl(
          'https://player.example.invalid/movie/1',
          configuredOrigin: 'https://player.example.invalid',
        ),
        isTrue,
      );
    });
  });
}
