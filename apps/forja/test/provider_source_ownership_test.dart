import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/playback/probe/playback_stream_guards.dart';
import 'package:forja/shared/player/controls/sources/stream/player_stream_menu.dart';
import 'package:rust/rust.dart';

void main() {
  group('sourcesOwnedByProvider', () {
    test('keeps rows stamped for the bucket', () {
      final rows = [
        StreamSource(
          url: 'https://cdn/a.m3u8',
          title: 'Mirror · 2160p',
          type: 'hls',
          providerId: 'provider-a',
        ),
        StreamSource(
          url: 'https://cdn/b.m3u8',
          title: 'Mirror · playhq',
          type: 'hls',
          providerId: 'provider-a',
        ),
      ];
      final owned = sourcesOwnedByProvider('provider-a', rows);
      expect(owned, hasLength(2));
    });

    test('drops rows stamped for another provider', () {
      final rows = [
        StreamSource(
          url: 'https://cdn/a.m3u8',
          title: 'Mirror · 2160p',
          type: 'hls',
          providerId: 'provider-a',
        ),
      ];
      expect(sourcesOwnedByProvider('provider-b', rows), isEmpty);
    });

    test('drops foreign display-label titles when restamped', () {
      // Display label comes from StreamProviderDisplay — title "Vidnest"
      // under another bucket is foreign even if providerId was restamped.
      final rows = [
        StreamSource(
          url: 'https://cdn/a.mp4',
          title: 'Vidnest',
          type: 'mp4',
          providerId: 'vidsrcwin',
        ),
        StreamSource(
          url: 'https://cdn/c.m3u8',
          title: 'Own row',
          type: 'hls',
          providerId: 'vidsrcwin',
        ),
      ];
      final owned = sourcesOwnedByProvider('vidsrcwin', rows);
      expect(owned, hasLength(1));
      expect(owned.first.title, 'Own row');
    });

    test('stamps bucket id on untagged survivors', () {
      final rows = [
        StreamSource(
          url: 'https://cdn/x.m3u8',
          title: 'Stream',
          type: 'hls',
        ),
      ];
      final owned = sourcesOwnedByProvider('provider-a', rows);
      expect(owned, hasLength(1));
      expect(owned.first.providerId, 'provider-a');
    });
  });

  group('preferFullerProviderSources', () {
    test('keeps fuller cache when live collapsed to one stream', () {
      final a = StreamSource(
        url: 'https://cdn/a.m3u8',
        title: 'Alpha',
        type: 'hls',
        providerId: 'provider-a',
      );
      final b = StreamSource(
        url: 'https://cdn/b.m3u8',
        title: 'Blaze',
        type: 'hls',
        providerId: 'provider-a',
      );
      final fuller = preferFullerProviderSources(
        providerId: 'provider-a',
        live: [a],
        cached: [a, b],
      );
      expect(fuller, hasLength(2));
      expect(fuller.map((s) => s.url), [
        'https://cdn/a.m3u8',
        'https://cdn/b.m3u8',
      ]);
    });
  });

  group('PlayerStreamMenu.sourcesForProvider', () {
    test('current server keeps cache siblings after live shrink', () {
      final a = StreamSource(
        url: 'https://cdn/a.m3u8',
        title: 'Alpha',
        type: 'hls',
        providerId: 'provider-a',
      );
      final b = StreamSource(
        url: 'https://cdn/b.m3u8',
        title: 'Blaze',
        type: 'hls',
        providerId: 'provider-a',
      );
      final state = PlayerStreamMenuState(
        currentProviderId: 'provider-a',
        sources: [a],
        currentUrl: a.url,
        currentPlayingCatalogUrl: a.url,
        current111477FileUrl: null,
        is111477: false,
        playbackConfirmed: true,
        mediaPlaying: true,
      );
      expect(
        PlayerStreamMenu.sourcesForProvider(
          providerId: 'provider-a',
          state: state,
          cache: {
            'provider-a': [a, b],
          },
        ),
        hasLength(2),
      );
    });

    test('other bucket does not show foreign-stamped cache poison', () {
      final owned = StreamSource(
        url: 'https://cdn/a.m3u8',
        title: 'Mirror · 2160p',
        type: 'hls',
        providerId: 'provider-a',
      );
      final state = PlayerStreamMenuState(
        currentProviderId: 'provider-a',
        sources: [owned],
        currentUrl: owned.url,
        currentPlayingCatalogUrl: owned.url,
        current111477FileUrl: null,
        is111477: false,
        playbackConfirmed: true,
        mediaPlaying: true,
      );
      final cache = <String, List<StreamSource>>{
        'provider-a': [owned],
        // Poison: same rows wrongly stored under another bucket.
        'provider-b': [owned],
      };
      expect(
        PlayerStreamMenu.sourcesForProvider(
          providerId: 'provider-a',
          state: state,
          cache: cache,
        ),
        hasLength(1),
      );
      expect(
        PlayerStreamMenu.sourcesForProvider(
          providerId: 'provider-b',
          state: state,
          cache: cache,
        ),
        isEmpty,
      );
    });
  });
}
