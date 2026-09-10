import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/engine/live/live_plugin_engine.dart';
import 'package:forja/shared/engine/live/live_stremio_catalog.dart';
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
import 'package:forja/shared/foundation/services/schedule/live_sports_hub_merge_upgrade.dart';

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
    // One-shot cards→merged hub (needs WidgetsBinding / SharedPreferences).
    if (_widgetsBindingReady) {
      unawaited(
        LiveSportsHubMergeUpgrade.runOnce().catchError((Object e, StackTrace st) {
          if (kDebugMode) {
            debugPrint('[KitLiveBoot] merge upgrade skipped: $e');
          }
        }),
      );
    }
  }

  static bool get _widgetsBindingReady {
    try {
      WidgetsBinding.instance;
      return true;
    } catch (_) {
      return false;
    }
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
    KitTopBarHostHooks.readCatalogPref = (ref) {
      return ref.watch(kitScheduleFiltersProvider).catalogFilter;
    };
    KitTopBarHostHooks.catalogChipLabel = (filter, options) {
      final id = (filter ?? 'all').trim();
      if (id.isEmpty || id == 'all') return 'All';
      for (final o in options) {
        if (o.id == id) return o.label;
      }
      // Pref before options load — never paint stremio:<full url>.
      if (isLiveStremioCatalogFilter(id)) {
        return liveStremioCatalogChipFallbackLabel(id);
      }
      return id;
    };
    KitTopBarHostHooks.catalogChipSelected = (filter) {
      final id = (filter ?? 'all').trim();
      return id.isNotEmpty && id != 'all';
    };
    KitTopBarHostHooks.writeCatalogFilter = (context, filter) async {
      final container = ProviderScope.containerOf(context);
      await container
          .read(kitScheduleFiltersProvider.notifier)
          .setCatalogFilter(filter);
    };
    KitTopBarHostHooks.readSchedulePref = (ref) {
      return ref.watch(kitScheduleFiltersProvider).schedulePref;
    };
    KitTopBarHostHooks.openScheduleSheet =
        (context, {required currentPref, required onChanged}) async {
      final container = ProviderScope.containerOf(context);
      final filters = container.read(kitScheduleFiltersProvider);
      await showKitScheduleWindowSheet(
        context,
        status: filters.scheduleStatus,
        horizon: filters.scheduleHorizon,
        onChanged: ({status, horizon}) {
          final cur = container.read(kitScheduleFiltersProvider);
          final nextStatus = status ?? cur.scheduleStatus;
          final nextHorizon = horizon ?? cur.scheduleHorizon;
          final pref = kitScheduleWindowPref(
            status: nextStatus,
            horizon: nextHorizon,
          );
          // Mirror into layout scope immediately (chip / focus), then persist.
          onChanged(pref);
          unawaited(
            container.read(kitScheduleFiltersProvider.notifier).setScheduleWindow(
                  status: status,
                  horizon: horizon,
                ),
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
      // Default is Airing — horizon is hidden for that status.
      return window.status != KitScheduleStatus.airing;
    };
    KitTopBarHostHooks.readFeedBusy = (ref) {
      final async = ref.watch(metaFeedCatalogProvider);
      final page = async.asData?.value;
      final busy =
          async.isLoading || (page?.loadingRemote ?? false);
      final scrape = (page?.loadingProgressLabel ?? '').trim();
      return (
        busy: busy,
        label: scrape.isEmpty ? 'Loading live catalogs…' : scrape,
      );
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
