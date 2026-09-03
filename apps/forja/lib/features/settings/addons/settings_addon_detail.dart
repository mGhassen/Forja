import 'package:flutter/material.dart';
import 'package:forja/features/settings/addons/settings_addon_catalog.dart';
import 'package:forja/features/settings/sections/settings_debrid_section.dart';
import 'package:forja/features/settings/sections/settings_iptv_sports_section.dart';
import 'package:forja/features/settings/sections/lan_settings_section.dart';
import 'package:forja/features/settings/sections/settings_providers_section.dart';
import 'package:forja/features/settings/sections/settings_search_torrents_section.dart';
import 'package:forja/features/settings/sections/settings_simkl_panel.dart';
import 'package:forja/features/settings/sections/settings_mdblist_panel.dart';
import 'package:forja/features/settings/addons/sections/settings_iptv_addon_section.dart';
import 'package:forja/features/settings/settings_visibility.dart';

/// Builds the detail body for a given addon ID.
///
/// Reuses existing section widgets — no logic duplication.
Widget buildAddonDetailBody(String addonId, SettingsVisibility visibility) {
  switch (addonId) {
    case SettingsAddonId.iptv:
      return const SettingsIptvAddonSection();
    case SettingsAddonId.liveSports:
      return const SettingsIptvSportsSection();
    case SettingsAddonId.torrent:
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (visibility.showTorrentEngine)
            const SettingsSearchTorrentsSection(),
        ],
      );
    case SettingsAddonId.stremio:
      return SettingsForjaAddonsSection(
        visibility: visibility,
        stremioOnly: true,
      );
    case SettingsAddonId.nuvio:
      return SettingsForjaAddonsSection(
        visibility: visibility,
        nuvioOnly: true,
      );
    case SettingsAddonId.debrid:
      return const SettingsDebridSection();
    case SettingsAddonId.connectedServices:
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SettingsSimklPanel(),
          if (visibility.showMdblist) const SettingsMdblistPanel(),
        ],
      );
    case SettingsAddonId.lan:
      return const LanSettingsSection();
    default:
      return const SizedBox.shrink();
  }
}
