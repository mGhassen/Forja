import 'package:flutter/foundation.dart';
import 'package:forja/features/live_matches/catalog/live_schedule_catalog_source.dart';
import 'package:forja/features/live_matches/catalog/live_sports_streams_panel_host.dart';
import 'package:forja/shared/catalog/host_list_registry.dart';

/// Live Sports product constants + Forja platform registration.
///
/// Registers the match-list source and streams panel so kit browse can resolve
/// them by opaque id (`live_schedule`) without importing play internals.
abstract final class LiveSportsHost {
  LiveSportsHost._();

  /// Opaque kit.list source id (registry key — not a user-facing name).
  static const listSourceId = 'live_schedule';
  static const hubPluginId = 'live-sports-hub';
  static const tabId = 'live_matches';

  static bool _registered = false;

  static void ensureRegistered() {
    if (_registered) return;
    _registered = true;
    CatalogHostListRegistry.register(
      LiveScheduleCatalogSource.instance,
      pluginId: hubPluginId,
    );
    CatalogHostListRegistry.registerPanel(LiveSportsStreamsPanelHost.instance);
  }

  /// Test helper — allows [ensureRegistered] after [CatalogHostListRegistry.debugReset].
  @visibleForTesting
  static void debugReset() {
    _registered = false;
  }
}
