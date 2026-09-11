import 'package:flutter/foundation.dart';
import 'package:forja/shared/host/kit/my_list_catalog_source.dart';
import 'package:forja/shared/host/kit/host_list_registry.dart';

/// Opaque My List kit ids + foundation registration.
///
/// Registers `source: my_list` so pack layouts resolve without importing
/// list internals. Tab chrome + MetaRuntime `feed` live in the hub pack
/// (`ctx.host.myList.load`); this host only registers the thin adapter.
abstract final class MyListHost {
  MyListHost._();

  static const listSourceId = 'my_list';
  static const hubPluginId = myListHubPluginId;
  static const tabId = 'mylist';

  static bool _registered = false;

  static void ensureRegistered() {
    if (_registered) return;
    _registered = true;
    HostListRegistry.register(
      MyListCatalogSource.instance,
      pluginId: hubPluginId,
    );
  }

  /// Test helper — allows [ensureRegistered] after [HostListRegistry.debugReset].
  @visibleForTesting
  static void debugReset() {
    _registered = false;
  }
}
