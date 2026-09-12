import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/engine/live/kit_schedule_window.dart';
import 'package:forja/shared/engine/live/live_feed_aggregate.dart';
import 'package:forja/shared/engine/live/live_plugin_engine.dart';
import 'package:forja/shared/engine/live/live_stremio_catalog.dart';
import 'package:forja/shared/engine/live/match_event.dart';
import 'package:forja/shared/engine/hub/host_list_registry.dart';
import 'package:forja/shared/shell/kit_catalog_filter_sheet.dart';
import 'package:forja/shared/shell/kit_schedule_window_sheet.dart';
import 'package:forja/shared/engine/hub/kit_feed_chrome.dart';
import 'package:forja/shared/player/sources/kit_resolve_panel_host.dart';
import 'package:forja/shared/engine/hub/kit_top_bar_host_hooks.dart';
import 'package:forja/shared/engine/hub/live_surface_open.dart';
import 'package:forja/shared/engine/hub/meta_feed_list_source.dart';
import 'package:forja/shared/engine/hub/meta_surface_open.dart';
import 'package:forja/shared/engine/hub/plugin_nav.dart';

/// Registers the opaque `live_schedule` list source + resolve panel.
///
/// Packs declare `kit.list { source: "live_schedule" }` and own horizon / view
/// menus. This boot does not implement Live Sports UX.
abstract final class KitLiveBoot {
  KitLiveBoot._();

  static const listSourceId = 'live_schedule';
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
      final out = <({String id, String label})>[
        for (final p in plugins)
          (
            id: EngineService.normalizeLiveSportPluginId(p.id),
            label: p.name.trim().isEmpty ? p.id : p.name.trim(),
          ),
      ];
      out.addAll(await liveStremioCatalogOptions());
      return out;
    };
    KitTopBarHostHooks.openCatalogSheet = showKitCatalogFilterSheet;
    KitTopBarHostHooks.readCatalogPref = (ref, {required tabId}) {
      final key = kitChromeKeyForTab(tabId);
      if (key.isEmpty) return 'all';
      return ref.watch(kitFeedCatalogFilterProvider(key));
    };
    KitTopBarHostHooks.catalogChipLabel = (filter, options) {
      final id = (filter ?? 'all').trim();
      if (id.isEmpty || id == 'all') return 'All';
      for (final o in options) {
        if (o.id == id) return o.label;
      }
      if (isLiveStremioCatalogFilter(id)) {
        return liveStremioCatalogChipFallbackLabel(id);
      }
      return id;
    };
    KitTopBarHostHooks.catalogChipSelected = (filter) {
      final id = (filter ?? 'all').trim();
      return id.isNotEmpty && id != 'all';
    };
    KitTopBarHostHooks.writeCatalogFilter = (context, filter, {required tabId}) async {
      final key = kitChromeKeyForTab(tabId);
      if (key.isEmpty) return;
      final container = ProviderScope.containerOf(context);
      container.read(kitFeedCatalogFilterProvider(key).notifier).state = filter;
    };
    KitTopBarHostHooks.openScheduleSheet =
        (context, {required currentPref, required onChanged}) async {
      final parsed =
          kitScheduleWindowFromPref(currentPref) ?? kKitScheduleDefaultWindow;
      var curStatus = parsed.status;
      var curHorizon = parsed.horizon;
      await showKitScheduleWindowSheet(
        context,
        status: curStatus,
        horizon: curHorizon,
        onChanged: ({
          KitScheduleStatus? status,
          KitScheduleHorizon? horizon,
        }) {
          if (status != null) curStatus = status;
          if (horizon != null) curHorizon = horizon;
          onChanged(
            kitScheduleWindowPref(status: curStatus, horizon: curHorizon),
          );
        },
      );
    };
    KitTopBarHostHooks.scheduleChipLabel = (pref) {
      final window =
          kitScheduleWindowFromPref(pref) ?? kKitScheduleDefaultWindow;
      return kitScheduleChipLabel(
        status: window.status,
        horizon: window.horizon,
      );
    };
    KitTopBarHostHooks.scheduleChipSelected = (pref) {
      final window =
          kitScheduleWindowFromPref(pref) ?? kKitScheduleDefaultWindow;
      return window.status != KitScheduleStatus.airing;
    };
    KitTopBarHostHooks.readFeedBusy = (ref, {required tabId}) {
      final async = ref.watch(metaFeedCatalogProvider);
      final page = async.asData?.value;
      final busy = async.isLoading || (page?.loadingRemote ?? false);
      final scrape = (page?.loadingProgressLabel ?? '').trim();
      return (
        busy: busy,
        label: scrape.isEmpty ? 'Loading…' : scrape,
      );
    };
    KitTopBarHostHooks.readFeedUpdatedLabel = (ref, {required tabId}) {
      ref.watch(metaFeedCatalogProvider);
      final key = kitChromeKeyForTab(tabId);
      if (key.isEmpty) return null;
      final catalog = ref.watch(kitFeedCatalogFilterProvider(key));
      return liveFeedSessionUpdatedLabel(catalog);
    };
  }

  static Future<String?> resolveTabId() async {
    for (final (_, pl, nav) in await PluginNavRegistry.listNavHubs()) {
      if (pl.types.contains(engineType)) return nav.tabId;
    }
    final pluginId =
        await PluginNavRegistry.pluginIdForEngineType(engineType);
    if (pluginId == null || pluginId.isEmpty) return null;
    return PluginNavRegistry.tabIdForPluginSync(pluginId);
  }

  @visibleForTesting
  static void debugReset() {
    _registered = false;
    MetaSurfaceOpen.unregister(LiveSurfaceOpen.surface);
    matchEventAiringOnlyLiveCheck = null;
    KitTopBarHostHooks.clear();
  }
}
