import 'package:flutter/foundation.dart';
import 'package:forja/shared/host/kit/kit_list_source.dart';
import 'package:forja/shared/host/kit/kit_panel_host.dart';

/// Host-side registration for `kit.list` backends + optional side panels.
///
/// Features register at boot by **host source id** (e.g. `live_schedule`).
/// Optional [pluginId] is only for resolve fallback when pack layout omits
/// `source` — do not pass shipped hub pack ids from foundation hosts.
abstract final class HostListRegistry {
  HostListRegistry._();

  static final Map<String, KitListSource> _bySourceId = {};
  static final Map<String, KitListSource> _byPluginId = {};
  static final Map<String, KitPanelHost> _panelBySourceId = {};
  static final Set<String> _fullPageSourceIds = {};

  static void register(
    KitListSource source, {
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

  /// Side panel for a list source (Live Sports streams panel, …).
  static void registerPanel(KitPanelHost panel) {
    final id = panel.listSourceId.trim();
    if (id.isEmpty) return;
    _panelBySourceId[id] = panel;
  }

  static KitPanelHost? resolvePanel(String sourceId) {
    final id = sourceId.trim();
    if (id.isEmpty) return null;
    return _panelBySourceId[id];
  }

  /// Full-page host bodies (not the poster [KitListWidget] grid).
  static void registerFullPage(String sourceId) {
    final id = sourceId.trim();
    if (id.isEmpty) return;
    _fullPageSourceIds.add(id);
  }

  static bool isFullPageHost(String sourceId) =>
      _fullPageSourceIds.contains(sourceId.trim());

  static KitListSource? resolve({
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
    _panelBySourceId.clear();
    _fullPageSourceIds.clear();
  }
}
