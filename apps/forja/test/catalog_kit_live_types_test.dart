import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/live/live_feed_aggregate.dart';
import 'package:forja_foundation/protocol/layout_types.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja/shared/engine/hub/meta_feed_list_source.dart';
import 'package:forja/shared/engine/hub/host_list_registry.dart';
import 'package:forja/shared/engine/hub/kit_live_boot.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    HostListRegistry.debugReset();
    KitLiveBoot.debugReset();
    KitLiveBoot.ensureRegistered();
  });

  group('live_schedule kit.list source', () {
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
        LayoutTypes.treeContains(
          layout,
          slot: LayoutTypes.list,
          listSource: KitLiveBoot.listSourceId,
        ),
        isTrue,
      );
      expect(HostListRegistry.isFullPageHost('live_schedule'), isFalse);
      final source = HostListRegistry.resolve(sourceId: 'live_schedule');
      expect(source, isNotNull);
      expect(source, same(MetaFeedListSource.liveSchedule));
      expect(source!.wantsHostBody, isFalse);
      expect(source.id, KitLiveBoot.listSourceId);
    });

    test('generic kit types only — no product-named live slots', () {
      expect(LayoutTypes.normalize('kit.stack'), LayoutTypes.stack);
      expect(LayoutTypes.normalize('kit.list'), LayoutTypes.list);
      expect(LayoutTypes.normalize('kit.topBar'), LayoutTypes.topBar);
      expect(
        LayoutTypes.normalize('kit.categoryBar'),
        LayoutTypes.categoryBar,
      );
      expect(LayoutTypes.normalize('kit.live.mode'), 'kit.live.mode');
    });
  });

  group('MetaItem live fields', () {
    test('parses string viewers (PPV-style wire)', () {
      final item = MetaItem.fromJson({
        'id': 'test-a:2',
        'type': 'live_match',
        'name': 'A vs B',
        'viewers': '2846',
      });
      expect(item.viewers, 2846);
    });

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

    test('liveMetaFromFeedRow maps opaque rows', () {
      final item = liveMetaFromFeedRow({
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

    test('liveFeedRowMatches filters by window', () {
      final now = DateTime.now();
      final row = <String, dynamic>{
        'id': 'evt-2',
        'title': 'Soon',
        'startsAt': now.add(const Duration(hours: 2)).millisecondsSinceEpoch,
      };
      final item = liveMetaFromFeedRow(row);
      expect(
        liveFeedRowMatches(
          row,
          item,
          const LiveFeedQuery(
            scheduleStatus: 'both',
            scheduleHorizon: 'h1',
          ),
        ),
        isFalse,
      );
      expect(
        liveFeedRowMatches(
          row,
          item,
          const LiveFeedQuery(
            scheduleStatus: 'both',
            scheduleHorizon: 'h3',
          ),
        ),
        isTrue,
      );
      expect(
        liveFeedRowMatches(
          row,
          item,
          const LiveFeedQuery(
            scheduleStatus: 'both',
            scheduleHorizon: 'h24',
          ),
        ),
        isTrue,
      );
    });

    test('MetaFeedListSource resolves live_schedule id', () {
      expect(MetaFeedListSource.liveSchedule.id, 'live_schedule');
    });
  });
}
