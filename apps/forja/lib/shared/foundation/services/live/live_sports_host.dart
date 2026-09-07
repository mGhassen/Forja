import 'package:flutter/foundation.dart';
import 'package:forja/shared/foundation/services/host_list_registry.dart';
import 'package:forja/shared/foundation/services/live/live_schedule_catalog_source.dart';
import 'package:forja/shared/foundation/services/live/live_sports_streams_panel_host.dart';

/// Live Sports host services — list source + streams panel registration.
///
/// Packs set `kit.list { source: "live_schedule" }`. Host never binds a
/// shipped hub plugin id (`live-sports-hub`, …).
abstract final class LiveSportsHost {
  LiveSportsHost._();

  /// Host service id for [HostListRegistry] / pack `source`.
  static const listSourceId = 'live_schedule';

  /// Addons capability + list-pack nav tab id (not a plugin id).
  static const tabId = 'live_matches';

  static bool _registered = false;

  static void ensureRegistered() {
    if (_registered) return;
    _registered = true;
    HostListRegistry.register(LiveScheduleCatalogSource.instance);
    HostListRegistry.registerPanel(LiveSportsStreamsPanelHost.instance);
  }

  /// Test helper — allows [ensureRegistered] after [HostListRegistry.debugReset].
  @visibleForTesting
  static void debugReset() {
    _registered = false;
  }
}
