import 'package:flutter_test/flutter_test.dart';
import 'package:forja/app/boot_needs.dart';
import 'package:forja/app/hub_boot_prefetch.dart';
import 'package:forja/shared/catalog/plugin_nav.dart';

void main() {
  setUp(PluginNavRegistry.seedTestHubNav);

  group('BootNeeds nav helpers', () {
    test('hub vs vod vs core shell', () {
      expect(BootNeeds.isHubNavId('test_hub_a'), isTrue);
      expect(BootNeeds.isHubNavId('test_hub_b'), isTrue);
      expect(BootNeeds.isHubNavId('unknown_hub'), isFalse);
      expect(BootNeeds.isHubNavId('mylist'), isFalse);
      expect(BootNeeds.isHubNavId('iptv'), isFalse);
      expect(BootNeeds.isHubNavId('settings'), isFalse);

      expect(BootNeeds.isVodNavId('test_hub_a'), isTrue);
      // Features rail slot awaiting pack nav (not yet contributed).
      expect(BootNeeds.isVodNavId('mylist'), isTrue);
      expect(BootNeeds.isVodNavId('anime'), isTrue);
      expect(BootNeeds.isVodNavId('iptv'), isFalse);
      expect(BootNeeds.isVodNavId('live_matches'), isFalse);
      expect(BootNeeds.isVodNavId('settings'), isFalse);
    });

    test('openingStatusLabel uses hub destination label', () {
      const needs = BootNeeds(
        visibleNavIds: ['test_hub_b', 'iptv'],
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
      expect(needs.openingStatusLabel, 'Opening Hub B…');
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
      expect(needs.needsForjaPluginWarm, isFalse);
    });

    test('needsForjaPluginWarm true when catalog, engines, or pending packs', () {
      const liveOnly = BootNeeds(
        visibleNavIds: ['iptv', 'live_matches'],
        hubTab: false,
        catalogTab: false,
        torrent: false,
        stremio: false,
        nuvio: false,
        engine: false,
        playSourceTorrent: true,
        playSourceStremio: true,
        playSourceNuvio: true,
        playSourceEngine: true,
        vodTab: false,
      );
      expect(liveOnly.needsForjaPluginWarm, isFalse);

      const liveOnlyPending = BootNeeds(
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
        pendingPackDisk: true,
      );
      expect(liveOnlyPending.needsForjaPluginWarm, isTrue);

      const withHub = BootNeeds(
        visibleNavIds: ['test_hub_a', 'iptv'],
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
      expect(withHub.needsForjaPluginWarm, isTrue);

      // Features shows Home while pack not contributed yet.
      const ghostHubs = BootNeeds(
        visibleNavIds: ['home', 'anime', 'iptv', 'live_matches'],
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
        pendingPackDisk: true,
      );
      expect(ghostHubs.needsForjaPluginWarm, isTrue);
      expect(BootNeeds.isVodNavId('home'), isTrue);
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
          'test_hub_a': {
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
      }, 'test_hub_a');
      expect(pageUsesFeed(page!), isTrue);
    });
  });
}
