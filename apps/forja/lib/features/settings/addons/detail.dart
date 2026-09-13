import 'package:flutter/material.dart';
import 'package:forja/features/settings/addons/pack/pack_addon_settings_section.dart';
import 'package:forja/features/settings/addons/pack/pack_connected_auth_section.dart';
import 'package:forja/features/settings/addons/catalog.dart';
import 'package:forja/features/settings/addons/host/debrid_section.dart';
import 'package:forja/features/settings/addons/host/lan_section.dart';
import 'package:forja/features/settings/addons/host/providers_section.dart';
import 'package:forja/features/settings/addons/host/search_torrents_section.dart';
import 'package:forja/features/settings/addons/host/simkl_panel.dart';
import 'package:forja/features/settings/addons/host/mdblist_panel.dart';
import 'package:forja/features/settings/addons/host/playback_section.dart';
import 'package:forja/features/settings/addons/host/iptv_addon_section.dart';
import 'package:forja/features/settings/shell/visibility.dart';
import 'package:forja/features/settings/ui/settings_ui.dart';

/// Builds the detail body for a given addon ID.
///
/// Pack-declared fields ([PackAddonSettingsSection]) first, then host section
/// when the id is a built-in. Pack-only buckets (RFC-089 discovery) are
/// settings-only.
Widget buildAddonDetailBody(String addonId, SettingsVisibility visibility) {
  final host = _hostAddonDetailBody(addonId, visibility);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      PackAddonSettingsSection(addonId: addonId),
      host,
    ],
  );
}

Widget _hostAddonDetailBody(String addonId, SettingsVisibility visibility) {
  switch (addonId) {
    case SettingsAddonId.playback:
      return SettingsPlaybackSection(visibility: visibility);
    case SettingsAddonId.iptv:
      return const SettingsIptvAddonSection();
    case SettingsAddonId.torrent:
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (visibility.showTorrentEngine)
            const SettingsSearchTorrentsSection(),
          SettingsForjaAddonsSection(
            visibility: visibility,
            indexersOnly: true,
          ),
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
          const PackConnectedAuthSection(),
          const SettingsGroup(
            label: 'Simkl',
            children: [SettingsSimklPanel()],
          ),
          if (visibility.showMdblist)
            const SettingsGroup(
              label: 'MDBlist',
              adminOnly: true,
              children: [SettingsMdblistPanel()],
            ),
        ],
      );
    case SettingsAddonId.lan:
      return const LanSettingsSection();
    default:
      // Pack-contributed settings bucket — fields already above.
      return const SizedBox.shrink();
  }
}
