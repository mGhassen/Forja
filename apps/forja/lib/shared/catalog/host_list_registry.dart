import 'package:flutter/foundation.dart';
import 'package:forja/shared/catalog/kit/layout/catalog_kit_list_source.dart';

/// Host-side registration for `kit.list` data backends.
///
/// Features call [register] / [registerFullPage] at boot. Kit widgets resolve
/// opaque [sourceId] or hub [pluginId] — they never import product modules.
abstract final class CatalogHostListRegistry {
  CatalogHostListRegistry._();

  static final Map<String, CatalogKitListSource> _bySourceId = {};
  static final Map<String, CatalogKitListSource> _byPluginId = {};
  static final Set<String> _fullPageSourceIds = {};

  static void register(
    CatalogKitListSource source, {
    String? pluginId,
  }) {
    final id = source.id.trim();
    if (id.isEmpty) return;
    _bySourceId[id] = source;
    final hub = (pluginId ?? source.hubPluginId)?.trim();
    if (hub != null && hub.isNotEmpty) {
      _byPluginId[hub] = source;
    }
  }

  /// Full-page host bodies (not the poster [CatalogKitListWidget] grid).
  static void registerFullPage(String sourceId) {
    final id = sourceId.trim();
    if (id.isEmpty) return;
    _fullPageSourceIds.add(id);
  }

  static bool isFullPageHost(String sourceId) =>
      _fullPageSourceIds.contains(sourceId.trim());

  static CatalogKitListSource? resolve({
    String? sourceId,
    String? pluginId,
  }) {
    final src = sourceId?.trim() ?? '';
    if (src.isNotEmpty) {
      final hit = _bySourceId[src];
      if (hit != null) return hit;
      if (isFullPageHost(src)) return null;
    }
    final hub = pluginId?.trim() ?? '';
    if (hub.isNotEmpty) return _byPluginId[hub];
    return null;
  }

  /// Test helper — clears registrations between cases.
  @visibleForTesting
  static void debugReset() {
    _bySourceId.clear();
    _byPluginId.clear();
    _fullPageSourceIds.clear();
  }
}
