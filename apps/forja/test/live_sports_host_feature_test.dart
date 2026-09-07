import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/live_sports/live_sports_host_layout.dart';
import 'package:forja/features/live_sports/live_sports_host.dart';
import 'package:forja/shared/foundation/services/host_list_registry.dart';
import 'package:forja/shared/foundation/components/layout/kit_types.dart';
import 'package:forja/shared/foundation/services/plugin_nav.dart';
import 'package:forja/shell/nav_config.dart';

void main() {
  setUp(() {
    HostListRegistry.debugReset();
    LiveSportsHost.debugReset();
    PluginNavRegistry.seedBuiltIns();
    LiveSportsHost.ensureRegistered();
  });

  test('live_matches is core shell — contributed without a hub pack', () {
    expect(PluginNavRegistry.coreShellNavIds, contains('live_matches'));
    expect(PluginNavRegistry.isContributed('live_matches'), isTrue);
    expect(PluginNavRegistry.isKitTab('live_matches'), isFalse);
    expect(coreNavDestinations.containsKey('live_matches'), isTrue);
    expect(coreNavTabBuilders.containsKey('live_matches'), isTrue);
    expect(navDestinations['live_matches']?.label, 'Live Sports');
  });

  test('Features inventory omits addon-gated tabs until Addons activates them',
      () {
    final off = PluginNavRegistry.featureTabIds();
    expect(off, isNot(contains('iptv')));
    expect(off, isNot(contains('live_matches')));
    expect(off, isNot(contains('settings')));
    expect(off, isNot(contains('home')));

    final on = PluginNavRegistry.featureTabIds(
      availableAddonFeatureIds: const ['iptv', 'live_matches'],
    );
    expect(on, containsAll(['iptv', 'live_matches']));
    expect(on, isNot(contains('settings')));
  });

  test('Features inventory includes contributed hub tabs', () {
    PluginNavRegistry.seedTestHubNav();
    final ids = PluginNavRegistry.featureTabIds(
      availableAddonFeatureIds: const ['iptv', 'live_matches'],
    );
    expect(ids, containsAll(['iptv', 'live_matches', 'test_hub_a']));
    expect(ids, isNot(contains('settings')));
  });

  test('host-default layout is topBar + categoryBar + list+panel', () {
    expect(
      KitTypes.treeContains(
        kLiveSportsHostDefaultLayout,
        slot: KitTypes.list,
        listSource: LiveSportsHost.listSourceId,
      ),
      isTrue,
    );
    expect(
      KitTypes.treeContains(
        kLiveSportsHostDefaultLayout,
        slot: KitTypes.topBar,
      ),
      isTrue,
    );
    expect(
      KitTypes.treeContains(
        kLiveSportsHostDefaultLayout,
        slot: KitTypes.categoryBar,
      ),
      isTrue,
    );
    final stack = kLiveSportsHostDefaultLayout.first;
    expect(stack['type'], KitTypes.stack);
    final children = stack['children'] as List;
    final list = children.last as Map;
    expect(list['type'], KitTypes.list);
    expect(list['source'], LiveSportsHost.listSourceId);
    expect(list['style'], 'list');
    expect(list['open'], 'panel');
  });

  test('live_schedule registers list source without host body', () {
    final source = HostListRegistry.resolve(sourceId: 'live_schedule');
    expect(source, isNotNull);
    expect(source!.wantsHostBody, isFalse);
    expect(HostListRegistry.isFullPageHost('live_schedule'), isFalse);
  });

  test('live_schedule registers streams panel host', () {
    final panel =
        HostListRegistry.resolvePanel(LiveSportsHost.listSourceId);
    expect(panel, isNotNull);
    expect(panel!.listSourceId, LiveSportsHost.listSourceId);
  });

  test('pack builder overwrites core live_matches when registry has hub', () {
    PluginNavRegistry.seedTestHubNav(
      destinations: {
        'live_matches': coreNavDestinations['live_matches']!,
      },
      tabPluginIds: const {'live_matches': 'test-live-hub'},
    );
    expect(PluginNavRegistry.isKitTab('live_matches'), isTrue);
    expect(navTabBuilders.containsKey('live_matches'), isTrue);
    expect(PluginNavRegistry.builders.containsKey('live_matches'), isTrue);
  });
}
