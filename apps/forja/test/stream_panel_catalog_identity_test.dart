import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/playback/playback_stream_guards.dart';
import 'package:forja/shared/player/controls/player_stream_menu.dart';
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
        streamSourceMatchesPlaying(
          row,
          playUrl: proxy,
          catalogUrl: catalog,
        ),
        isTrue,
      );
    });

    test('matches catalog row when only play URL is proxy (catalog state empty)',
        () {
      const catalog = 'https://cdn.example/ep.m3u8';
      final proxy =
          'http://127.0.0.1:8787/hls-proxy?strip=png&url=${Uri.encodeComponent(catalog)}';
      final row = StreamSource(
        url: catalog,
        title: 'Stream',
        type: 'hls',
      );
      expect(
        streamSourceMatchesPlaying(
          row,
          playUrl: proxy,
          catalogUrl: null,
        ),
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
        PlayerStreamMenu.isCurrentSource(
          row,
          state,
          providerId: 'megaplay',
        ),
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
}
