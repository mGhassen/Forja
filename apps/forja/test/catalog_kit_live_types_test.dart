import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/live_matches/catalog/live_schedule_catalog_source.dart';
import 'package:forja/features/live_matches/live_schedule/data/live_prefs.dart';
import 'package:forja/features/live_matches/live_schedule/data/live_schedule_source.dart';
import 'package:forja/features/live_matches/live_schedule/live_sports_browse_shell.dart';
import 'package:forja/features/live_matches/live_sports_host.dart';
import 'package:forja/shared/catalog/host_list_registry.dart';
import 'package:forja/shared/catalog/kit/layout/catalog_kit_types.dart';
import 'package:forja/shared/catalog/protocol.dart';

void main() {
  setUp(() {
    CatalogHostListRegistry.debugReset();
    LiveSportsHost.debugReset();
    LiveSportsHost.ensureRegistered();
  });

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
      expect(LiveSportsBrowseShell.matchesLayout(layout), isTrue);
      expect(
        CatalogKitTypes.treeContains(
          layout,
          slot: CatalogKitTypes.list,
          listSource: LiveSportsHost.listSourceId,
        ),
        isTrue,
      );
      expect(CatalogHostListRegistry.isFullPageHost('live_schedule'), isFalse);
      final source = CatalogHostListRegistry.resolve(sourceId: 'live_schedule');
      expect(source, isNotNull);
      expect(source, same(LiveScheduleCatalogSource.instance));
      expect(source!.wantsHostBody, isTrue);
      expect(source.id, LiveSportsHost.listSourceId);
      expect(
        LiveSportsListSources.resolve(LiveSportsListSources.liveSchedule),
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
        'category': 'Football',
      });
      expect(item.id, 'evt-1');
      expect(item.type, 'live_match');
      expect(item.airing, isTrue);
      expect(item.open?.surface, 'live');
      expect(item.genres, ['Football']);
    });

    test('HubLiveScheduleSource resolves live_schedule id', () {
      expect(
        LiveSportsListSources.resolve('live_schedule'),
        isA<HubLiveScheduleSource>(),
      );
      expect(const HubLiveScheduleSource().id, 'live_schedule');
    });
  });
}
