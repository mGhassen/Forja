import 'package:flutter/material.dart';
import 'package:forja/features/settings/settings_visibility.dart';

/// Stable category IDs for the Settings hub (RFC-033).
abstract final class SettingsCategoryId {
  static const profile = 'profile';
  static const playback = 'playback';
  static const sources = 'sources';
  static const webstreamr = 'webstreamr';
  static const debrid = 'debrid';
  static const accounts = 'accounts';
  static const lists = 'lists';
  static const data = 'data';
  static const lan = 'lan';
  static const navigation = 'navigation';
  static const about = 'about';

  static const ordered = <String>[
    profile,
    playback,
    sources,
    webstreamr,
    debrid,
    accounts,
    lists,
    data,
    lan,
    navigation,
    about,
  ];
}

class SettingsCategoryMeta {
  const SettingsCategoryMeta({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.fillViewport = false,
    this.adminOnly = false,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;

  /// When true, the detail body fills the pane (no outer scroll) - for tabbed UIs.
  final bool fillViewport;

  /// Admin-only category — sparkles on the hub tile / page title.
  final bool adminOnly;
}

/// Ordered catalog of Settings categories for the active [visibility].
List<SettingsCategoryMeta> settingsCategories(SettingsVisibility visibility) {
  final sourcesSubtitle = visibility.showTorrentEngine
      ? (visibility.showStremioAddons
          ? 'Torrents, extractors, addons'
          : 'Torrents and scrapers')
      : visibility.showProviderScoring
          ? (visibility.showStremioAddons
              ? 'Server reliability, addons'
              : 'Server reliability')
          : 'Extractors and addons';

  return [
    const SettingsCategoryMeta(
      id: SettingsCategoryId.profile,
      title: 'Profile & account',
      subtitle: 'Profile, cloud sync, sign in',
      icon: Icons.account_circle_outlined,
    ),
    const SettingsCategoryMeta(
      id: SettingsCategoryId.playback,
      title: 'Playback',
      subtitle: 'Play sources, quality, audio, auto-play',
      icon: Icons.play_circle_outline_rounded,
    ),
    if (visibility.showSourcesCategory)
      SettingsCategoryMeta(
        id: SettingsCategoryId.sources,
        title: 'Sources',
        subtitle: sourcesSubtitle,
        icon: Icons.extension_rounded,
      ),
    if (visibility.showWebstreamr)
      const SettingsCategoryMeta(
        id: SettingsCategoryId.webstreamr,
        title: 'WebStreamr',
        subtitle: 'Countries, extractors, MFP, TMDB',
        icon: Icons.language_rounded,
        adminOnly: true,
      ),
    if (visibility.showDebrid)
      const SettingsCategoryMeta(
        id: SettingsCategoryId.debrid,
        title: 'Debrid',
        subtitle: 'Real-Debrid, TorBox, and more',
        icon: Icons.cloud_download_rounded,
        adminOnly: true,
      ),
    if (visibility.showAccounts)
      SettingsCategoryMeta(
        id: SettingsCategoryId.accounts,
        title: 'Connected services',
        subtitle: [
          if (visibility.showTrakt) 'Trakt',
          'Simkl',
          if (visibility.showMdblist) 'MDBlist',
        ].join(', '),
        icon: Icons.sync_rounded,
      ),
    if (visibility.showLists)
      const SettingsCategoryMeta(
        id: SettingsCategoryId.lists,
        title: 'Lists',
        subtitle: 'Trakt & MDBlist custom lists',
        icon: Icons.list_alt_rounded,
        fillViewport: true,
        adminOnly: true,
      ),
    if (visibility.showDataCategory)
      const SettingsCategoryMeta(
        id: SettingsCategoryId.data,
        title: 'Data & backup',
        subtitle: 'Clear cache, export, import',
        icon: Icons.folder_outlined,
      ),
    const SettingsCategoryMeta(
      id: SettingsCategoryId.lan,
      title: 'LAN',
      subtitle: 'Desktop server, pairing, torrent relay',
      icon: Icons.lan_outlined,
    ),
    const SettingsCategoryMeta(
      id: SettingsCategoryId.navigation,
      title: 'Features',
      subtitle: 'Tabs, order, default menu',
      icon: Icons.tab_rounded,
    ),
    const SettingsCategoryMeta(
      id: SettingsCategoryId.about,
      title: 'About',
      subtitle: 'Updates, version, developer',
      icon: Icons.info_outline_rounded,
    ),
  ];
}

SettingsCategoryMeta? settingsCategoryById(
  String id,
  SettingsVisibility visibility,
) {
  for (final c in settingsCategories(visibility)) {
    if (c.id == id) return c;
  }
  return null;
}
