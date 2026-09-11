import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/foundation/services/registry/host_list_registry.dart';
import 'package:forja/shared/host/live_sports/schedule/kit_live_boot.dart';
import 'package:forja/shared/host/live_sports/schedule/kit_schedule_prefs.dart';
import 'package:forja/shared/foundation/services/nav/plugin_nav.dart';
import 'package:forja/shell/nav/nav_config.dart';
import 'package:rust/rust.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({
      KitSchedulePrefs.mergeUpgradeDoneKey: true,
    });
    HostListRegistry.debugReset();
    KitLiveBoot.debugReset();
    PluginNavRegistry.seedBuiltIns();
    KitLiveBoot.ensureRegistered();
  });

  test('live_sports is pack-owned — not core shell without a hub', () {
    expect(PluginNavRegistry.coreShellNavIds, isNot(contains('live_sports')));
    expect(PluginNavRegistry.isContributed('live_sports'), isFalse);
    expect(PluginNavRegistry.isKitTab('live_sports'), isFalse);
    expect(coreNavDestinations.containsKey('live_sports'), isFalse);
    expect(coreNavTabBuilders.containsKey('live_sports'), isFalse);
    expect(SettingsService.addonGatedNavIds, isNot(contains('live_sports')));
  });

  test('Features inventory omits iptv until Addons activates it', () {
    final off = PluginNavRegistry.featureTabIds();
    expect(off, isNot(contains('iptv')));
    expect(off, isNot(contains('live_sports')));
    expect(off, isNot(contains('settings')));
    expect(off, isNot(contains('home')));

    final on = PluginNavRegistry.featureTabIds(
      availableAddonFeatureIds: const ['iptv'],
    );
    expect(on, contains('iptv'));
    expect(on, isNot(contains('live_sports')));
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
    final panel = HostListRegistry.resolvePanel(KitLiveBoot.listSourceId);
    expect(panel, isNotNull);
    expect(panel!.listSourceId, KitLiveBoot.listSourceId);
  });

  test('hub pack contributes live_sports kit tab', () {
    PluginNavRegistry.seedTestHubNav(
      destinations: {
        'live_sports': const NavDestination(
          id: 'live_sports',
          icon: Icons.sports_soccer_outlined,
          activeIcon: Icons.sports_soccer,
          label: 'Live Sports',
        ),
      },
      tabPluginIds: const {'live_sports': 'test-live-hub'},
    );
    expect(PluginNavRegistry.isKitTab('live_sports'), isTrue);
    expect(PluginNavRegistry.isContributed('live_sports'), isTrue);
    expect(navTabBuilders.containsKey('live_sports'), isTrue);
    expect(PluginNavRegistry.builders.containsKey('live_sports'), isTrue);
    expect(navDestinations['live_sports']?.label, 'Live Sports');
  });
}
