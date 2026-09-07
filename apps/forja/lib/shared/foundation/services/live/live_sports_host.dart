import 'package:flutter/foundation.dart';
import 'package:forja/shared/foundation/services/host_list_registry.dart';
import 'package:forja/shared/foundation/services/live/live_schedule_catalog_source.dart';
import 'package:forja/shared/foundation/services/live/live_sports_streams_panel_host.dart';

/// Opaque Live Sports kit ids + foundation registration.
///
/// Registers the match-list source and streams panel so pack layouts can
/// resolve `source: live_schedule` without importing play internals.
/// Tab chrome lives only in hub packs — not a host feature root.
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
    HostListRegistry.register(
      LiveScheduleCatalogSource.instance,
      pluginId: hubPluginId,
    );
    HostListRegistry.registerPanel(LiveSportsStreamsPanelHost.instance);
  }

  /// Test helper — allows [ensureRegistered] after [HostListRegistry.debugReset].
  @visibleForTesting
  static void debugReset() {
    _registered = false;
  }
}
