import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/engine/runtime/actions/schedule/kit_schedule_window.dart';
import 'package:forja/shared/engine/runtime/actions/schedule/kit_schedule_window_sheet.dart';
import 'package:forja/shared/engine/runtime/actions/schedule/live_schedule_progressive.dart';
import 'package:forja/shared/engine/runtime/actions/schedule/top_bar_host_hooks.dart';
import 'package:forja/shared/engine/runtime/nav/feed_chrome.dart';
import 'package:forja/shared/engine/runtime/nav/plugin_nav.dart';
import 'package:forja/shared/engine/unlock/live_stremio_catalog.dart';
import 'package:forja_foundation/widgets/chrome/catalog_filter_sheet.dart';

/// Catalog + Status×Horizon schedule sheets for Live Sports top bar.
///
/// Hooks are process-global; paint tree must gate on pack flags
/// (`dynamicCatalogs` / `dynamicSchedule`) so other hubs that reuse action
/// ids like `catalog` stay independent.
void registerLiveScheduleChromeHooks() {
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
  KitTopBarHostHooks.openCatalogSheet = (
    context, {
    required current,
    required options,
  }) =>
      showCatalogFilterSheet(
        context,
        current: current,
        options: options,
      );
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
  KitTopBarHostHooks.readSchedulePref = (ref, {required tabId}) {
    final key = kitChromeKeyForTab(tabId);
    if (key.isEmpty) return kKitScheduleDefaultPref;
    final v = ref.watch(kitFeedHorizonPrefProvider(key));
    return v.trim().isEmpty ? kKitScheduleDefaultPref : v;
  };
  KitTopBarHostHooks.readFeedBusy = (ref, {required tabId}) {
    final pluginId = PluginNavRegistry.pluginIdForTabSync(tabId)?.trim() ?? '';
    if (pluginId.isEmpty) return (busy: false, label: null);
    return ref.watch(liveScheduleFeedBusyProvider(pluginId));
  };
}

void clearLiveScheduleChromeHooks() {
  KitTopBarHostHooks.loadCatalogOptions = null;
  KitTopBarHostHooks.openCatalogSheet = null;
  KitTopBarHostHooks.readCatalogPref = null;
  KitTopBarHostHooks.catalogChipLabel = null;
  KitTopBarHostHooks.catalogChipSelected = null;
  KitTopBarHostHooks.writeCatalogFilter = null;
  KitTopBarHostHooks.openScheduleSheet = null;
  KitTopBarHostHooks.scheduleChipLabel = null;
  KitTopBarHostHooks.scheduleChipSelected = null;
  KitTopBarHostHooks.readSchedulePref = null;
  KitTopBarHostHooks.readFeedBusy = null;
}
