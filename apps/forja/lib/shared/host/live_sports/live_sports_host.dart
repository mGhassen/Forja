import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/foundation/lib/match_event.dart';
import 'package:forja/shared/foundation/services/registry/host_list_registry.dart';
import 'package:forja/shared/foundation/services/registry/kit_top_bar_host_hooks.dart';
import 'package:forja/shared/foundation/services/registry/meta_surface_open.dart';
import 'package:forja/shared/foundation/services/nav/plugin_nav.dart';
import 'package:forja/shared/host/live_sports/live_catalog_sheet.dart';
import 'package:forja/shared/host/live_sports/live_play_kit.dart';
import 'package:forja/shared/host/live_sports/live_schedule_catalog_source.dart';
import 'package:forja/shared/host/live_sports/live_schedule_sheet.dart';
import 'package:forja/shared/host/live_sports/live_schedule_window.dart';
import 'package:forja/shared/host/live_sports/live_sports_streams_panel_host.dart';
import 'package:forja/shared/host/live_sports/live_stream_engine.dart';
import 'package:forja/shared/host/live_sports/schedule_filters.dart';

/// Live Sports host services — list source + streams panel + kit hooks.
///
/// Packs set `kit.list { source: "live_schedule" }`. Host never binds a
/// shipped hub plugin id or pack nav tab id. Lives under `shared/host/` —
/// not foundation (RFC-090).
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
    MetaSurfaceOpen.register(LivePlayKit.surface, LivePlayKit.openFromMeta);
    matchEventAiringOnlyLiveCheck = LiveMatchesEngine.cachedAiringOnlyLive;
    _registerTopBarHooks();
  }

  static void _registerTopBarHooks() {
    KitTopBarHostHooks.loadCatalogOptions = () async {
      final plugins = await EngineService.instance.listEnabledLiveFeedPlugins();
      return [
        for (final p in plugins)
          (
            id: EngineService.normalizeLiveSportPluginId(p.id),
            label: p.name.trim().isEmpty ? p.id : p.name.trim(),
          ),
      ];
    };
    KitTopBarHostHooks.openCatalogSheet = showLiveCatalogSheet;
    KitTopBarHostHooks.openScheduleSheet =
        (context, {required currentPref, required onChanged}) async {
      final window = liveScheduleWindowFromPref(currentPref) ??
          (
            status: LiveScheduleStatus.both,
            horizon: LiveScheduleHorizon.h24,
          );
      final container = ProviderScope.containerOf(context);
      await showLiveScheduleSheet(
        context,
        status: window.status,
        horizon: window.horizon,
        onChanged: ({status, horizon}) {
          final notifier = container.read(liveScheduleFiltersProvider.notifier);
          notifier.setScheduleWindow(status: status, horizon: horizon).then((_) {
            final next = container.read(liveScheduleFiltersProvider);
            onChanged(next.schedulePref);
          });
        },
      );
    };
    KitTopBarHostHooks.scheduleChipLabel = (pref) {
      final window = liveScheduleWindowFromPref(pref) ??
          (
            status: LiveScheduleStatus.both,
            horizon: LiveScheduleHorizon.h24,
          );
      return liveScheduleChipLabel(
        status: window.status,
        horizon: window.horizon,
      );
    };
    KitTopBarHostHooks.scheduleChipSelected = (pref) {
      final window = liveScheduleWindowFromPref(pref) ??
          (
            status: LiveScheduleStatus.both,
            horizon: LiveScheduleHorizon.h24,
          );
      return window.status != LiveScheduleStatus.both ||
          window.horizon != LiveScheduleHorizon.h24;
    };
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
    MetaSurfaceOpen.unregister(LivePlayKit.surface);
    matchEventAiringOnlyLiveCheck = null;
    KitTopBarHostHooks.clear();
  }
}
