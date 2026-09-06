import 'package:flutter/material.dart';
import 'package:forja/features/settings/settings_visibility.dart';

/// Stable category IDs for the Settings hub (RFC-033).
abstract final class SettingsCategoryId {
  static const profile = 'profile';
  static const playback = 'playback';
  static const sources = 'sources';
  static const forjaPacks = 'forja_packs';
  static const debrid = 'debrid';
  static const accounts = 'accounts';
  static const lists = 'lists';
  static const data = 'data';
  static const iptvSports = 'iptv_sports';
  static const lan = 'lan';
  static const navigation = 'navigation';
  static const about = 'about';

  /// Addons is the new hub for sources / debrid / iptv_sports / accounts / lan.
  static const addons = sources;

  static const ordered = <String>[
    profile,
    sources, // displayed as "Addons"
    forjaPacks,
    navigation,
    data,
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
  return [
    const SettingsCategoryMeta(
      id: SettingsCategoryId.profile,
      title: 'Profile & account',
      subtitle: 'Profile, cloud sync, sign in',
      icon: Icons.account_circle_outlined,
    ),
    if (visibility.showSourcesCategory)
      const SettingsCategoryMeta(
        id: SettingsCategoryId.sources,
        title: 'Addons',
        subtitle: 'Playback, IPTV, torrents, Stremio, debrid, LAN',
        icon: Icons.extension_rounded,
      ),
    if (visibility.showForjaPacksCategory)
      const SettingsCategoryMeta(
        id: SettingsCategoryId.forjaPacks,
        title: 'Forja Packs',
        subtitle: 'Install and manage plugin packs',
        icon: Icons.inventory_2_outlined,
      ),
    const SettingsCategoryMeta(
      id: SettingsCategoryId.navigation,
      title: 'Features',
      subtitle: 'Tabs, order, default menu',
      icon: Icons.tab_rounded,
    ),
    if (visibility.showDataCategory)
      const SettingsCategoryMeta(
        id: SettingsCategoryId.data,
        title: 'Data & backup',
        subtitle: 'Clear cache, export, import',
        icon: Icons.folder_outlined,
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
