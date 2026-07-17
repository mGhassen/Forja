import 'package:flutter/material.dart';
import 'package:rust/rust.dart';

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
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;

  /// When true, the detail body fills the pane (no outer scroll) — for tabbed UIs.
  final bool fillViewport;
}

/// Ordered catalog of Settings categories.
List<SettingsCategoryMeta> settingsCategories() {
  final torrent = PlatformPlayback.capabilities.builtinTorrentSearch;
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
      subtitle: 'Sources, quality, audio, auto-play',
      icon: Icons.play_circle_outline_rounded,
    ),
    SettingsCategoryMeta(
      id: SettingsCategoryId.sources,
      title: 'Sources',
      subtitle: torrent
          ? 'Torrents, extractors, addons'
          : 'Extractors and addons',
      icon: Icons.extension_rounded,
    ),
    const SettingsCategoryMeta(
      id: SettingsCategoryId.webstreamr,
      title: 'WebStreamr',
      subtitle: 'Countries, extractors, MFP, TMDB',
      icon: Icons.language_rounded,
    ),
    const SettingsCategoryMeta(
      id: SettingsCategoryId.debrid,
      title: 'Debrid',
      subtitle: 'Real-Debrid, TorBox, and more',
      icon: Icons.cloud_download_rounded,
    ),
    const SettingsCategoryMeta(
      id: SettingsCategoryId.accounts,
      title: 'Connected services',
      subtitle: 'Trakt, Simkl, MDBlist',
      icon: Icons.sync_rounded,
    ),
    const SettingsCategoryMeta(
      id: SettingsCategoryId.lists,
      title: 'Lists',
      subtitle: 'Trakt & MDBlist custom lists',
      icon: Icons.list_alt_rounded,
      fillViewport: true,
    ),
    const SettingsCategoryMeta(
      id: SettingsCategoryId.data,
      title: 'Data & backup',
      subtitle: 'Clear cache, export, import',
      icon: Icons.folder_outlined,
    ),
    const SettingsCategoryMeta(
      id: SettingsCategoryId.navigation,
      title: 'Navigation',
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

SettingsCategoryMeta? settingsCategoryById(String id) {
  for (final c in settingsCategories()) {
    if (c.id == id) return c;
  }
  return null;
}
