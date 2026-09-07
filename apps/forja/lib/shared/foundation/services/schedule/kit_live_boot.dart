import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/engine/live/live_plugin_engine.dart';
import 'package:forja/shared/foundation/components/chrome/kit_catalog_filter_sheet.dart';
import 'package:forja/shared/foundation/components/chrome/kit_schedule_window_sheet.dart';
import 'package:forja/shared/foundation/lib/match_event.dart';
import 'package:forja/shared/foundation/services/meta/meta_feed_list_source.dart';
import 'package:forja/shared/foundation/services/nav/plugin_nav.dart';
import 'package:forja/shared/foundation/services/panel/kit_resolve_panel_host.dart';
import 'package:forja/shared/foundation/services/play/live_surface_open.dart';
import 'package:forja/shared/foundation/services/registry/host_list_registry.dart';
import 'package:forja/shared/foundation/services/registry/kit_top_bar_host_hooks.dart';
import 'package:forja/shared/foundation/services/registry/meta_surface_open.dart';
import 'package:forja/shared/foundation/services/schedule/kit_schedule_filters.dart';
import 'package:forja/shared/foundation/services/schedule/kit_schedule_window.dart';

/// Boot registration for opaque `live_schedule` list + resolve panel.
///
/// Packs set `kit.list { source: "live_schedule" }`. No Live Sports product
/// tree — MetaRuntime feed on the hub plugin + generic services only.
abstract final class KitLiveBoot {
  KitLiveBoot._();

  /// Host service id for [HostListRegistry] / pack `source`.
  static const listSourceId = 'live_schedule';

  /// Engine type token live hubs declare (`engine.types`).
  static const engineType = 'live_match';

  static bool _registered = false;

  static void ensureRegistered() {
    if (_registered) return;
    _registered = true;
    HostListRegistry.register(MetaFeedListSource.liveSchedule);
    HostListRegistry.registerPanel(KitResolvePanelHost.instance);
    MetaSurfaceOpen.register(LiveSurfaceOpen.surface, LiveSurfaceOpen.openFromMeta);
    matchEventAiringOnlyLiveCheck = LivePluginEngine.cachedAiringOnlyLive;
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
    KitTopBarHostHooks.openCatalogSheet = showKitCatalogFilterSheet;
    KitTopBarHostHooks.openScheduleSheet =
        (context, {required currentPref, required onChanged}) async {
      final window = kitScheduleWindowFromPref(currentPref) ??
          (
            status: KitScheduleStatus.both,
            horizon: KitScheduleHorizon.h24,
          );
      final container = ProviderScope.containerOf(context);
      await showKitScheduleWindowSheet(
        context,
        status: window.status,
        horizon: window.horizon,
        onChanged: ({status, horizon}) {
          final notifier = container.read(kitScheduleFiltersProvider.notifier);
          notifier.setScheduleWindow(status: status, horizon: horizon).then((_) {
            final next = container.read(kitScheduleFiltersProvider);
            onChanged(next.schedulePref);
          });
        },
      );
    };
    KitTopBarHostHooks.scheduleChipLabel = (pref) {
      final window = kitScheduleWindowFromPref(pref) ??
          (
            status: KitScheduleStatus.both,
            horizon: KitScheduleHorizon.h24,
          );
      return kitScheduleChipLabel(
        status: window.status,
        horizon: window.horizon,
      );
    };
    KitTopBarHostHooks.scheduleChipSelected = (pref) {
      final window = kitScheduleWindowFromPref(pref) ??
          (
            status: KitScheduleStatus.both,
            horizon: KitScheduleHorizon.h24,
          );
      return window.status != KitScheduleStatus.both ||
          window.horizon != KitScheduleHorizon.h24;
    };
  }

  /// Pack-contributed shell tab for a live hub. Null when none installed.
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
    MetaSurfaceOpen.unregister(LiveSurfaceOpen.surface);
    matchEventAiringOnlyLiveCheck = null;
    KitTopBarHostHooks.clear();
  }
}
