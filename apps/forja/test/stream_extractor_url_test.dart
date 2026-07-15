import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/extractors/embed_extract_profiles.dart';
import 'package:forja/shared/extractors/core/stream_extractor.dart';

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

    test('rejects relative demo placeholders', () {
      expect(StreamExtractor.isPlayableStreamUrl('/demo-video.mp4'), isFalse);
      expect(
        StreamExtractor.isPlayableStreamUrl(
          'https://cdn.example/demo-video.mp4',
        ),
        isFalse,
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

  group('EmbedExtractProfiles', () {
    test('every required template provider has a catalog entry', () {
      for (final id in EmbedExtractProfiles.requiredTemplateIds) {
        expect(
          EmbedExtractProfiles.catalog.containsKey(id),
          isTrue,
          reason: 'missing EmbedExtractProfile for $id',
        );
      }
    });

    test('vidlove rotates chips; vidfast does not', () {
      final love = EmbedExtractProfiles.resolve('vidlove');
      final fast = EmbedExtractProfiles.resolve('vidfast');
      expect(love.rotateServerChips, isTrue);
      expect(love.serverChipLabels, contains('neta'));
      expect(love.forceDirect, isTrue);
      expect(fast.rotateServerChips, isFalse);
      expect(fast.forceDirect, isFalse);
    });

    test('vidsrcsbs accepts proxy playlist bodies', () {
      final p = EmbedExtractProfiles.resolve('vidsrcsbs');
      expect(p.acceptProxyPlaylistBodies, isTrue);
      expect(p.forceDirect, isTrue);
      expect(p.deferUntilStrongStream, isTrue);
    });

    test('unknown provider falls back without borrowing vidlove policy', () {
      final p = EmbedExtractProfiles.resolve('some-new-host');
      expect(p.rotateServerChips, isFalse);
      expect(p.acceptProxyPlaylistBodies, isFalse);
      expect(p.forceDirect, isFalse);
    });
  });
}
