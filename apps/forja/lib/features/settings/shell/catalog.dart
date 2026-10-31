import 'package:flutter/material.dart';
import 'package:forja/features/settings/shell/visibility.dart';
import 'package:forja/l10n/app_localizations.dart';

/// Stable category IDs for the Settings hub (RFC-033).
///
/// Product knobs that used to be top-level (playback, debrid, lan, lists, …)
/// live under Addons — see [SettingsAddonId] and ShellBus deep-link aliases.
abstract final class SettingsCategoryId {
  static const profile = 'profile';
  static const sources = 'sources'; // displayed as "Addons"
  static const forjaPacks = 'forja_packs';
  static const downloads = 'downloads';
  static const data = 'data';
  static const navigation = 'navigation';
  static const about = 'about';

  /// Alias for [sources].
  static const addons = sources;

  static const ordered = <String>[
    profile,
    sources,
    forjaPacks,
    navigation,
    downloads,
    data,
    about,
  ];
}

class SettingsCategoryMeta {
  const SettingsCategoryMeta({
    required this.id,
    required this.titleOf,
    required this.subtitleOf,
    required this.icon,
    this.fillViewport = false,
    this.adminOnly = false,
  });

  final String id;

  /// Resolved per build so the text follows the app language.
  final String Function(AppLocalizations l10n) titleOf;
  final String Function(AppLocalizations l10n) subtitleOf;
  final IconData icon;

  /// When true, the detail body fills the pane (no outer scroll) - for tabbed UIs.
  final bool fillViewport;

  /// Admin-only category — sparkles on the hub tile / page title.
  final bool adminOnly;
}

/// Ordered catalog of Settings categories for the active [visibility].
List<SettingsCategoryMeta> settingsCategories(SettingsVisibility visibility) {
  return [
    SettingsCategoryMeta(
      id: SettingsCategoryId.profile,
      titleOf: (l) => l.settingsCategoryProfileTitle,
      subtitleOf: (l) => l.settingsCategoryProfileSubtitle,
      icon: Icons.account_circle_outlined,
    ),
    if (visibility.showSourcesCategory)
      SettingsCategoryMeta(
        id: SettingsCategoryId.sources,
        titleOf: (l) => l.settingsCategoryAddonsTitle,
        subtitleOf: (l) => l.settingsCategoryAddonsSubtitle,
        icon: Icons.extension_rounded,
      ),
    if (visibility.showForjaPacksCategory)
      SettingsCategoryMeta(
        id: SettingsCategoryId.forjaPacks,
        titleOf: (l) => l.settingsCategoryPacksTitle,
        subtitleOf: (l) => l.settingsCategoryPacksSubtitle,
        icon: Icons.inventory_2_outlined,
      ),
    SettingsCategoryMeta(
      id: SettingsCategoryId.navigation,
      titleOf: (l) => l.settingsCategoryFeaturesTitle,
      subtitleOf: (l) => l.settingsCategoryFeaturesSubtitle,
      icon: Icons.tab_rounded,
    ),
    if (visibility.showDownloadsCategory)
      SettingsCategoryMeta(
        id: SettingsCategoryId.downloads,
        titleOf: (l) => l.settingsCategoryDownloadsTitle,
        subtitleOf: (l) => l.settingsCategoryDownloadsSubtitle,
        icon: Icons.download_rounded,
        fillViewport: true,
      ),
    if (visibility.showDataCategory)
      SettingsCategoryMeta(
        id: SettingsCategoryId.data,
        titleOf: (l) => l.settingsCategoryDataTitle,
        subtitleOf: (l) => l.settingsCategoryDataSubtitle,
        icon: Icons.folder_outlined,
      ),
    SettingsCategoryMeta(
      id: SettingsCategoryId.about,
      titleOf: (l) => l.settingsCategoryAboutTitle,
      subtitleOf: (l) => l.settingsCategoryAboutSubtitle,
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
