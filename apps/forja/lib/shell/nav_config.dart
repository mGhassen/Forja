import 'package:flutter/material.dart';
import 'package:forja/features/iptv/screens/iptv_pt_screen.dart';
import 'package:forja/features/live_matches/live_matches_screen.dart';
import 'package:forja/features/settings/settings_screen.dart';
import 'package:forja/shared/catalog/forja_host_assets.dart';
import 'package:forja/shared/catalog/plugin_nav.dart';
import 'package:forja/shell/nav_destination.dart';

export 'package:forja/shell/nav_destination.dart';

/// Tab ids under [features/archive/] — stripped from shell, Features settings,
/// and saved nav configs. Re-register in [coreNavDestinations] to restore.
const Set<String> archivedNavIds = {
  'search',
  'discover',
  'similar',
  'downloader',
  'magnet',
  'audiobooks',
  'books',
  'music',
  'comics',
  'manga',
  'jellyfin',
  'anime_arabic',
  'arabic',
};

@Deprecated('Use archivedNavIds')
const Set<String> temporarilyHiddenNavIds = archivedNavIds;

/// In-scope app-owned shell destinations
const Map<String, NavDestination> coreNavDestinations = {
  'live_matches': NavDestination(
    id: 'live_matches',
    icon: Icons.sports_soccer_outlined,
    activeIcon: Icons.sports_soccer_rounded,
    label: 'Live Sports',
    iconAsset: ForjaHostAssets.flutterNavLiveMatches,
  ),
  'iptv': NavDestination(
    id: 'iptv',
    icon: Icons.live_tv_outlined,
    activeIcon: Icons.live_tv,
    label: 'IPTV',
    iconAsset: ForjaHostAssets.flutterNavIptv,
  ),
  'settings': NavDestination(
    id: 'settings',
    icon: Icons.settings_outlined,
    activeIcon: Icons.settings,
    label: 'Settings',
  ),
};

/// Core + hub destinations from [PluginNavRegistry] (plugin `nav` specs).
Map<String, NavDestination> get navDestinations => {
  for (final e in {
    ...coreNavDestinations,
    ...PluginNavRegistry.destinations,
  }.entries)
    if (!archivedNavIds.contains(e.key)) e.key: e.value,
};

const Map<String, Color> coreNavDestinationAccentColors = {
  'live_matches': Color(0xFFFB923C),
  'iptv': Color(0xFF22D3EE),
  'settings': Color(0xFF94A3B8),
};

Map<String, Color> get navDestinationAccentColors => {
  ...coreNavDestinationAccentColors,
  ...PluginNavRegistry.accents,
};

/// Lazy tab factories — widgets are created on first visit only.
final Map<String, TabBuilder> coreNavTabBuilders = {
  'live_matches': LiveMatchesScreen.new,
  'iptv': IptvPtScreen.new,
  'settings': SettingsScreen.new,
};

/// Core builders + catalog hub builders from [PluginNavRegistry].
Map<String, TabBuilder> get navTabBuilders => {
  for (final e in {
    ...coreNavTabBuilders,
    ...PluginNavRegistry.builders,
  }.entries)
    if (!archivedNavIds.contains(e.key)) e.key: e.value,
};
