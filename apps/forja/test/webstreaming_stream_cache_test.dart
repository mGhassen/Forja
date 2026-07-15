import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/playback/playback_stream_guards.dart';
import 'package:forja/shared/playback/webstreaming_stream_cache.dart';
import 'package:rust/rust.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('isWebStreamProviderId', () {
    test('accepts catalog web extractors', () {
      expect(isWebStreamProviderId('videasy'), isTrue);
      expect(isWebStreamProviderId('vidsrc'), isTrue);
    });

    test('rejects playback modes and nuvio scrapers', () {
      expect(isWebStreamProviderId('stremio_direct'), isFalse);
      expect(isWebStreamProviderId('amri'), isFalse);
      expect(isWebStreamProviderId('torrent'), isFalse);
      expect(isWebStreamProviderId('nuvio:torrentio'), isFalse);
      expect(isWebStreamProviderId(''), isFalse);
    });
  });

  group('isCatalogSourcesMode', () {
    test('matches Stremio Direct, torrent, Amri, and Nuvio scrapers', () {
      expect(isCatalogSourcesMode('stremio_direct'), isTrue);
      expect(isCatalogSourcesMode('torrent'), isTrue);
      expect(isCatalogSourcesMode('amri'), isTrue);
      expect(isCatalogSourcesMode('nuvio:showbox'), isTrue);
    });

    test('rejects web extractors and empty', () {
      expect(isCatalogSourcesMode('videasy'), isFalse);
      expect(isCatalogSourcesMode(null), isFalse);
      expect(isCatalogSourcesMode(''), isFalse);
    });
  });

  group('WebstreamingStreamCache.cacheKey', () {
    test('movie keys ignore season/episode', () {
      expect(
        WebstreamingStreamCache.cacheKey(
          tmdbId: 42,
          mediaType: 'movie',
          season: 9,
          episode: 9,
        ),
        'movie:42',
      );
    });

    test('tv keys normalize 0-based inputs to season 1 episode 1', () {
      expect(
        WebstreamingStreamCache.cacheKey(
          tmdbId: 99,
          mediaType: 'tv',
          season: 0,
          episode: 0,
        ),
        'tv:99:S1:E1',
      );
    });

    test('cacheKeyFromProgress matches explicit tv episode', () {
      expect(
        WebstreamingStreamCache.cacheKeyFromProgress(
          tmdbId: 99,
          mediaType: 'tv',
          season: 2,
          episode: 5,
        ),
        'tv:99:S2:E5',
      );
    });
  });

  group('WebstreamingStreamCache validation', () {
    test('rejects magnet URLs', () {
      expect(
        WebstreamingStreamCache.isValidHit(
          WebstreamingCacheHit(
            providerId: 'videasy',
            sources: [
              StreamSource(
                url: 'magnet:?xt=urn:btih:abc',
                title: 'bad',
                type: 'video',
              ),
            ],
          ),
        ),
        isFalse,
      );
    });

    test('rejects placeholder relative URLs', () {
      expect(
        WebstreamingStreamCache.isValidHit(
          WebstreamingCacheHit(
            providerId: 'videasy',
            sources: [
              StreamSource(
                url: '/demo-video.mp4',
                title: 'placeholder',
                type: 'mp4',
              ),
            ],
          ),
        ),
        isFalse,
      );
    });

    test('rejects loopback seek-proxy URLs', () {
      expect(
        WebstreamingStreamCache.isValidHit(
          WebstreamingCacheHit(
            providerId: 'service111477',
            sources: [
              StreamSource(
                url: 'http://127.0.0.1:51736/',
                title: 'proxy',
                type: 'mp4',
              ),
            ],
          ),
        ),
        isFalse,
      );
    });

    test('rejects stremio_direct provider ids', () {
      expect(
        WebstreamingStreamCache.isValidHit(
          WebstreamingCacheHit(
            providerId: 'stremio_direct',
            sources: [
              StreamSource(
                url: 'https://cdn.example/stremio.m3u8',
                title: 'stremio',
                type: 'hls',
              ),
            ],
          ),
        ),
        isFalse,
      );
    });

    test('rejects amri and torrent mode ids', () {
      expect(
        WebstreamingStreamCache.isValidHit(
          WebstreamingCacheHit(
            providerId: 'amri',
            sources: [
              StreamSource(
                url: 'https://cdn.example/amri.m3u8',
                title: 'amri',
                type: 'hls',
              ),
            ],
          ),
        ),
        isFalse,
      );
      expect(
        WebstreamingStreamCache.isValidHit(
          WebstreamingCacheHit(
            providerId: 'torrent',
            sources: [
              StreamSource(
                url: 'https://cdn.example/file.mp4',
                title: 'torrent',
                type: 'mp4',
              ),
            ],
          ),
        ),
        isFalse,
      );
    });

    test('readSession drops stremio_direct poisoned entries', () {
      WebstreamingStreamCache.writeSession(
        'tv:94997:S1:E1',
        WebstreamingCacheHit(
          providerId: 'stremio_direct',
          sources: [
            StreamSource(
              url: 'https://cdn.example/hotd.m3u8',
              title: 'stremio_direct',
              type: 'hls',
            ),
          ],
        ),
      );
      expect(WebstreamingStreamCache.readSession('tv:94997:S1:E1'), isNull);
    });

    test('accepts direct hls URLs', () {
      expect(
        WebstreamingStreamCache.isValidHit(
          WebstreamingCacheHit(
            providerId: 'videasy',
            sources: [
              StreamSource(
                url: 'https://cdn.example/index.m3u8',
                title: 'main',
                type: 'hls',
              ),
            ],
          ),
        ),
        isTrue,
      );
    });

    test('readSession drops poisoned session entries', () {
      WebstreamingStreamCache.writeSession(
        'tv:1:S1:E1',
        WebstreamingCacheHit(
          providerId: 'nuvio:torrentio',
          sources: [
            StreamSource(
              url: 'magnet:?xt=urn:btih:deadbeef',
              title: 'torrent',
              type: 'video',
            ),
          ],
        ),
      );
      expect(WebstreamingStreamCache.readSession('tv:1:S1:E1'), isNull);
    });

    test('clearAll removes session and disk cache', () async {
      WebstreamingStreamCache.writeSession(
        'movie:7',
        WebstreamingCacheHit(
          providerId: 'videasy',
          sources: [
            StreamSource(
              url: 'https://cdn.example/main.m3u8',
              title: 'main',
              type: 'hls',
            ),
          ],
        ),
      );
      await WebstreamingStreamCache.write(
        'movie:7',
        WebstreamingCacheHit(
          providerId: 'videasy',
          sources: [
            StreamSource(
              url: 'https://cdn.example/main.m3u8',
              title: 'main',
              type: 'hls',
            ),
          ],
        ),
      );
      await WebstreamingStreamCache.clearAll();
      expect(WebstreamingStreamCache.readSession('movie:7'), isNull);
      expect(await WebstreamingStreamCache.read('movie:7'), isNull);
    });
  });
}
