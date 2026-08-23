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

    test('vixsrc playlist endpoint looks like HLS master', () {
      expect(
        StreamExtractor.looksLikeHlsMasterPlaylist(
          'https://vixsrc.to/playlist/772715?token=abc',
        ),
        isTrue,
      );
      expect(
        StreamExtractor.looksLikeHlsMasterPlaylist(
          'https://cdn.example.com/master.m3u8?token=abc',
        ),
        isTrue,
      );
      expect(
        StreamExtractor.looksLikeHlsMasterPlaylist(
          'https://cdn.example.com/rendition/1080.m3u8?token=abc',
        ),
        isFalse,
      );
    });

    test('selectBestPlayableUrl prefers master over media variant', () {
      final pick = StreamExtractor.selectBestPlayableUrl([
        'https://cdn.example.com/rendition/1080.m3u8?token=abc',
        'https://vixsrc.to/playlist/772715?token=abc',
      ]);
      expect(pick, 'https://vixsrc.to/playlist/772715?token=abc');
    });

    test('accepts VidLove signed /api?d=&internal_token= media proxy', () {
      const url =
          'https://cdn.example.com/api?d=abc123&internal_token=v1.moviebox.x';
      expect(StreamExtractor.isPlayableStreamUrl(url), isTrue);
      expect(StreamExtractor.isOpaqueSignedMediaProxyUrl(url), isTrue);
      expect(
        StreamExtractor.isOpaqueSignedMediaProxyUrl(
          'https://cdn.example.com/api?d=only',
        ),
        isFalse,
      );
    });

    test('accepts Cinesrc ice proxy ?m3u8= token URLs', () {
      const url =
          'https://ice.bright67.online/?m3u8=51e94ee741680a43&h=d6bb5033';
      expect(StreamExtractor.isPlayableStreamUrl(url), isTrue);
      expect(StreamExtractor.isDeferredStrongStreamUrl(url), isTrue);
      expect(
        StreamExtractor.isPlayableStreamUrl(
          'https://ice.bright67.online/?seg=abc&h=d6bb',
        ),
        isFalse,
      );
    });

    test('VidFast /w/uuid path is embed proxy playlist URL', () {
      const url =
          'https://vidfast.vc/w/2997559f-eb63-54f1-bf57-dfa63248e8aa/token';
      // Not playable by suffix alone — needs confirmed playlist body.
      expect(StreamExtractor.isPlayableStreamUrl(url), isFalse);
    });

    test('rejects HLS fMP4 init/segments', () {
      expect(
        StreamExtractor.isPlayableStreamUrl(
          'https://echogate.top/vd/x/init-s1080p-v1-a1.mp4',
        ),
        isFalse,
      );
      expect(
        StreamExtractor.isPlayableStreamUrl(
          'https://echogate.top/vd/x/seg-1-s1080p-v1-a1.m4s',
        ),
        isFalse,
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

    test('VidLove opaque media proxy ends deferred sniff', () {
      expect(
        StreamExtractor.isDeferredStrongStreamUrl(
          'https://cdn.example.com/api?d=abc&internal_token=v1.x',
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

    test('vidlove rotates chips; vidfast loads direct + defers for HLS.js', () {
      final love = EmbedExtractProfiles.resolve('vidlove');
      final fast = EmbedExtractProfiles.resolve('vidfast');
      expect(love.rotateServerChips, isTrue);
      expect(
        love.serverChipLabels,
        containsAll(['moviebox', 'vidapi', 'neta', 'gogo']),
      );
      expect(love.forceDirect, isTrue);
      expect(love.acceptProxyPlaylistBodies, isTrue);
      expect(fast.rotateServerChips, isTrue);
      expect(fast.forceDirect, isTrue);
      expect(fast.deferUntilStrongStream, isTrue);
      expect(fast.acceptProxyPlaylistBodies, isTrue);
      expect(fast.timeout.inSeconds, 90);
    });

    test('vidzee waits for CF, forceDirect, rotates servers', () {
      final p = EmbedExtractProfiles.resolve('vidzee');
      expect(p.forceDirect, isTrue);
      expect(p.deferUntilStrongStream, isTrue);
      expect(p.rotateServerChips, isTrue);
      expect(p.waitForCloudflare, isTrue);
      expect(p.timeout.inSeconds, 90);
      expect(p.cdnHostsPreferEmbedReferer, containsAll(['1shows', 'vidzee']));
    });

    test('vidrock rotates Servers list chips and defers for HLS.js', () {
      final p = EmbedExtractProfiles.resolve('vidrock');
      expect(p.forceDirect, isTrue);
      expect(p.deferUntilStrongStream, isTrue);
      expect(p.rotateServerChips, isTrue);
      expect(p.acceptProxyPlaylistBodies, isTrue);
      expect(p.serverChipLabels, isEmpty);
      expect(p.timeout.inSeconds, 90);
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

    test('vidsrcsbs nested profile rotates each mirror Servers chips', () {
      expect(vidsrcsbsNestedExtractProfile.rotateServerChips, isTrue);
      expect(vidsrcsbsNestedExtractProfile.rotateBeforeComplete, isFalse);
      expect(vidsrcsbsNestedExtractProfile.forceDirect, isTrue);
      expect(vidsrcsbsNestedExtractProfile.serverChipLabels, isEmpty);
      expect(vidsrcsbsNestedExtractProfile.timeout.inSeconds, 75);
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

    test('vixsrc prefers HLS master for demuxed audio', () {
      final p = EmbedExtractProfiles.resolve('vixsrc');
      expect(p.id, 'vixsrc');
      expect(p.preferHlsMaster, isTrue);
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
