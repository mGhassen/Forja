import 'package:flutter/material.dart';
import 'package:forja/shared/engine/models/models.dart';
import 'package:forja/shared/foundation/services/pack/pack_addon_settings_spec.dart';
import 'package:forja/shared/sync/sync.dart';

/// Built-in app addons (Settings → Addons).
///
/// Host rows in [kSettingsAddons] are fixed product surfaces. Packs may also
/// contribute **extra** rows via `settings.addon` (RFC-089) — discovered from
/// enabled plugins, never hardcoded pack ids in this catalog.
abstract final class SettingsAddonId {
  static const playback = 'playback';
  static const iptv = 'iptv';
  static const torrent = 'torrent';
  static const stremio = 'stremio';
  static const nuvio = 'nuvio';
  static const debrid = 'debrid';
  static const connectedServices = 'connected_services';
  static const lan = 'lan';

  /// Maps old top-level category IDs to addon IDs for deep-link compat.
  static const categoryAliases = <String, String>{
    'playback': playback,
    'debrid': debrid,
    'accounts': connectedServices,
    'lan': lan,
  };
}

class SettingsAddonMeta {
  const SettingsAddonMeta({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.hasToggle = true,
    this.adminOnly = false,
    this.packContributed = false,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;

  /// False for addons without a master on/off (e.g. Connected services,
  /// pack-contributed settings buckets).
  final bool hasToggle;
  final bool adminOnly;

  /// Invented from an enabled pack `settings.addon` (not in [kSettingsAddons]).
  final bool packContributed;
}

const List<SettingsAddonMeta> kSettingsAddons = [
  SettingsAddonMeta(
    id: SettingsAddonId.playback,
    title: 'Playback',
    subtitle: 'Quality, audio, auto-play',
    icon: Icons.play_circle_outline_rounded,
    hasToggle: false,
  ),
  SettingsAddonMeta(
    id: SettingsAddonId.iptv,
    title: 'IPTV',
    subtitle: 'Portals, EPG, live quality',
    icon: Icons.live_tv_rounded,
  ),
  SettingsAddonMeta(
    id: SettingsAddonId.torrent,
    title: 'Direct torrent',
    subtitle: 'Jackett, Prowlarr, torrent engine',
    icon: Icons.downloading_rounded,
  ),
  SettingsAddonMeta(
    id: SettingsAddonId.stremio,
    title: 'Stremio',
    subtitle: 'Stremio addons',
    icon: Icons.extension_rounded,
  ),
  SettingsAddonMeta(
    id: SettingsAddonId.nuvio,
    title: 'Nuvio',
    subtitle: 'Nuvio scrapers',
    icon: Icons.travel_explore_rounded,
  ),
  SettingsAddonMeta(
    id: SettingsAddonId.debrid,
    title: 'Debrid',
    subtitle: 'Real-Debrid, TorBox, and more',
    icon: Icons.cloud_download_rounded,
    adminOnly: true,
  ),
  SettingsAddonMeta(
    id: SettingsAddonId.connectedServices,
    title: 'Connected services',
    subtitle: 'Simkl; MDBlist (admin)',
    icon: Icons.sync_rounded,
    hasToggle: false,
  ),
  SettingsAddonMeta(
    id: SettingsAddonId.lan,
    title: 'LAN',
    subtitle: 'Desktop server, pairing, torrent relay',
    icon: Icons.lan_outlined,
  ),
];

final Set<String> _hostAddonIds = {for (final a in kSettingsAddons) a.id};

/// Pack-only Addons rows from enabled plugins that declare `settings.addon`
/// for an id that is **not** already a host built-in (those still get fields
/// injected into the host detail via [PackAddonSettingsSection]).
List<SettingsAddonMeta> packContributedAddonMetas(
  Iterable<EnginePlugin> plugins,
) {
  final byAddon = <String, List<(EnginePlugin, PackAddonSettingsSpec)>>{};
  for (final p in plugins) {
    if (!p.enabled) continue;
    final spec = PackAddonSettingsSpec.fromPlugin(p);
    if (spec == null) continue;
    final bucket =
        spec.addonId.isNotEmpty ? spec.addonId : p.id;
    if (_hostAddonIds.contains(bucket)) continue;
    byAddon.putIfAbsent(bucket, () => []).add((p, spec));
  }
  final out = <SettingsAddonMeta>[];
  final sortedIds = byAddon.keys.toList()..sort();
  for (final id in sortedIds) {
    final list = byAddon[id]!;
    list.sort((a, b) {
      final c = a.$2.order.compareTo(b.$2.order);
      if (c != 0) return c;
      return a.$2.pluginName.compareTo(b.$2.pluginName);
    });
    final first = list.first;
    final navLabel = (first.$1.nav?['label'] ?? '').toString().trim();
    final title = navLabel.isNotEmpty
        ? navLabel
        : (first.$2.pluginName.trim().isNotEmpty
            ? first.$2.pluginName
            : id);
    out.add(
      SettingsAddonMeta(
        id: id,
        title: title,
        subtitle: list.length == 1
            ? 'Pack settings'
            : '${list.length} pack settings',
        icon: Icons.tune_rounded,
        hasToggle: false,
        packContributed: true,
      ),
    );
  }
  return out;
}

List<SettingsAddonMeta> settingsAddons({
  List<SettingsAddonMeta> packContributed = const [],
}) {
  final admin = AccountFeatures.instance.isAdmin;
  return [
    for (final a in kSettingsAddons)
      if (!a.adminOnly || admin) a,
    ...packContributed,
  ];
}

SettingsAddonMeta? settingsAddonById(
  String id, {
  List<SettingsAddonMeta> packContributed = const [],
}) {
  for (final a in kSettingsAddons) {
    if (a.id == id) return a;
  }
  for (final a in packContributed) {
    if (a.id == id) return a;
  }
  return null;
}
