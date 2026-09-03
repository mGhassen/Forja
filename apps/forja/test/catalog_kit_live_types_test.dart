import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/catalog/kit/layout/catalog_kit_types.dart';
import 'package:forja/shared/catalog/kit/sources/catalog_kit_list_source.dart';
import 'package:forja/shared/catalog/kit/sources/live_schedule/data/live_mode_registry.dart';
import 'package:forja/shared/catalog/kit/sources/live_schedule/data/live_prefs.dart';
import 'package:forja/shared/catalog/kit/sources/live_schedule/data/live_schedule_source.dart';
import 'package:forja/shared/catalog/kit/sources/live_schedule/live_sports_kit_page.dart';
import 'package:forja/shared/catalog/protocol.dart';

void main() {
  group('Live schedule kit.list source', () {
    test('matchesLayout detects kit.list + live_schedule', () {
      final layout = [
        {
          'type': 'kit.stack',
          'id': 'page',
          'expand': true,
          'children': [
            {
              'type': 'kit.list',
              'id': 'schedule',
              'source': 'live_schedule',
              'expand': true,
            },
          ],
        },
      ];
      expect(LiveSportsKitPage.matchesLayout(layout), isTrue);
      expect(
        CatalogKitTypes.treeContains(
          layout,
          slot: CatalogKitTypes.list,
          listSource: CatalogKitListSources.liveSchedule,
        ),
        isTrue,
      );
      expect(CatalogKitListSources.isFullPageHost('live_schedule'), isTrue);
      expect(CatalogKitListSources.resolve('live_schedule'), isNull);
      expect(
        CatalogKitLiveSources.resolve(CatalogKitLiveSources.liveSchedule),
        isNotNull,
      );
    });

    test('generic kit types only — no product-named live slots', () {
      expect(CatalogKitTypes.normalize('kit.stack'), CatalogKitTypes.stack);
      expect(CatalogKitTypes.normalize('kit.list'), CatalogKitTypes.list);
      expect(CatalogKitTypes.normalize('kit.live.mode'), 'kit.live.mode');
    });
  });

  group('LiveModeId', () {
    test('parses wire ids and legacy server prefs', () {
      expect(LiveModeIdX.tryParse('forja_live'), LiveModeId.forjaLive);
      expect(LiveModeIdX.tryParse('iptvSports'), LiveModeId.forjaSports);
      expect(LiveModeIdX.tryParse('stremio'), LiveModeId.stremio);
      expect(LiveModeIdX.tryParse('ppv'), LiveModeId.forjaLive);
      expect(LiveModeIdX.tryParse('unknown'), isNull);
    });

    test('sharesCatalogSchedule for Forja Live ↔ Forja Sports', () {
      expect(
        LiveModeRegistry.sharesCatalogSchedule(
          LiveModeId.forjaLive,
          LiveModeId.forjaSports,
        ),
        isTrue,
      );
      expect(
        LiveModeRegistry.sharesCatalogSchedule(
          LiveModeId.forjaLive,
          LiveModeId.stremio,
        ),
        isFalse,
      );
    });

    test('LivePrefs keys migrate server_v1 to mode_v1', () {
      expect(LivePrefs.modeKey, 'live_matches_mode_v1');
      expect(LivePrefs.legacyServerKey, 'live_matches_server_v1');
    });
  });

  group('CatalogMetaItem live fields', () {
    test('parses airing, starts_at, viewers, mode, sources', () {
      final item = CatalogMetaItem.fromJson({
        'id': 'test-a:1',
        'type': 'live_match',
        'name': 'Team A vs Team B',
        'airing': true,
        'starts_at': '2026-09-01T18:00:00Z',
        'viewers': 1200,
        'mode': 'forja_live',
        'sources': [
          {'pluginId': 'test-provider-a', 'id': '1'},
        ],
        'open': {'surface': 'live', 'id': '1'},
      });
      expect(item.airing, isTrue);
      expect(item.startsAt, '2026-09-01T18:00:00Z');
      expect(item.viewers, 1200);
      expect(item.mode, 'forja_live');
      expect(item.sources, isNotEmpty);
      expect(item.open?.surface, 'live');
      expect(item.toJson()['starts_at'], '2026-09-01T18:00:00Z');
    });

    test('liveMetaFromScheduleRow maps opaque rows', () {
      final item = liveMetaFromScheduleRow(
        {
          'id': 'evt-1',
          'title': 'Alpha vs Beta',
          'live': true,
          'starts_at': '2026-09-01T18:00:00Z',
          'viewers': 9,
        },
        mode: 'forja_live',
      );
      expect(item.id, 'evt-1');
      expect(item.type, 'live_match');
      expect(item.airing, isTrue);
      expect(item.open?.surface, 'live');
      expect(item.mode, 'forja_live');
    });
  });
}
