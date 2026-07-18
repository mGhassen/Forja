import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/extractors/embed_extract_profiles.dart';
import 'package:forja/shared/extractors/core/stream_extractor.dart';
import 'package:forja/shared/extractors/providers/vidsrcsbs/profile.dart';

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

    test('tran-audio mp4 is not strong', () {
      expect(
        StreamExtractor.isStrongStreamUrl(
          'https://bcdn.example.com/tran-audio/20250603/clip.mp4?sign=abc',
        ),
        isFalse,
      );
      expect(
        StreamExtractor.isAudioOnlyStreamUrl(
          'https://bcdn.example.com/tran-audio/20250603/clip.mp4?sign=abc',
        ),
        isTrue,
      );
    });
  });

  group('StreamExtractor.isDeferredStrongStreamUrl', () {
    test('m3u8 ends deferred sniff; progressive mp4 does not', () {
      expect(
        StreamExtractor.isDeferredStrongStreamUrl(
          'https://cdn.example.com/master.m3u8',
        ),
        isTrue,
      );
      expect(
        StreamExtractor.isDeferredStrongStreamUrl(
          'https://cdn.example.com/film.mp4',
        ),
        isFalse,
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
      expect(p.rotateServerChips, isTrue);
      expect(p.rotateBeforeComplete, isTrue);
      expect(
        p.serverChipLabels,
        containsAll(['pro multi', 'cinesrc', 'vlux', 'star']),
      );
      expect(p.serverChipLabels.first, 'pro multi');
    });

    test('vidsrcsbs nested profile sniffs mirrors without dropdown rotation', () {
      expect(vidsrcsbsNestedExtractProfile.rotateServerChips, isFalse);
      expect(vidsrcsbsNestedExtractProfile.rotateBeforeComplete, isFalse);
      expect(vidsrcsbsNestedExtractProfile.forceDirect, isTrue);
      expect(vidsrcsbsNestedExtractProfile.timeout.inSeconds, lessThan(30));
    });

    test('autoembed forces player top-level load (anti-sandbox)', () {
      final p = EmbedExtractProfiles.resolve('autoembed');
      expect(p.id, 'autoembed');
      expect(p.forceDirect, isTrue);
      expect(p.deferUntilStrongStream, isTrue);
      expect(
        p.cdnHostsPreferEmbedReferer.any((h) => h.contains('cloudfabric')),
        isTrue,
      );
    });

    test('2embed forces stream host top-level and rotates servers', () {
      final p = EmbedExtractProfiles.resolve('2embed');
      expect(p.id, '2embed');
      expect(p.forceDirect, isTrue);
      expect(p.deferUntilStrongStream, isTrue);
      expect(p.rotateServerChips, isTrue);
    });

    test('vidsrcwin loads directly and rotates MoviePire servers', () {
      final p = EmbedExtractProfiles.resolve('vidsrcwin');
      expect(p.id, 'vidsrcwin');
      expect(p.forceDirect, isTrue);
      expect(p.deferUntilStrongStream, isTrue);
      expect(p.rotateServerChips, isTrue);
      expect(p.serverChipLabels, containsAll(['alpha', 'blaze']));
    });

    test('unknown provider falls back without borrowing vidlove policy', () {
      final p = EmbedExtractProfiles.resolve('some-new-host');
      expect(p.rotateServerChips, isFalse);
      expect(p.acceptProxyPlaylistBodies, isFalse);
      expect(p.forceDirect, isFalse);
    });
  });
}
