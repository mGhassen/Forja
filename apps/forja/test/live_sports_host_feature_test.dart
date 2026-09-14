import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/layout/list/host_list_registry.dart';
import 'package:forja/shared/engine/runtime/nav/plugin_nav.dart';
import 'package:forja/shared/engine/runtime/open/live_surface_open.dart';
import 'package:forja/shared/player/sources/resolve_panel_host.dart';
import 'package:forja/shell/nav/nav_config.dart';
import 'package:rust/rust.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    HostListRegistry.debugReset();
    LiveSurfaceOpen.debugReset();
    PluginNavRegistry.seedBuiltIns();
    LiveSurfaceOpen.ensureRegistered();
  });

  test('live_sports is pack-owned — not core shell without a hub', () {
    expect(PluginNavRegistry.coreShellNavIds, isNot(contains('live_sports')));
    expect(PluginNavRegistry.isContributed('live_sports'), isFalse);
    expect(PluginNavRegistry.isKitTab('live_sports'), isFalse);
    expect(coreNavDestinations.containsKey('live_sports'), isFalse);
    expect(coreNavTabBuilders.containsKey('live_sports'), isFalse);
    expect(SettingsService.addonGatedNavIds, isNot(contains('live_sports')));
  });

  test('iptv is pack-owned — not core shell without a hub (RFC-109)', () {
    expect(PluginNavRegistry.coreShellNavIds, isNot(contains('iptv')));
    expect(PluginNavRegistry.isContributed('iptv'), isFalse);
    expect(PluginNavRegistry.isKitTab('iptv'), isFalse);
    expect(coreNavDestinations.containsKey('iptv'), isFalse);
    expect(coreNavTabBuilders.containsKey('iptv'), isFalse);
    expect(SettingsService.addonGatedNavIds, isNot(contains('iptv')));
  });

  test('Features inventory omits pack tabs until contributed', () {
    final off = PluginNavRegistry.featureTabIds();
    expect(off, isNot(contains('iptv')));
    expect(off, isNot(contains('live_sports')));
    expect(off, isNot(contains('settings')));
    expect(off, isNot(contains('home')));

    final on = PluginNavRegistry.featureTabIds(
      availableAddonFeatureIds: const ['iptv'],
    );
    expect(on, isNot(contains('iptv')));
    expect(on, isNot(contains('live_sports')));
    expect(on, isNot(contains('settings')));
  });

  test('Features inventory includes contributed hub tabs', () {
    PluginNavRegistry.seedTestHubNav();
    final ids = PluginNavRegistry.featureTabIds(
      availableAddonFeatureIds: const ['iptv'],
    );
    expect(ids, contains('test_hub_a'));
    expect(ids, isNot(contains('iptv')));
    expect(ids, isNot(contains('settings')));
  });

  test('live_schedule resolves progressive host list source via wire constant', () {
    // HostListRegistry stays panel-only; KitListWidget builds LiveScheduleFeedSource
    // when listSource == LiveSurfaceOpen.listSourceId.
    expect(HostListRegistry.resolve(sourceId: 'live_schedule'), isNull);
    expect(HostListRegistry.isFullPageHost('live_schedule'), isFalse);
    expect(LiveSurfaceOpen.listSourceId, 'live_schedule');
  });

  test('live_schedule registers streams panel host', () {
    final panel = HostListRegistry.resolvePanel('live_schedule');
    expect(panel, isNotNull);
    expect(panel!.listSourceId, KitResolvePanelHost.instance.listSourceId);
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

  test('hub pack contributes iptv kit tab via PackLayoutHost', () {
    PluginNavRegistry.seedTestHubNav(
      destinations: {
        'iptv': const NavDestination(
          id: 'iptv',
          icon: Icons.live_tv_outlined,
          activeIcon: Icons.live_tv,
          label: 'IPTV',
        ),
      },
      tabPluginIds: const {'iptv': 'iptv-hub'},
    );
    expect(PluginNavRegistry.isKitTab('iptv'), isTrue);
    expect(PluginNavRegistry.isContributed('iptv'), isTrue);
    expect(navTabBuilders.containsKey('iptv'), isTrue);
    expect(PluginNavRegistry.builders.containsKey('iptv'), isTrue);
    expect(navDestinations['iptv']?.label, 'IPTV');
  });
}
