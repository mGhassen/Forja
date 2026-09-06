import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/live_matches/live_schedule/live_sports_host_layout.dart';
import 'package:forja/features/live_matches/live_schedule/live_sports_kit_page.dart';
import 'package:forja/features/live_matches/live_sports_host.dart';
import 'package:forja/shared/catalog/kit/layout/catalog_kit_types.dart';
import 'package:forja/shared/catalog/plugin_nav.dart';
import 'package:forja/shell/nav_config.dart';

void main() {
  setUp(() {
    PluginNavRegistry.seedBuiltIns();
    LiveSportsHost.ensureRegistered();
  });

  test('live_matches is core shell — contributed without a hub pack', () {
    expect(PluginNavRegistry.coreShellNavIds, contains('live_matches'));
    expect(PluginNavRegistry.isContributed('live_matches'), isTrue);
    expect(PluginNavRegistry.isHubTab('live_matches'), isFalse);
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
      activeAddonNavIds: const ['iptv', 'live_matches'],
    );
    expect(on, containsAll(['iptv', 'live_matches']));
    expect(on, isNot(contains('settings')));
  });

  test('Features inventory includes contributed hub tabs', () {
    PluginNavRegistry.seedTestHubNav();
    final ids = PluginNavRegistry.featureTabIds(
      activeAddonNavIds: const ['iptv', 'live_matches'],
    );
    expect(ids, containsAll(['iptv', 'live_matches', 'test_hub_a']));
    expect(ids, isNot(contains('settings')));
  });

  test('host-default layout is live_schedule list (RFC-084)', () {
    expect(
      LiveSportsKitPage.matchesLayout(kLiveSportsHostDefaultLayout),
      isTrue,
    );
    final root = kLiveSportsHostDefaultLayout.first;
    expect(root['type'], CatalogKitTypes.list);
    expect(root['source'], LiveSportsHost.listSourceId);
    expect(root['style'], 'list');
  });

  test('pack builder overwrites core live_matches when registry has hub', () {
    PluginNavRegistry.seedTestHubNav(
      destinations: {
        'live_matches': coreNavDestinations['live_matches']!,
      },
      tabPluginIds: const {'live_matches': 'test-live-hub'},
    );
    expect(PluginNavRegistry.isHubTab('live_matches'), isTrue);
    expect(navTabBuilders.containsKey('live_matches'), isTrue);
    // Pack map is merged after core — same key means pack path is present.
    expect(PluginNavRegistry.builders.containsKey('live_matches'), isTrue);
  });
}
