import 'package:forja/app/boot_needs.dart';
import 'package:forja/shared/playback/play_source_effective.dart';
import 'package:forja/shared/sync/sync.dart';
import 'package:forja/shell/nav_config.dart';
import 'package:rust/rust.dart';

/// Which Settings hub tiles / rows match the active profile (nav + play sources).
///
/// VOD tabs ([BootNeeds.isVodNavId]) gate movie/series Settings the same way
/// boot gates engines. IPTV-only / Live-only profiles keep Profile, Playback
/// (IPTV + player), Navigation, About. Android TV hides Lists and Data &
/// backup (lean leanback Settings).
class SettingsVisibility {
  const SettingsVisibility({
    required this.playSourceTorrent,
    required this.playSourceStremio,
    required this.playSourceNuvio,
    required this.playSourceEngine,
    required this.showPlaySourceTorrentToggle,
    required this.showPlaySourceStremioToggle,
    required this.showPlaySourceNuvioToggle,
    required this.showPlaySourceEngineToggle,
    required this.lanPlaySourcesEditable,
    required this.vodTab,
    required this.iptvNav,
    required this.liveMatchesNav,
  });

  final bool playSourceTorrent;
  final bool playSourceStremio;
  final bool playSourceNuvio;
  final bool playSourceEngine;

  /// Settings → Playback rows (platform play-source caps).
  final bool showPlaySourceTorrentToggle;
  final bool showPlaySourceStremioToggle;
  final bool showPlaySourceNuvioToggle;
  final bool showPlaySourceEngineToggle;

  /// ATV LAN leftover: always editable when the platform exposes the toggles.
  final bool lanPlaySourcesEditable;

  /// Any tab that can open VOD details / Sources (same set as [BootNeeds]).
  final bool vodTab;
  final bool iptvNav;
  final bool liveMatchesNav;

  static bool get _isAndroidTv =>
      SettingsService.platformProfile == PlatformProfile.androidTv;

  /// Play-source toggles under Playback (need a VOD tab to matter).
  bool get showPlaySources => vodTab;

  /// Torrent search / engine (built-in providers, cache, connections).
  bool get showTorrentEngine =>
      vodTab &&
      playSourceTorrent &&
      PlatformPlayback.capabilities.builtinTorrentSearch;

  /// Jackett / Prowlarr indexer config — admin accounts only (`accounts.is_admin`).
  bool get showJackettProwlarr =>
      showTorrentEngine && AccountFeatures.instance.isAdmin;

  /// Nuvio scrapers (own play source).
  bool get showNuvio => vodTab && playSourceNuvio;

  /// Forja plugins (Sources → Forja).
  bool get showEngine => vodTab && playSourceEngine;

  /// Stremio addons — VOD Sources and/or Live Matches sport servers.
  bool get showStremioAddons => (vodTab && playSourceStremio) || liveMatchesNav;

  /// Settings → Sources hub tile (torrent / Stremio / Nuvio / Forja packs).
  ///
  /// Torrent / Stremio / Nuvio stay gated by [resolve] platform caps as well.
  bool get showSourcesCategory =>
      (vodTab &&
          (playSourceTorrent ||
              playSourceStremio ||
              playSourceNuvio ||
              playSourceEngine)) ||
      liveMatchesNav;

  /// Debrid serves torrent + Stremio hashes (+ Nuvio magnets).
  /// Lean Android TV Settings keep Debrid off (desktop relay only).
  /// Admin accounts only (`accounts.is_admin`).
  bool get showDebrid =>
      !_isAndroidTv &&
      vodTab &&
      (playSourceTorrent || playSourceStremio || playSourceNuvio) &&
      AccountFeatures.instance.isAdmin;

  /// Simkl for everyone; MDBlist row admin-only.
  bool get showAccounts => vodTab;

  /// MDBlist API key — admin accounts only (`accounts.is_admin`).
  bool get showMdblist => vodTab && AccountFeatures.instance.isAdmin;

  /// Embedded Lists screen — admin accounts only (`accounts.is_admin`).
  bool get showLists =>
      !_isAndroidTv && vodTab && AccountFeatures.instance.isAdmin;

  /// Settings → Data & backup (cache clear, export/import, IPTV portals CSV).
  bool get showDataCategory => !_isAndroidTv;

  /// Auto next / auto skip (episode flow).
  bool get showVodPlayerExtras => vodTab;

  /// IPTV EPG, portals CSV, portal cache clear.
  bool get showIptvSettings => iptvNav;

  /// Settings → Forja Sports (Live Matches Xtream matcher + live plugins).
  bool get showIptvSportsSettings => liveMatchesNav && iptvNav;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SettingsVisibility &&
        other.playSourceTorrent == playSourceTorrent &&
        other.playSourceStremio == playSourceStremio &&
        other.playSourceNuvio == playSourceNuvio &&
        other.playSourceEngine == playSourceEngine &&
        other.showPlaySourceTorrentToggle == showPlaySourceTorrentToggle &&
        other.showPlaySourceStremioToggle == showPlaySourceStremioToggle &&
        other.showPlaySourceNuvioToggle == showPlaySourceNuvioToggle &&
        other.showPlaySourceEngineToggle == showPlaySourceEngineToggle &&
        other.lanPlaySourcesEditable == lanPlaySourcesEditable &&
        other.vodTab == vodTab &&
        other.iptvNav == iptvNav &&
        other.liveMatchesNav == liveMatchesNav;
  }

  @override
  int get hashCode => Object.hash(
    playSourceTorrent,
    playSourceStremio,
    playSourceNuvio,
    playSourceEngine,
    showPlaySourceTorrentToggle,
    showPlaySourceStremioToggle,
    showPlaySourceNuvioToggle,
    showPlaySourceEngineToggle,
    lanPlaySourcesEditable,
    vodTab,
    iptvNav,
    liveMatchesNav,
  );

  static Future<SettingsVisibility> resolve([SettingsService? settings]) async {
    final s = settings ?? SettingsService();
    var nav = await s.getNavbarConfig();
    nav = nav.where((id) => !archivedNavIds.contains(id)).toList();

    final lanReady = await PlaySourceEffective.lanDesktopReady();
    final lanEditable = await PlaySourceEffective.lanPlaySourcesEditable();
    return SettingsVisibility(
      playSourceTorrent: await PlaySourceEffective.torrent(s, lanReady),
      playSourceStremio: await PlaySourceEffective.stremio(s, lanReady),
      playSourceNuvio: await PlaySourceEffective.nuvio(s, lanReady),
      playSourceEngine: await PlaySourceEffective.engine(s, lanReady),
      showPlaySourceTorrentToggle:
          await PlaySourceEffective.showTorrentToggle(),
      showPlaySourceStremioToggle:
          await PlaySourceEffective.showStremioToggle(),
      showPlaySourceNuvioToggle: await PlaySourceEffective.showNuvioToggle(),
      showPlaySourceEngineToggle: await PlaySourceEffective.showEngineToggle(),
      lanPlaySourcesEditable: lanEditable,
      vodTab: nav.any(BootNeeds.isVodNavId),
      iptvNav: nav.contains('iptv'),
      liveMatchesNav: nav.contains('live_matches'),
    );
  }
}
