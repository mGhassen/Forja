import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/protocol/layout_types.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja_foundation/layout/list/host_list_registry.dart';
import 'package:forja/shared/engine/runtime/open/live_surface_open.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    HostListRegistry.debugReset();
    LiveSurfaceOpen.debugReset();
    LiveSurfaceOpen.ensureRegistered();
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
          listSource: 'live_schedule',
        ),
        isTrue,
      );
      expect(HostListRegistry.isFullPageHost('live_schedule'), isFalse);
      // Progressive source is built in KitListWidget (not HostListRegistry).
      expect(
        HostListRegistry.resolve(sourceId: 'live_schedule'),
        isNull,
      );
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
        'open': {'surface': 'live', 'id': '1', 'tabId': 'live_sports'},
      });
      expect(item.airing, isTrue);
      expect(item.startsAt, '2026-09-01T18:00:00Z');
      expect(item.viewers, 1200);
      expect(item.sources, isNotEmpty);
      expect(item.open?.surface, 'live');
      expect(item.open?.extraString('tabId'), 'live_sports');
      expect(item.toJson()['starts_at'], '2026-09-01T18:00:00Z');
    });
  });
}
