import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/foundation/services/live/live_prefs.dart';
import 'package:forja/shared/foundation/services/live/live_schedule_catalog_source.dart';
import 'package:forja/shared/foundation/services/live/live_sports_host.dart';
import 'package:forja/shared/foundation/services/live/schedule_list_source.dart';
import 'package:forja/shared/foundation/services/host_list_registry.dart';
import 'package:forja/shared/foundation/components/layout/kit_types.dart';
import 'package:forja/shared/foundation/protocol/protocol.dart';

void main() {
  setUp(() {
    HostListRegistry.debugReset();
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
      expect(
        KitTypes.treeContains(
          layout,
          slot: KitTypes.list,
          listSource: LiveSportsHost.listSourceId,
        ),
        isTrue,
      );
      expect(HostListRegistry.isFullPageHost('live_schedule'), isFalse);
      final source = HostListRegistry.resolve(sourceId: 'live_schedule');
      expect(source, isNotNull);
      expect(source, same(LiveScheduleCatalogSource.instance));
      expect(source!.wantsHostBody, isFalse);
      expect(source.id, LiveSportsHost.listSourceId);
      expect(
        LiveSportsListSources.resolve(LiveSportsListSources.liveSchedule),
        isNotNull,
      );
    });

    test('generic kit types only — no product-named live slots', () {
      expect(KitTypes.normalize('kit.stack'), KitTypes.stack);
      expect(KitTypes.normalize('kit.list'), KitTypes.list);
      expect(KitTypes.normalize('kit.topBar'), KitTypes.topBar);
      expect(
        KitTypes.normalize('kit.categoryBar'),
        KitTypes.categoryBar,
      );
      expect(KitTypes.normalize('kit.live.mode'), 'kit.live.mode');
    });
  });

  group('LivePrefs', () {
    test('keeps catalog / schedule / view keys; mode keys retired', () {
      expect(LivePrefs.catalogFilterKey, 'live_sports_forja_catalog_filter_v1');
      expect(LivePrefs.scheduleKey, 'live_sports_schedule_v2');
      expect(LivePrefs.viewKey, 'live_sports_timeline_view');
    });
  });

  group('MetaItem live fields', () {
    test('parses airing, starts_at, viewers, sources', () {
      final item = MetaItem.fromJson({
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
        'airing': true,
        'startsAt': '2026-09-01T18:00:00Z',
        'viewers': 9,
        'kind': 'football',
        'open': {'surface': 'live', 'id': 'evt-1'},
      });
      expect(item.id, 'evt-1');
      expect(item.type, 'live_match');
      expect(item.airing, isTrue);
      expect(item.open?.surface, 'live');
      expect(item.genres, ['football']);
      expect(item.startsAt, '2026-09-01T18:00:00Z');
    });

    test('liveScheduleRowInHorizon filters by window', () {
      final now = DateTime.now();
      final row = <String, dynamic>{
        'id': 'evt-2',
        'title': 'Soon',
        'startsAt': now.add(const Duration(hours: 2)).millisecondsSinceEpoch,
      };
      final item = liveMetaFromScheduleRow(row);
      expect(liveScheduleRowInHorizon(row, item, '1h'), isFalse);
      expect(liveScheduleRowInHorizon(row, item, '3h'), isTrue);
      expect(liveScheduleRowInHorizon(row, item, 'all'), isTrue);
    });

    test('LiveScheduleListSource resolves live_schedule id', () {
      expect(
        LiveSportsListSources.resolve('live_schedule'),
        isA<LiveScheduleListSource>(),
      );
      expect(const LiveScheduleListSource().id, 'live_schedule');
    });
  });
}
