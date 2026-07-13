import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/extractors/stream_extractor.dart';

void main() {
  group('StreamExtractor.isPlayableStreamUrl', () {
    test('rejects PWA webmanifest', () {
      expect(
        StreamExtractor.isPlayableStreamUrl(
          'https://anyembed.xyz/manifest.webmanifest',
        ),
        isFalse,
      );
    });

    test('accepts HLS playlists', () {
      expect(
        StreamExtractor.isPlayableStreamUrl(
          'https://cdn.example.com/master.m3u8?token=abc',
        ),
        isTrue,
      );
    });

    test('accepts vixsrc-style playlist endpoint', () {
      expect(
        StreamExtractor.isPlayableStreamUrl(
          'https://vixsrc.to/playlist/772715?token=abc',
        ),
        isTrue,
      );
    });
  });

  group('StreamExtractor.isStrongStreamUrl', () {
    test('webmanifest is not strong', () {
      expect(
        StreamExtractor.isStrongStreamUrl(
          'https://anyembed.xyz/manifest.webmanifest',
        ),
        isFalse,
      );
    });

    test('m3u8 is strong', () {
      expect(
        StreamExtractor.isStrongStreamUrl(
          'https://cdn.example.com/stream/index.m3u8',
        ),
        isTrue,
      );
    });
  });
}
