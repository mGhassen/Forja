import 'package:flutter/foundation.dart';
import 'package:forja/features/my_list/catalog/my_list_catalog_source.dart';
import 'package:forja/shared/catalog/host_list_registry.dart';

/// Product constants for the My List hub — feature-owned, not kit.
abstract final class MyListHost {
  MyListHost._();

  static const listSourceId = 'my_list';
  static const hubPluginId = myListHubPluginId;
  static const tabId = 'mylist';

  static bool _registered = false;

  static void ensureRegistered() {
    if (_registered) return;
    _registered = true;
    CatalogHostListRegistry.register(
      MyListCatalogSource.instance,
      pluginId: hubPluginId,
    );
  }

  /// Test helper — allows [ensureRegistered] after [CatalogHostListRegistry.debugReset].
  @visibleForTesting
  static void debugReset() {
    _registered = false;
  }
}
