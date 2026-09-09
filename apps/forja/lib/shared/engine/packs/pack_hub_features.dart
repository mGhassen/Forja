import 'package:forja/shared/engine/models/models.dart';
import 'package:forja/shared/foundation/protocol/protocol.dart';
import 'package:forja/shared/foundation/services/nav/plugin_nav.dart';
import 'package:forja/shared/sync/bridge/sync_domain_bridge.dart';
import 'package:rust/rust.dart';

/// Hub Features / rail visibility when a pack is installed or toggled (RFC-086).
///
/// [PluginNavRegistry.refresh] only marks hubs known — it does **not** turn
/// tabs on. Call [activatePackHubFeatures] after install / pack ON so the
/// navbar matches toggle-enable (guest onboarding + Official packs used to
/// skip this and left Features empty until the user flipped the pack switch).
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
  static Future<void> activate(EnginePack pack) async {
    final tabs = hubTabIds(pack);
    if (tabs.isEmpty) return;
    final settings = SettingsService();
    noteNavigationDirty();
    for (final id in tabs) {
      await settings.setNavbarTabVisible(id, true, orderAtEnd: true);
    }
    await scheduleNavigationSyncPush();
  }

  /// Pack OFF / uninstall → drop that pack's hub tabs from Features / rail.
  static Future<void> deactivate(EnginePack pack) async {
    final tabs = hubTabIds(pack, requirePluginEnabled: false);
    if (tabs.isEmpty) return;
    final settings = SettingsService();
    noteNavigationDirty();
    for (final id in tabs) {
      await settings.setNavbarTabVisible(id, false);
    }
    await scheduleNavigationSyncPush();
  }

  /// After a batch install: refresh destinations, then default-on each hub pack.
  static Future<void> refreshAndActivateInstalled(
    Iterable<EnginePack> packs,
  ) async {
    await PluginNavRegistry.refresh();
    for (final pack in packs) {
      if (!pack.enabled) continue;
      await activate(pack);
    }
  }
}
