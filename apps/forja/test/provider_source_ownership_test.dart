import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/playback/playback_stream_guards.dart';
import 'package:forja/shared/player/controls/player_stream_menu.dart';
import 'package:rust/rust.dart';

void main() {
  group('hasVideasyMirrorTitle', () {
    test('matches Servers-tab labels', () {
      expect(hasVideasyMirrorTitle('Yoru · 2160p'), isTrue);
      expect(hasVideasyMirrorTitle('Breach · playhq'), isTrue);
      expect(hasVideasyMirrorTitle('Cypher · 1080p'), isTrue);
      expect(hasVideasyMirrorTitle('Primary'), isFalse);
      expect(hasVideasyMirrorTitle('1080p'), isFalse);
    });
  });

  group('sourcesOwnedByProvider', () {
    final videasyRows = [
      StreamSource(
        url: 'https://cdn/a.m3u8',
        title: 'Yoru · 2160p',
        type: 'hls',
        providerId: 'videasy',
      ),
      StreamSource(
        url: 'https://cdn/b.m3u8',
        title: 'Breach · playhq',
        type: 'hls',
        providerId: 'videasy',
      ),
    ];

    test('keeps Videasy rows under videasy', () {
      final owned = sourcesOwnedByProvider('videasy', videasyRows);
      expect(owned, hasLength(2));
    });

    test('drops Videasy rows under vidsrc / VSEmbed', () {
      final owned = sourcesOwnedByProvider('vidsrc', videasyRows);
      expect(owned, isEmpty);
    });

    test('drops foreign providerId even without Videasy title', () {
      final rows = [
        StreamSource(
          url: 'https://cdn/x.m3u8',
          title: 'Stream',
          type: 'hls',
          providerId: 'videasy',
        ),
      ];
      expect(sourcesOwnedByProvider('vidsrc', rows), isEmpty);
    });

    test('drops Vidnest-titled rows under VidSrc', () {
      final rows = [
        StreamSource(
          url: 'https://cdn/a.mp4',
          title: 'Vidnest',
          type: 'mp4',
          providerId: 'vidsrcwin',
        ),
        StreamSource(
          url: 'https://cdn/b.mpd',
          title: 'Gama · auto',
          type: 'dash',
          providerId: 'vidsrcwin',
        ),
        StreamSource(
          url: 'https://cdn/c.m3u8',
          title: 'Alpha · Stream',
          type: 'hls',
          providerId: 'vidsrcwin',
        ),
      ];
      final owned = sourcesOwnedByProvider('vidsrcwin', rows);
      expect(owned, hasLength(1));
      expect(owned.first.title, 'Alpha · Stream');
    });

    test('stamps bucket id on untagged survivors', () {
      final rows = [
        StreamSource(
          url: 'https://cdn/x.m3u8',
          title: 'Stream',
          type: 'hls',
        ),
      ];
      final owned = sourcesOwnedByProvider('vidsrc', rows);
      expect(owned, hasLength(1));
      expect(owned.first.providerId, 'vidsrc');
    });
  });

  group('preferFullerProviderSources', () {
    test('keeps fuller cache when live collapsed to one stream', () {
      final a = StreamSource(
        url: 'https://cdn/a.m3u8',
        title: 'Alpha',
        type: 'hls',
        providerId: 'vidsrcwin',
      );
      final b = StreamSource(
        url: 'https://cdn/b.m3u8',
        title: 'Blaze',
        type: 'hls',
        providerId: 'vidsrcwin',
      );
      final fuller = preferFullerProviderSources(
        providerId: 'vidsrcwin',
        live: [a],
        cached: [a, b],
      );
      expect(fuller, hasLength(2));
      expect(fuller.map((s) => s.url), ['https://cdn/a.m3u8', 'https://cdn/b.m3u8']);
    });
  });

  group('PlayerStreamMenu.sourcesForProvider', () {
    test('current server keeps cache siblings after live shrink', () {
      final a = StreamSource(
        url: 'https://cdn/a.m3u8',
        title: 'Alpha',
        type: 'hls',
        providerId: 'vidsrcwin',
      );
      final b = StreamSource(
        url: 'https://cdn/b.m3u8',
        title: 'Blaze',
        type: 'hls',
        providerId: 'vidsrcwin',
      );
      final state = PlayerStreamMenuState(
        currentProviderId: 'vidsrcwin',
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
          providerId: 'vidsrcwin',
          state: state,
          cache: {
            'vidsrcwin': [a, b],
          },
        ),
        hasLength(2),
      );
    });

    test('VSEmbed section does not show Videasy cache poison', () {
      final videasy = StreamSource(
        url: 'https://cdn/a.m3u8',
        title: 'Yoru · 2160p',
        type: 'hls',
        providerId: 'videasy',
      );
      final state = PlayerStreamMenuState(
        currentProviderId: 'videasy',
        sources: [videasy],
        currentUrl: videasy.url,
        currentPlayingCatalogUrl: videasy.url,
        current111477FileUrl: null,
        is111477: false,
        playbackConfirmed: true,
        mediaPlaying: true,
      );
      final cache = <String, List<StreamSource>>{
        'videasy': [videasy],
        // Poison: same Videasy rows wrongly stored under vidsrc.
        'vidsrc': [videasy],
      };
      expect(
        PlayerStreamMenu.sourcesForProvider(
          providerId: 'videasy',
          state: state,
          cache: cache,
        ),
        hasLength(1),
      );
      expect(
        PlayerStreamMenu.sourcesForProvider(
          providerId: 'vidsrc',
          state: state,
          cache: cache,
        ),
        isEmpty,
      );
    });
  });
}
