import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/playback/webstreaming_stream_cache.dart';
import 'package:rust/rust.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
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
