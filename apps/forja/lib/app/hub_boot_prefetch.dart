import 'package:flutter/foundation.dart';
import 'package:forja/app/boot_needs.dart';
import 'package:forja/shared/catalog/filter.dart';
import 'package:forja/shared/catalog/plugin_nav.dart';
import 'package:forja/shared/catalog/runtime.dart';
import 'package:forja/shared/catalog/kit/chrome/catalog_chrome_filters.dart';

/// Prefetch default hub layout + first-paint rails into [CatalogCache].
///
/// Replaces the old [BootCache] splash warm: Catalog Shell opens on a cache hit
/// instead of cold-fetching (and re-enriching) every rail.
Future<void> prefetchDefaultHubLayout(BootNeeds needs) async {
  final tabId = _defaultHubTab(needs);
  if (tabId == null) return;

  final pluginId = await PluginNavRegistry.pluginIdForTab(tabId);
  if (pluginId == null || pluginId.isEmpty) return;

  debugPrint('[Init] Prefetch hub ($tabId → $pluginId)');
  try {
    await CatalogRuntime.instance.run(
      pluginId: pluginId,
      action: 'layout',
      params: {'page': tabId},
      timeout: const Duration(seconds: 20),
    );
  } catch (e) {
    debugPrint('[Init] Hub layout prefetch failed (non-fatal): $e');
  }

  if (tabId == 'home' || tabId == 'anime') {
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

  final rails = _firstPaintRails(tabId);
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

/// Same first-screen rails BootCache / old hub screens warmed at splash.
List<String> _firstPaintRails(String tabId) => switch (tabId) {
      // Home: trending→spotlight, featured bleed, popular, now playing→new_releases.
      'home' => const ['spotlight', 'featured', 'popular', 'new_releases'],
      'anime' => const [],
      'asian_drama' => const ['spotlight', 'latest'],
      _ => const [],
    };

String? _defaultHubTab(BootNeeds needs) {
  final nav = needs.visibleNavIds;
  if (nav.contains('home')) return 'home';
  if (nav.contains('anime')) return 'anime';
  if (nav.contains('asian_drama')) return 'asian_drama';
  return null;
}
