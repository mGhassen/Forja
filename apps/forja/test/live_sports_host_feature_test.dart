import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/catalog/kit/layout/catalog_kit_types.dart';
import 'package:forja/shared/catalog/kit/sources/catalog_kit_list_source.dart';
import 'package:forja/shared/catalog/kit/sources/live_schedule/live_sports_host_layout.dart';
import 'package:forja/shared/catalog/kit/sources/live_schedule/live_sports_kit_page.dart';
import 'package:forja/shared/catalog/plugin_nav.dart';
import 'package:forja/shell/nav_config.dart';

void main() {
  setUp(() {
    PluginNavRegistry.seedBuiltIns();
  });

  test('live_matches is core shell — contributed without a hub pack', () {
    expect(PluginNavRegistry.coreShellNavIds, contains('live_matches'));
    expect(PluginNavRegistry.isContributed('live_matches'), isTrue);
    expect(PluginNavRegistry.isHubTab('live_matches'), isFalse);
    expect(coreNavDestinations.containsKey('live_matches'), isTrue);
    expect(coreNavTabBuilders.containsKey('live_matches'), isTrue);
    expect(navDestinations['live_matches']?.label, 'Live Sports');
  });

  test('Features inventory always lists host-core tabs', () {
    final ids = PluginNavRegistry.featureTabIds();
    expect(ids, containsAll(['iptv', 'live_matches']));
    expect(ids, isNot(contains('settings')));
    expect(ids, isNot(contains('home')));
  });

  test('Features inventory includes contributed hub tabs', () {
    PluginNavRegistry.seedTestHubNav();
    final ids = PluginNavRegistry.featureTabIds();
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
    expect(root['source'], CatalogKitListSources.liveSchedule);
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
