import 'package:flutter/foundation.dart';
import 'package:forja/shared/foundation/services/host_list_registry.dart';
import 'package:forja/shared/foundation/services/live/live_schedule_catalog_source.dart';
import 'package:forja/shared/foundation/services/live/live_sports_streams_panel_host.dart';
import 'package:forja/shared/foundation/services/plugin_nav.dart';

/// Live Sports host services — list source + streams panel registration.
///
/// Packs set `kit.list { source: "live_schedule" }`. Host never binds a
/// shipped hub plugin id or pack nav tab id.
abstract final class LiveSportsHost {
  LiveSportsHost._();

  /// Host service id for [HostListRegistry] / pack `source`.
  static const listSourceId = 'live_schedule';

  /// Engine type token live hubs declare (`engine.types`).
  static const engineType = 'live_match';

  static bool _registered = false;

  static void ensureRegistered() {
    if (_registered) return;
    _registered = true;
    HostListRegistry.register(LiveScheduleCatalogSource.instance);
    HostListRegistry.registerPanel(LiveSportsStreamsPanelHost.instance);
  }

  /// Pack-contributed shell tab for Live Sports. Null when no live hub is
  /// installed/enabled — never a hardcoded pack tab id.
  static Future<String?> resolveTabId() async {
    for (final (_, pl, nav) in await PluginNavRegistry.listNavHubs()) {
      if (pl.types.contains(engineType)) return nav.tabId;
    }
    final pluginId =
        await PluginNavRegistry.pluginIdForEngineType(engineType);
    if (pluginId == null || pluginId.isEmpty) return null;
    return PluginNavRegistry.tabIdForPluginSync(pluginId);
  }

  /// Test helper — allows [ensureRegistered] after [HostListRegistry.debugReset].
  @visibleForTesting
  static void debugReset() {
    _registered = false;
  }
}
