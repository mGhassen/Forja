import 'package:flutter_test/flutter_test.dart';
import 'package:forja/app/boot_needs.dart';
import 'package:forja/app/hub_boot_prefetch.dart';
import 'package:forja/shared/catalog/plugin_nav.dart';

void main() {
  setUp(PluginNavRegistry.seedTestHubNav);

  group('BootNeeds nav helpers', () {
    test('hub vs vod vs core shell', () {
      expect(BootNeeds.isHubNavId('home'), isTrue);
      expect(BootNeeds.isHubNavId('anime'), isTrue);
      expect(BootNeeds.isHubNavId('custom_hub'), isTrue);
      expect(BootNeeds.isHubNavId('mylist'), isTrue);
      expect(BootNeeds.isHubNavId('iptv'), isFalse);
      expect(BootNeeds.isHubNavId('settings'), isFalse);

      expect(BootNeeds.isVodNavId('home'), isTrue);
      expect(BootNeeds.isVodNavId('mylist'), isTrue);
      expect(BootNeeds.isVodNavId('iptv'), isFalse);
      expect(BootNeeds.isVodNavId('live_matches'), isFalse);
      expect(BootNeeds.isVodNavId('settings'), isFalse);
    });

    test('openingStatusLabel uses hub destination label', () {
      const needs = BootNeeds(
        visibleNavIds: ['anime', 'iptv'],
        hubTab: true,
        catalogTab: true,
        torrent: false,
        stremio: false,
        nuvio: false,
        engine: false,
        playSourceTorrent: false,
        playSourceStremio: false,
        playSourceNuvio: false,
        playSourceEngine: false,
        vodTab: true,
      );
      expect(needs.openingStatusLabel, 'Opening Anime…');
    });

    test('openingStatusLabel for live/iptv-only', () {
      const needs = BootNeeds(
        visibleNavIds: ['iptv', 'live_matches'],
        hubTab: false,
        catalogTab: false,
        torrent: false,
        stremio: false,
        nuvio: false,
        engine: false,
        playSourceTorrent: false,
        playSourceStremio: false,
        playSourceNuvio: false,
        playSourceEngine: false,
        vodTab: false,
      );
      expect(needs.openingStatusLabel, 'Opening Live & IPTV…');
    });
  });

  group('firstPaintRailsFromPage', () {
    test('feed pages return empty (caller runs feed)', () {
      expect(
        firstPaintRailsFromPage({
          'feed': true,
          'widgets': [
            {'type': 'hero', 'rail': 'spotlight', 'bleed': 'featured'},
          ],
        }),
        isEmpty,
      );
      expect(pageUsesFeed({'feed': true}), isTrue);
    });

    test('collects hero rail+bleed above continue', () {
      expect(
        firstPaintRailsFromPage({
          'widgets': [
            {
              'type': 'hero',
              'id': 'spotlight',
              'rail': 'spotlight',
              'bleed': 'latest',
            },
            {'type': 'continue', 'id': 'cw'},
            {'type': 'rail', 'rail': 'trending'},
          ],
        }),
        ['spotlight', 'latest'],
      );
    });

    test('skips vertical_filters and mood', () {
      expect(
        firstPaintRailsFromPage({
          'widgets': [
            {'type': 'vertical_filters', 'id': 'vf'},
            {'type': 'hero', 'rail': 'a', 'bleed': 'b'},
            {'type': 'mood', 'rail': 'discover'},
            {'type': 'continue'},
            {'type': 'rail', 'rail': 'c'},
          ],
        }),
        ['a', 'b'],
      );
    });
  });

  group('layoutPageForTab', () {
    test('prefers matching page key', () {
      final page = layoutPageForTab({
        'pages': {
          'home': {
            'feed': true,
            'widgets': [
              {'type': 'hero'},
            ],
          },
          'other': {
            'widgets': [
              {'type': 'rail', 'rail': 'x'},
            ],
          },
        },
      }, 'home');
      expect(pageUsesFeed(page!), isTrue);
    });
  });
}
