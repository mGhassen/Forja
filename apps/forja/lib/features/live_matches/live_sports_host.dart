import 'package:flutter/foundation.dart';
import 'package:forja/shared/catalog/host_list_registry.dart';

/// Product constants for Live Sports — feature-owned, not kit.
abstract final class LiveSportsHost {
  LiveSportsHost._();

  static const listSourceId = 'live_schedule';
  static const hubPluginId = 'live-sports-hub';
  static const tabId = 'live_matches';

  static bool _registered = false;

  static void ensureRegistered() {
    if (_registered) return;
    _registered = true;
    CatalogHostListRegistry.registerFullPage(listSourceId);
  }

  /// Test helper — allows [ensureRegistered] after [CatalogHostListRegistry.debugReset].
  @visibleForTesting
  static void debugReset() {
    _registered = false;
  }
}
