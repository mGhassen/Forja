import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/host/layout/kit/kit_schedule_window.dart';
import 'package:forja/shared/engine/feeds/live_feed_aggregate.dart';
import 'package:forja/shared/engine/feeds/live_plugin_engine.dart';
import 'package:forja/shared/engine/feeds/live_stremio_catalog.dart';
import 'package:forja/shared/engine/feeds/match_event.dart';
import 'package:forja/shared/engine/runtime/host_list_registry.dart';
import 'package:forja/shared/host/layout/kit/kit_feed_chrome.dart';
import 'package:forja/shared/engine/runtime/meta_surface_open.dart';
import 'package:forja/shared/engine/runtime/plugin_hub_feed_source.dart';
import 'package:forja/shared/engine/runtime/plugin_nav.dart';
import 'package:forja/shared/host/layout/kit/kit_catalog_filter_sheet.dart';
import 'package:forja/shared/host/layout/kit/kit_schedule_window_sheet.dart';
import 'package:forja/shared/host/layout/kit/kit_top_bar_host_hooks.dart';
import 'package:forja/shared/host/layout/resolve_panel_host.dart';
import 'package:forja/shell/bus/shell_bus.dart';

/// Host route for `open.surface: live` + thin live chrome adapters.
///
/// Schedule rows come from pack MetaRuntime `feed` ([PluginHubFeedListSource]).
/// This never registers a product list source boot class.
abstract final class LiveSurfaceOpen {
  LiveSurfaceOpen._();

  static const surface = 'live';
  static const listSourceId = 'live_schedule';
  static const engineType = 'live_match';

  static String? pendingOpenEntryId;
  static bool _registered = false;

  static bool isLiveMeta(MetaItem item) =>
      item.open?.surface == surface || item.type == engineType;

  /// Panel + surface + top-bar hooks. No host list-source product boot.
  static void ensureRegistered() {
    if (_registered) return;
    _registered = true;
    HostListRegistry.registerPanel(KitResolvePanelHost.instance);
    MetaSurfaceOpen.register(surface, openFromMeta);
    matchEventAiringOnlyLiveCheck = LivePluginEngine.cachedAiringOnlyLive;
    _registerTopBarHooks();
  }

  static void openFromMeta(BuildContext context, MetaItem item) {
    final id = (item.open?.id ?? item.id).trim();
    pendingOpenEntryId = id.isEmpty ? null : id;
    unawaited(_requestTab());
  }

  static Future<void> _requestTab() async {
    final tab = await resolveTabId();
    if (tab == null || tab.isEmpty) return;
    ShellBus.requestTab.value = tab;
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

  static String? takePendingOpenEntryId() {
    final id = pendingOpenEntryId;
    pendingOpenEntryId = null;
    return id;
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
    KitTopBarHostHooks.writeCatalogFilter =
        (context, filter, {required tabId}) async {
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
      final pluginId = PluginNavRegistry.pluginIdForTabSync(tabId)?.trim() ?? '';
      if (pluginId.isEmpty) {
        return (busy: false, label: 'Loading…');
      }
      final async = ref.watch(
        hubPluginCatalogProvider((pluginId: pluginId, status: 'plantowatch')),
      );
      final page = async.asData?.value;
      final busy = async.isLoading || (page?.loadingRemote ?? false);
      return (
        busy: busy,
        label: 'Loading…',
      );
    };
    KitTopBarHostHooks.readFeedUpdatedLabel = (ref, {required tabId}) {
      final pluginId = PluginNavRegistry.pluginIdForTabSync(tabId)?.trim() ?? '';
      if (pluginId.isNotEmpty) {
        ref.watch(
          hubPluginCatalogProvider((pluginId: pluginId, status: 'plantowatch')),
        );
      }
      final key = kitChromeKeyForTab(tabId);
      if (key.isEmpty) return null;
      final catalog = ref.watch(kitFeedCatalogFilterProvider(key));
      return liveFeedSessionUpdatedLabel(catalog);
    };
  }

  @visibleForTesting
  static void debugReset() {
    _registered = false;
    MetaSurfaceOpen.unregister(surface);
    matchEventAiringOnlyLiveCheck = null;
    KitTopBarHostHooks.clear();
  }
}
