import 'package:forja/shell/nav_config.dart';
import 'package:forja/shared/catalog/plugin_nav.dart';
import 'package:forja/shared/playback/play_source_effective.dart';
import 'package:rust/rust.dart';

/// Profile-scoped boot requirements from navbar + play-source prefs.
///
/// Resolve only after the active profile's settings are merged (profile splash
/// or guest local settings).
///
/// Play-source engines (torrent / stremio / nuvio / engine) also require a VOD
/// tab that can open media details. IPTV + Live Matches alone never warm them.
class BootNeeds {
  const BootNeeds({
    required this.visibleNavIds,
    required this.hubTab,
    required this.catalogTab,
    required this.torrent,
    required this.stremio,
    required this.nuvio,
    required this.engine,
    required this.playSourceTorrent,
    required this.playSourceStremio,
    required this.playSourceNuvio,
    required this.playSourceEngine,
    required this.vodTab,
  });

  final List<String> visibleNavIds;

  /// Any contributed catalog hub tab is visible (not IPTV / Live / Settings).
  final bool hubTab;

  /// Contributed catalog hub tab — splash catalog affinity (prefetch / copy).
  final bool catalogTab;

  /// Effective: Direct torrent on **and** a VOD tab visible.
  final bool torrent;

  /// Effective: Stremio on **and** a VOD tab visible.
  final bool stremio;

  /// Effective: Nuvio on **and** a VOD tab visible.
  final bool nuvio;

  /// Effective: Forja engine on **and** a VOD tab visible.
  final bool engine;

  /// Raw Settings toggles (for skip-reason logs).
  final bool playSourceTorrent;
  final bool playSourceStremio;
  final bool playSourceNuvio;
  final bool playSourceEngine;

  /// Any tab that can open VOD details / Sources.
  final bool vodTab;

  /// Install/warm Forja engine plugin packs at boot (hub, providers, torrent, nuvio).
  ///
  /// IPTV + Live Matches alone defer pack install to first use (Live Matches,
  /// Settings → Forja Sports, VOD Sources) — no splash download banner.
  bool get needsForjaPluginWarm =>
      catalogTab || engine || torrent || nuvio;

  /// Any contributed catalog hub tab.
  static bool isVodNavId(String id) {
    if (archivedNavIds.contains(id)) return false;
    if (PluginNavRegistry.coreShellNavIds.contains(id)) return false;
    return PluginNavRegistry.isHubTab(id);
  }

  /// Catalog hub tab contributed by an installed enabled pack ([PluginNavRegistry.refresh]).
  static bool isHubNavId(String id) {
    if (archivedNavIds.contains(id)) return false;
    return PluginNavRegistry.isHubTab(id);
  }

  /// Splash hold line after boot work finishes early.
  String get openingStatusLabel {
    final liveIptv = !vodTab &&
        (visibleNavIds.contains('iptv') ||
            visibleNavIds.contains('live_matches'));
    if (liveIptv) return 'Opening Live & IPTV…';

    for (final id in visibleNavIds) {
      if (!isHubNavId(id)) continue;
      final label = PluginNavRegistry.destinations[id]?.label.trim();
      if (label != null && label.isNotEmpty) return 'Opening $label…';
      return 'Warming catalog…';
    }
    if (catalogTab) return 'Warming catalog…';
    return 'Just a moment…';
  }

  static Future<BootNeeds> resolve([SettingsService? settings]) async {
    final s = settings ?? SettingsService();
    await PluginNavRegistry.refresh();
    var nav = await s.getNavbarConfig();
    nav = nav
        .where((id) => !archivedNavIds.contains(id))
        .where(PluginNavRegistry.isContributed)
        .toList();
    if (!PlatformPlayback.capabilities.builtinTorrentSearch) {
      nav = nav
          .where((id) => !PlatformPlayback.torrentNavIds.contains(id))
          .toList();
    }

    final lanReady = await PlaySourceEffective.lanDesktopReady();
    final playSourceTorrent = await PlaySourceEffective.torrent(s, lanReady);
    final playSourceStremio = await PlaySourceEffective.stremio(s, lanReady);
    final playSourceNuvio = await PlaySourceEffective.nuvio(s, lanReady);
    final playSourceEngine = await PlaySourceEffective.engine(s, lanReady);
    final hubTab = nav.any(PluginNavRegistry.isHubTab);
    final catalogTab = hubTab;
    final vodTab = hubTab;

    return BootNeeds(
      visibleNavIds: nav,
      hubTab: hubTab,
      catalogTab: catalogTab,
      vodTab: vodTab,
      playSourceTorrent: playSourceTorrent,
      playSourceStremio: playSourceStremio,
      playSourceNuvio: playSourceNuvio,
      playSourceEngine: playSourceEngine,
      torrent: playSourceTorrent && vodTab,
      stremio: playSourceStremio && vodTab,
      nuvio: playSourceNuvio && vodTab,
      engine: playSourceEngine && vodTab,
    );
  }

  @override
  String toString() =>
      'BootNeeds(nav=$visibleNavIds, vodTab=$vodTab, hubTab=$hubTab, '
      'catalogTab=$catalogTab, '
      'torrent=$torrent (flag=$playSourceTorrent), '
      'stremio=$stremio (flag=$playSourceStremio), '
      'nuvio=$nuvio (flag=$playSourceNuvio), '
      'engine=$engine (flag=$playSourceEngine))';
}
