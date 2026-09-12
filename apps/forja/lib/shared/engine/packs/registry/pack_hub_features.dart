import 'package:flutter/foundation.dart';
import 'package:forja/shared/engine/models/models.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja/shared/engine/hub/plugin_nav.dart';
import 'package:forja/shared/sync/bridge/sync_domain_bridge.dart';
import 'package:rust/rust.dart';

/// Hub Features / rail visibility when a pack is installed or toggled (RFC-086).
///
/// [PluginNavRegistry.refresh] only marks hubs known — it does **not** turn
/// tabs on. Call [activate] after install / pack ON so the navbar matches
/// toggle-enable (guest onboarding + Official packs used to skip this and left
/// Features empty until the user flipped the pack switch).
abstract final class PackHubFeatures {
  /// Host Features/rail ids contributed by [pack] kit plugins with valid `nav`.
  static List<String> hubTabIds(
    EnginePack pack, {
    bool requirePluginEnabled = true,
  }) {
    final tabs = <String>[];
    for (final pl in pack.plugins) {
      if (!pl.isKitPlugin) continue;
      if (requirePluginEnabled && !pl.enabled) continue;
      final spec = MetaNavSpec.fromPluginNav(
        pl.nav,
        pluginId: pl.id,
        fallbackLabel: pl.name,
      );
      if (spec == null || !spec.isValid) continue;
      if (SettingsService.addonGatedNavIds.contains(spec.tabId)) continue;
      tabs.add(
        PluginNavRegistry.hostNavId(
          sourceUrl: pack.sourceUrl,
          authorTabId: spec.tabId,
        ),
      );
    }
    return tabs;
  }

  /// Pack ON / fresh install → hub Features + rail on by default (RFC-086 A08).
  static Future<void> activate(EnginePack pack) =>
      refreshAndActivateInstalled([pack]);

  /// Pack OFF / uninstall → drop that pack's hub tabs from Features / rail.
  ///
  /// One [SettingsService.setNavbarConfig] write (not N [setNavbarTabVisible]
  /// notifies) so Settings → Forja Packs is not stormed off the shell mid-remove.
  static Future<void> deactivate(EnginePack pack) async {
    final tabs = hubTabIds(pack, requirePluginEnabled: false);
    if (tabs.isEmpty) return;
    final settings = SettingsService();
    noteNavigationDirty();
    final drop = tabs.toSet();
    final current = await settings.getNavbarConfig();
    final next = [for (final id in current) if (!drop.contains(id)) id];
    if (next.length != current.length) {
      await settings.setNavbarConfig(next);
    }
    await scheduleNavigationSyncPush();
  }

  /// After a batch install: refresh destinations, then default-on missing hubs
  /// in **one** navbar write + **one** sync push (issue 259 — N packs must not
  /// each await a cloud upsert and freeze the shell).
  static Future<void> refreshAndActivateInstalled(
    Iterable<EnginePack> packs,
  ) async {
    await PluginNavRegistry.refresh();
    final toAdd = <String>[];
    final seen = <String>{};
    for (final pack in packs) {
      if (!pack.enabled) continue;
      for (final id in hubTabIds(pack)) {
        if (seen.add(id)) toAdd.add(id);
      }
    }
    if (toAdd.isEmpty) return;

    final settings = SettingsService();
    final current = await settings.getNavbarConfig();
    final missing = [for (final id in toAdd) if (!current.contains(id)) id];
    if (missing.isEmpty) return;

    noteNavigationDirty();
    final nextVisible = [...current, ...missing];
    final order = await settings.getNavbarTabOrder();
    final baseOrder = order.isNotEmpty ? order : current;
    final nextOrder = [
      for (final id in baseOrder)
        if (!missing.contains(id)) id,
      ...missing,
    ];
    await settings.setNavbarConfig(nextVisible, tabOrder: nextOrder);
    if (kDebugMode) {
      debugPrint(
        '[PackHubFeatures] activate hubs ${missing.join(', ')} '
        '(batched ${missing.length})',
      );
    }
    await scheduleNavigationSyncPush();
  }
}
