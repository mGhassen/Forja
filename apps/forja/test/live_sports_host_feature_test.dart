import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/foundation/services/host_list_registry.dart';
import 'package:forja/shared/foundation/services/live/live_sports_host.dart';
import 'package:forja/shared/foundation/services/plugin_nav.dart';
import 'package:forja/shell/nav/nav_config.dart';
import 'package:forja/shell/nav/nav_destination.dart';
import 'package:rust/rust.dart';

void main() {
  setUp(() {
    HostListRegistry.debugReset();
    LiveSportsHost.debugReset();
    PluginNavRegistry.seedBuiltIns();
    LiveSportsHost.ensureRegistered();
  });

  test('live_matches is pack-owned — not core shell without a hub', () {
    expect(PluginNavRegistry.coreShellNavIds, isNot(contains('live_matches')));
    expect(PluginNavRegistry.isContributed('live_matches'), isFalse);
    expect(PluginNavRegistry.isKitTab('live_matches'), isFalse);
    expect(coreNavDestinations.containsKey('live_matches'), isFalse);
    expect(coreNavTabBuilders.containsKey('live_matches'), isFalse);
    expect(SettingsService.addonGatedNavIds, isNot(contains('live_matches')));
  });

  test('Features inventory omits iptv until Addons activates it', () {
    final off = PluginNavRegistry.featureTabIds();
    expect(off, isNot(contains('iptv')));
    expect(off, isNot(contains('live_matches')));
    expect(off, isNot(contains('settings')));
    expect(off, isNot(contains('home')));

    final on = PluginNavRegistry.featureTabIds(
      availableAddonFeatureIds: const ['iptv'],
    );
    expect(on, contains('iptv'));
    expect(on, isNot(contains('live_matches')));
    expect(on, isNot(contains('settings')));
  });

  test('Features inventory includes contributed hub tabs', () {
    PluginNavRegistry.seedTestHubNav();
    final ids = PluginNavRegistry.featureTabIds(
      availableAddonFeatureIds: const ['iptv'],
    );
    expect(ids, containsAll(['iptv', 'test_hub_a']));
    expect(ids, isNot(contains('settings')));
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

  test('hub pack contributes live_matches kit tab', () {
    PluginNavRegistry.seedTestHubNav(
      destinations: {
        'live_matches': const NavDestination(
          id: 'live_matches',
          icon: Icons.sports_soccer_outlined,
          activeIcon: Icons.sports_soccer,
          label: 'Live Sports',
        ),
      },
      tabPluginIds: const {'live_matches': 'test-live-hub'},
    );
    expect(PluginNavRegistry.isKitTab('live_matches'), isTrue);
    expect(PluginNavRegistry.isContributed('live_matches'), isTrue);
    expect(navTabBuilders.containsKey('live_matches'), isTrue);
    expect(PluginNavRegistry.builders.containsKey('live_matches'), isTrue);
    expect(navDestinations['live_matches']?.label, 'Live Sports');
  });
}
