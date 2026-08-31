import 'package:flutter/foundation.dart';
import 'package:forja/app/boot_needs.dart';
import 'package:forja/shared/catalog/filter.dart';
import 'package:forja/shared/catalog/plugin_nav.dart';
import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/shared/catalog/runtime.dart';
import 'package:forja/shared/catalog/kit/chrome/catalog_chrome_filters.dart';
import 'package:rust/rust.dart';

/// Prefetch default hub layout + first-paint rails into [CatalogCache].
///
/// Driven by pack `layout` (`feed: true` or widgets above Continue) — never a
/// hardcoded home/anime/asian_drama rail list.
Future<void> prefetchDefaultHubLayout(BootNeeds needs) async {
  // Packs just installed — rebuild tab→plugin map before resolving.
  await PluginNavRegistry.refresh();

  final tabId = await resolveDefaultHubTab(needs);
  if (tabId == null) return;

  final pluginId = await PluginNavRegistry.pluginIdForTab(tabId);
  if (pluginId == null || pluginId.isEmpty) return;

  debugPrint('[Init] Prefetch hub ($tabId → $pluginId)');
  late final CatalogEnvelope layoutEnv;
  try {
    layoutEnv = await CatalogRuntime.instance.run(
      pluginId: pluginId,
      action: 'layout',
      params: {'page': tabId},
      timeout: const Duration(seconds: 20),
    );
  } catch (e) {
    debugPrint('[Init] Hub layout prefetch failed (non-fatal): $e');
    return;
  }

  if (!layoutEnv.ok || layoutEnv.data == null) return;
  if (validateLayoutData(layoutEnv.data) != null) return;

  final page = layoutPageForTab(layoutEnv.data!, tabId);
  if (page == null) return;

  if (pageUsesFeed(page)) {
    debugPrint('[Init] Prefetch hub feed ($tabId)');
    try {
      await CatalogRuntime.instance.run(
        pluginId: pluginId,
        action: 'feed',
        params: catalogParamsWithFilters(
          const {},
          filters: catalogChromeFilters(
            tabId: tabId,
            pluginId: pluginId,
          ),
        ),
        timeout: const Duration(seconds: 40),
      );
    } catch (e) {
      debugPrint('[Init] Hub feed prefetch failed (non-fatal): $e');
    }
    return;
  }

  final rails = firstPaintRailsFromPage(page);
  if (rails.isEmpty) return;

  debugPrint('[Init] Prefetch hub rails (${rails.join(', ')})');
  await Future.wait(
    rails.map((rail) => _prefetchRail(pluginId, tabId, rail)),
  );
}

Future<void> _prefetchRail(
  String pluginId,
  String tabId,
  String rail,
) async {
  try {
    await CatalogRuntime.instance.run(
      pluginId: pluginId,
      action: 'rail',
      params: catalogParamsWithFilters(
        {'rail': rail},
        filters: catalogChromeFilters(tabId: tabId, pluginId: pluginId),
      ),
      timeout: const Duration(seconds: 25),
    );
  } catch (e) {
    debugPrint('[Init] Hub rail $rail prefetch failed (non-fatal): $e');
  }
}

/// First visible hub in navbar order, preferring Settings default tab when it
/// is a hub and visible.
Future<String?> resolveDefaultHubTab(
  BootNeeds needs, {
  SettingsService? settings,
}) async {
  final nav = needs.visibleNavIds;
  final defaultTab = await (settings ?? SettingsService()).getDefaultNavTab();
  if (nav.contains(defaultTab) && BootNeeds.isHubNavId(defaultTab)) {
    return defaultTab;
  }
  for (final id in nav) {
    if (BootNeeds.isHubNavId(id)) return id;
  }
  return null;
}

/// Layout page map for [tabId], or the first page when the key is missing.
Map<String, dynamic>? layoutPageForTab(
  Map<String, dynamic> layoutData,
  String tabId,
) {
  final pages = layoutData['pages'];
  if (pages is! Map || pages.isEmpty) return null;
  final raw = pages[tabId] ?? pages.values.first;
  if (raw is! Map) return null;
  return Map<String, dynamic>.from(raw);
}

bool pageUsesFeed(Map<String, dynamic> page) => page['feed'] == true;

/// Rails to warm before dismiss: widgets above the first `continue`, including
/// hero `rail` + `bleed`. Empty when the page uses `feed` (caller runs feed).
List<String> firstPaintRailsFromPage(Map<String, dynamic> page) {
  if (pageUsesFeed(page)) return const [];
  final widgets = page['widgets'];
  if (widgets is! List) return const [];
  final rails = <String>[];
  void add(dynamic raw) {
    final id = raw?.toString().trim() ?? '';
    if (id.isEmpty || rails.contains(id)) return;
    rails.add(id);
  }

  for (final w in widgets) {
    if (w is! Map) continue;
    final type = (w['type'] ?? '').toString().trim();
    if (type == 'continue') break;
    if (type == 'vertical_filters' || type == 'mood') continue;
    add(w['rail']);
    add(w['bleed']);
  }
  return rails;
}
