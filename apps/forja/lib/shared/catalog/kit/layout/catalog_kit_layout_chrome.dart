import 'package:flutter/foundation.dart';

import 'catalog_kit_types.dart';

/// Tracks hub tabs whose pack layout declares kit chrome (`kit.menu` / `kit.tabs`).
///
/// When true, [PluginHubCatalogTopBar] stays hidden — the pack owns top filters.
abstract final class CatalogKitLayoutChromeRegistry {
  CatalogKitLayoutChromeRegistry._();

  static final ValueNotifier<int> revision = ValueNotifier(0);
  static final Set<String> _packOwnedTabs = {};

  static bool packOwnsChrome(String? tabId) {
    final id = tabId?.trim();
    if (id == null || id.isEmpty) return false;
    return _packOwnedTabs.contains(id);
  }

  static void syncFromLayout({
    required String tabId,
    required List<Map<String, dynamic>> widgets,
  }) {
    final id = tabId.trim();
    if (id.isEmpty) return;
    final before = _packOwnedTabs.contains(id);
    if (_layoutDeclaresKitChrome(widgets)) {
      _packOwnedTabs.add(id);
    } else {
      _packOwnedTabs.remove(id);
    }
    if (before != _packOwnedTabs.contains(id)) revision.value++;
  }

  static void unregister(String tabId) {
    final id = tabId.trim();
    if (id.isEmpty) return;
    if (_packOwnedTabs.remove(id)) revision.value++;
  }

  @visibleForTesting
  static void clearForTest() {
    _packOwnedTabs.clear();
    revision.value++;
  }

  static bool _layoutDeclaresKitChrome(Iterable<Map<String, dynamic>> roots) {
    var found = false;
    walkLayoutWidgets(roots, (spec) {
      if (found) return;
      final type = CatalogKitTypes.normalize(
        (spec['type'] ?? '').toString(),
        spec,
      );
      if (type == CatalogKitTypes.menu || type == CatalogKitTypes.tabs) {
        found = true;
      }
    });
    return found;
  }
}
