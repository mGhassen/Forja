import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/catalog/kit/layout/catalog_kit_types.dart';
import 'package:forja/shared/catalog/kit/sources/catalog_kit_list_source.dart';
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

  group('LivePrefs', () {
    test('keeps catalog / schedule / view keys; mode keys retired', () {
      expect(LivePrefs.catalogFilterKey, 'live_matches_forja_catalog_filter_v1');
      expect(LivePrefs.scheduleKey, 'live_matches_schedule_v2');
      expect(LivePrefs.viewKey, 'live_matches_timeline_view');
    });
  });

  group('CatalogMetaItem live fields', () {
    test('parses airing, starts_at, viewers, sources', () {
      final item = CatalogMetaItem.fromJson({
        'id': 'test-a:1',
        'type': 'live_match',
        'name': 'Team A vs Team B',
        'airing': true,
        'starts_at': '2026-09-01T18:00:00Z',
        'viewers': 1200,
        'sources': [
          {'pluginId': 'test-provider-a', 'id': '1'},
        ],
        'open': {'surface': 'live', 'id': '1'},
      });
      expect(item.airing, isTrue);
      expect(item.startsAt, '2026-09-01T18:00:00Z');
      expect(item.viewers, 1200);
      expect(item.sources, isNotEmpty);
      expect(item.open?.surface, 'live');
      expect(item.toJson()['starts_at'], '2026-09-01T18:00:00Z');
    });

    test('liveMetaFromScheduleRow maps opaque rows', () {
      final item = liveMetaFromScheduleRow({
        'id': 'evt-1',
        'title': 'Alpha vs Beta',
        'live': true,
        'starts_at': '2026-09-01T18:00:00Z',
        'viewers': 9,
      });
      expect(item.id, 'evt-1');
      expect(item.type, 'live_match');
      expect(item.airing, isTrue);
      expect(item.open?.surface, 'live');
    });
  });
}
