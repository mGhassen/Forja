import 'package:flutter/material.dart';
import 'package:forja/shared/sync/sync.dart';

/// Built-in app addons (Settings → Addons).
///
/// These are **root product surfaces**, not plugin packs. The list is fixed:
/// every addon always appears so it can be activated or not. Installed plugins
/// (Forja Packs, Stremio addons, Nuvio scrapers, live catalogs) add extra
/// settings **inside** an addon's detail page — they do not add or remove
/// rows from this list.
abstract final class SettingsAddonId {
  static const playback = 'playback';
  static const iptv = 'iptv';
  static const liveSports = 'live_sports';
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
    'iptv_sports': liveSports,
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
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;

  /// False for addons without a master on/off (e.g. Connected services).
  final bool hasToggle;
  final bool adminOnly;
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
    id: SettingsAddonId.liveSports,
    title: 'Live Sports',
    subtitle: 'Portal, leagues, Live Matches',
    icon: Icons.sports_rounded,
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

List<SettingsAddonMeta> settingsAddons() {
  final admin = AccountFeatures.instance.isAdmin;
  return [
    for (final a in kSettingsAddons)
      if (!a.adminOnly || admin) a,
  ];
}

SettingsAddonMeta? settingsAddonById(String id) {
  for (final a in kSettingsAddons) {
    if (a.id == id) return a;
  }
  return null;
}
