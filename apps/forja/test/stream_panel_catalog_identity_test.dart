import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/controls/player_stream_menu.dart';
import 'package:forja/shared/player/player/utils.dart';
import 'package:rust/rust.dart';

void main() {
  group('durableStreamCatalogUrl', () {
    test('prefers catalog over hls-proxy play URL', () {
      const catalog = 'https://cdn.example/ep.m3u8';
      final proxy =
          'http://127.0.0.1:8787/hls-proxy?strip=png&url=${Uri.encodeComponent(catalog)}';
      expect(
        durableStreamCatalogUrl(
          catalogUrl: catalog,
          sourceUrl: catalog,
          playUrl: proxy,
        ),
        catalog,
      );
    });

    test('unwraps proxy when catalog state was wrongly set to loopback', () {
      const catalog = 'https://cdn.example/ep.m3u8';
      final proxy =
          'http://127.0.0.1:8787/hls-proxy?strip=png&url=${Uri.encodeComponent(catalog)}';
      expect(
        durableStreamCatalogUrl(catalogUrl: proxy, playUrl: proxy),
        catalog,
      );
    });

    test('never returns bare loopback', () {
      expect(
        durableStreamCatalogUrl(
          catalogUrl: 'http://127.0.0.1:9/random',
          playUrl: 'http://127.0.0.1:9/random',
        ),
        isNull,
      );
    });
  });

  group('catalogStreamRowMatchesPlaying', () {
    test('matches catalog row while play URL is proxy', () {
      const catalog = 'https://cdn.example/ep.m3u8';
      final proxy =
          'http://127.0.0.1:8787/hls-proxy?strip=png&url=${Uri.encodeComponent(catalog)}';
      final row = {'url': catalog, 'title': 'Stream'};
      expect(
        catalogStreamRowMatchesPlaying(
          row,
          playUrl: proxy,
          catalogUrl: catalog,
        ),
        isTrue,
      );
    });
  });

  group('catalogStreamRowMatchesSavedProgress', () {
    test('does not match other Videasy quality rows', () {
      const saved =
          'https://moon.peakstorm.top/vd/x/index-s1080p-v1-a1.m3u8';
      const row720 =
          'https://moon.peakstorm.top/vd/x/index-s720p-v1-a1.m3u8';
      expect(
        catalogStreamRowMatchesSavedProgress(
          {'url': row720, '_enginePluginId': 'videasy'},
          savedUrl: saved,
          playingEnginePluginId: 'videasy',
        ),
        isFalse,
      );
      expect(
        catalogStreamRowMatchesSavedProgress(
          {'url': saved, '_enginePluginId': 'videasy'},
          savedUrl: saved,
          playingEnginePluginId: 'videasy',
        ),
        isTrue,
      );
    });

    test('loose playing match would collapse all qualities', () {
      const saved =
          'https://moon.peakstorm.top/vd/x/index-s1080p-v1-a1.m3u8';
      const row720 =
          'https://moon.peakstorm.top/vd/x/index-s720p-v1-a1.m3u8';
      expect(
        catalogStreamRowMatchesPlaying(
          {'url': row720, '_enginePluginId': 'videasy'},
          playUrl: saved,
          catalogUrl: saved,
          playingEnginePluginId: 'videasy',
        ),
        isTrue,
      );
    });
  });

  group('streamSourceMatchesPlaying', () {
    test('matches catalog row while play URL is proxy', () {
      const catalog = 'https://cdn.example/ep.m3u8';
      final proxy =
          'http://127.0.0.1:8787/hls-proxy?strip=png&url=${Uri.encodeComponent(catalog)}';
      final row = StreamSource(
        url: catalog,
        title: 'Stream',
        type: 'hls',
        catalogUrl: catalog,
      );
      expect(
        streamSourceMatchesPlaying(row, playUrl: proxy, catalogUrl: catalog),
        isTrue,
      );
    });

    test(
      'matches catalog row when only play URL is proxy (catalog state empty)',
      () {
        const catalog = 'https://cdn.example/ep.m3u8';
        final proxy =
            'http://127.0.0.1:8787/hls-proxy?strip=png&url=${Uri.encodeComponent(catalog)}';
        final row = StreamSource(url: catalog, title: 'Stream', type: 'hls');
        expect(
          streamSourceMatchesPlaying(row, playUrl: proxy, catalogUrl: null),
          isTrue,
        );
      },
    );

    test('peakstorm child play URL matches master catalog row', () {
      const child = 'https://moon.peakstorm.top/vd/x/index-s1080p-v1-a1.m3u8';
      const master = 'https://moon.peakstorm.top/vd/x/master.m3u8';
      final row = StreamSource(
        url: master,
        title: 'Stream',
        type: 'hls',
        catalogUrl: child,
      );
      expect(
        streamSourceMatchesPlaying(row, playUrl: child, catalogUrl: child),
        isTrue,
      );
    });

    test('does not invent match on unrelated row', () {
      final row = StreamSource(
        url: 'https://cdn.example/other.m3u8',
        title: 'Other',
        type: 'hls',
      );
      expect(
        streamSourceMatchesPlaying(
          row,
          playUrl: 'http://127.0.0.1:8787/hls-proxy?url=https://a/b.m3u8',
          catalogUrl: 'https://cdn.example/ep.m3u8',
        ),
        isFalse,
      );
    });
  });

  group('PlayerStreamMenu.isCurrentSource provider scope', () {
    const catalog = 'https://cdn.example/ep.m3u8';
    final row = StreamSource(
      url: catalog,
      title: 'HLS Stream',
      type: 'hls',
      catalogUrl: catalog,
    );
    final state = PlayerStreamMenuState(
      currentProviderId: 'megaplay',
      sources: [row],
      currentUrl: catalog,
      currentPlayingCatalogUrl: catalog,
      current111477FileUrl: null,
      is111477: false,
      playbackConfirmed: true,
      mediaPlaying: true,
    );

    test('same URL on current provider is playing', () {
      expect(
        PlayerStreamMenu.isCurrentSource(row, state, providerId: 'megaplay'),
        isTrue,
      );
    });

    test('same URL on another provider is not playing', () {
      expect(
        PlayerStreamMenu.isCurrentSource(
          row,
          state,
          providerId: 'vidnest_hianime',
        ),
        isFalse,
      );
    });
  });

  group('catalogSourcesButtonLabel', () {
    final movie = Movie(
      id: 1,
      title: 'Test',
      mediaType: 'movie',
      overview: '',
      posterPath: '',
      backdropPath: '',
      voteAverage: 0,
      releaseDate: '',
    );

    test('uses addon base URL when set', () {
      expect(
        catalogSourcesButtonLabel(
          movie: movie,
          season: null,
          episode: null,
          catalogAddonBaseUrl: 'nuvio:showbox',
        ),
        'Showbox',
      );
    });

    test('falls back to provider id', () {
      expect(
        catalogSourcesButtonLabel(
          movie: movie,
          season: null,
          episode: null,
          activeProvider: 'stremio_direct',
        ),
        'Stremio Direct',
      );
    });
  });
}
