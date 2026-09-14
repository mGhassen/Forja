import 'package:flutter/material.dart';
import 'package:forja/shared/engine/runtime/chrome/portals_action_host.dart';
import 'package:forja/shared/engine/runtime/open/meta_surface_open.dart';
import 'package:forja/shared/engine/runtime/kit/live_schedule_feed.dart';
import 'package:forja/shared/engine/runtime/kit/plugin_feed_source.dart';
import 'package:forja/shared/host/packs/services/pack_settings_store.dart';
import 'package:forja/shared/player/sources/resolve_panel_host.dart';
import 'package:forja/shell/bus/shell_bus.dart';
import 'package:forja/shared/engine/runtime/kit/list/host_list_registry.dart';
import 'package:forja/shared/engine/runtime/kit/list/list_open_mode.dart';
import 'package:forja_foundation/protocol/protocol.dart';

/// `open.surface: live` → switch to pack [tabId] from open payload (opaque).
abstract final class LiveSurfaceOpen {
  LiveSurfaceOpen._();

  static const surface = 'live';

  /// Pack `kit.list` source id for live schedule / portals hoist (opaque).
  static const listSourceId = 'live_schedule';

  static String? pendingOpenEntryId;
  static bool _registered = false;

  static void ensureRegistered() {
    if (_registered) return;
    _registered = true;
    HostListRegistry.registerPanel(KitResolvePanelHost.instance);
    HostListRegistry.packFeedResolver = ({sourceId, pluginId}) {
      final hub = pluginId?.trim() ?? '';
      if (hub.isEmpty) return null;
      final src = sourceId?.trim() ?? '';
      if (src == listSourceId) return LiveScheduleFeedSource(hub);
      return PluginFeedSource(hub);
    };
    KitListOpenModeHooks.revision = PackSettingsStore.revision;
    KitListOpenModeHooks.getString = (
      pluginId,
      fieldId, {
      required defaultValue,
    }) =>
        PackSettingsStore.getString(
          pluginId,
          fieldId,
          defaultValue: defaultValue,
        );
    MetaSurfaceOpen.register(surface, openFromMeta);
    registerLiveScheduleChromeHooks();
    PortalsActionHost.registerHoistSource(listSourceId);
  }

  static void openFromMeta(BuildContext context, MetaItem item) {
    final open = item.open;
    final id = (open?.id ?? item.id).trim();
    pendingOpenEntryId = id.isEmpty ? null : id;
    final tab = (open?.extraString('tabId') ?? '').trim();
    if (tab.isEmpty) return;
    ShellBus.requestTab.value = tab;
  }

  static String? takePendingOpenEntryId() {
    final id = pendingOpenEntryId;
    pendingOpenEntryId = null;
    return id;
  }

  @visibleForTesting
  static void debugReset() {
    _registered = false;
    pendingOpenEntryId = null;
    MetaSurfaceOpen.unregister(surface);
    clearLiveScheduleChromeHooks();
    KitListOpenModeHooks.clear();
    HostListRegistry.packFeedResolver = null;
  }
}
