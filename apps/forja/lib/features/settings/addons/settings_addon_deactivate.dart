import 'package:forja/features/settings/addons/settings_addon_catalog.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/lan/lan.dart';
import 'package:forja/shared/nuvio/nuvio.dart';
import 'package:forja/shared/sync/sync.dart';
import 'package:rust/rust.dart';

/// Turn off nested switches / packs when a built-in addon is deactivated.
///
/// Does not re-enable children when the addon is turned back on.
Future<void> deactivateAddonChildren(String addonId) async {
  switch (addonId) {
    case SettingsAddonId.stremio:
      await _disableStremioAddons();
    case SettingsAddonId.nuvio:
      await _disableNuvioScrapers();
    case SettingsAddonId.torrent:
      await _disablePacksOfKind(PluginRegistry.packKindTorrent);
      await TorrentStreamService().stop();
    case SettingsAddonId.iptv:
      await _disableIptv();
    case SettingsAddonId.lan:
      await LanServerService.instance.stop();
    case SettingsAddonId.debrid:
      break;
  }
}

Future<void> _disableStremioAddons() async {
  final settings = SettingsService();
  final addons = await settings.getStremioAddons();
  for (final addon in addons) {
    if (!StremioAddonFeatures.isEnabled(addon)) continue;
    final updated = Map<String, dynamic>.from(addon);
    updated['enabled'] = false;
    await settings.saveStremioAddon(updated);
  }
  scheduleStremioSyncPush();
}

Future<void> _disableNuvioScrapers() async {
  final nuvio = NuvioService.instance;
  final addons = await nuvio.listAddons();
  for (final addon in addons) {
    await nuvio.setAllScrapersEnabled(
      manifestUrl: addon.manifestUrl,
      enabled: false,
    );
  }
  scheduleNuvioSyncPush();
}

Future<void> _disablePacksOfKind(String kind) async {
  final registry = PluginRegistry.instance;
  final packs = await registry.listPacksRaw();
  for (final pack in packs) {
    if (PluginRegistry.packKindKey(pack) != kind) continue;
    if (!pack.enabled) continue;
    await EngineService.instance.setPackEnabled(
      sourceUrl: pack.sourceUrl,
      enabled: false,
    );
  }
}

Future<void> _disableIptv() async {
  final settings = SettingsService();
  // Cleared while IPTV is off; [setAddonMasterEnabled] restores the platform
  // default when IPTV is turned back on (avoids sticky-off NOW/NEXT).
  await settings.setIptvEpgEnabled(false);
  await _disablePacksOfKind(PluginRegistry.packKindIptv);
}
