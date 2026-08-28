import 'package:forja/app/boot_needs.dart';
import 'package:forja/shared/playback/play_source_effective.dart';
import 'package:forja/shared/sync/sync.dart';
import 'package:forja/shell/nav_config.dart';
import 'package:rust/rust.dart';

/// Which Settings hub tiles / rows match the active profile (nav + play sources).
///
/// VOD tabs ([BootNeeds.vodNavIds]) gate movie/series Settings the same way boot
/// gates engines. IPTV-only / Live-only profiles keep Profile, Playback (IPTV +
/// player), Navigation, About. Android TV hides WebStreamr, Lists, and Data &
/// backup (lean leanback Settings). WebStreamr Settings is admin-only.
class SettingsVisibility {
  const SettingsVisibility({
    required this.playSourceTorrent,
    required this.playSourceStremio,
    required this.playSourceNuvio,
    required this.playSourceEngine,
    required this.playSourceWebstreaming,
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
  final bool playSourceWebstreaming;

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

  /// Torrent search / engine / Jackett / Prowlarr.
  bool get showTorrentEngine =>
      vodTab &&
      playSourceTorrent &&
      PlatformPlayback.capabilities.builtinTorrentSearch;

  /// Nuvio scrapers (own play source).
  bool get showNuvio => vodTab && playSourceNuvio;

  /// Forja plugins (Sources → Forja).
  bool get showEngine => vodTab && playSourceEngine;

  /// Stremio addons — VOD Sources and/or Live Matches sport servers.
  bool get showStremioAddons =>
      (vodTab && playSourceStremio) || liveMatchesNav;

  /// Settings → Sources hub tile (torrent / Stremio / Nuvio / server reliability).
  ///
  /// Torrent / Stremio / Nuvio stay gated by [resolve] platform caps as well.
  /// Server reliability ([showProviderScoring]) stays admin + phone/desktop.
  bool get showSourcesCategory =>
      (vodTab &&
          (playSourceTorrent ||
              playSourceStremio ||
              playSourceNuvio ||
              playSourceEngine ||
              playSourceWebstreaming)) ||
      liveMatchesNav;

  /// Debrid serves torrent + Stremio hashes (+ Nuvio magnets).
  /// Lean Android TV Settings keep Debrid off (desktop relay only).
  /// Admin accounts only (`accounts.is_admin`).
  bool get showDebrid =>
      !_isAndroidTv &&
      vodTab &&
      (playSourceTorrent || playSourceStremio || playSourceNuvio) &&
      AccountFeatures.instance.isAdmin;

  /// Country / extractor / MFP hub — admin accounts only (`accounts.is_admin`).
  bool get showWebstreamr =>
      !_isAndroidTv &&
      vodTab &&
      playSourceWebstreaming &&
      AccountFeatures.instance.isAdmin;

  /// Server reliability / provider order (webstreaming extractors).
  /// Lives under Sources — admin + Webstreaming; hidden on Android TV.
  bool get showProviderScoring =>
      !_isAndroidTv &&
      vodTab &&
      playSourceWebstreaming &&
      AccountFeatures.instance.isAdmin;

  /// Simkl for everyone; Trakt / MDBlist rows admin-only.
  bool get showAccounts => vodTab;

  /// Trakt login / sync — admin accounts only (`accounts.is_admin`).
  bool get showTrakt => vodTab && AccountFeatures.instance.isAdmin;

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

  static Future<SettingsVisibility> resolve([SettingsService? settings]) async {
    final s = settings ?? SettingsService();
    var nav = await s.getNavbarConfig();
    nav = nav.where((id) => !temporarilyHiddenNavIds.contains(id)).toList();

    final lanReady = await PlaySourceEffective.lanDesktopReady();
    final lanEditable = await PlaySourceEffective.lanPlaySourcesEditable();
    return SettingsVisibility(
      playSourceTorrent: await PlaySourceEffective.torrent(s, lanReady),
      playSourceStremio: await PlaySourceEffective.stremio(s, lanReady),
      playSourceNuvio: await PlaySourceEffective.nuvio(s, lanReady),
      playSourceEngine: await PlaySourceEffective.engine(s, lanReady),
      playSourceWebstreaming: await PlaySourceEffective.webstreaming(s),
      showPlaySourceTorrentToggle: await PlaySourceEffective.showTorrentToggle(),
      showPlaySourceStremioToggle: await PlaySourceEffective.showStremioToggle(),
      showPlaySourceNuvioToggle: await PlaySourceEffective.showNuvioToggle(),
      showPlaySourceEngineToggle: await PlaySourceEffective.showEngineToggle(),
      lanPlaySourcesEditable: lanEditable,
      vodTab: nav.any(BootNeeds.vodNavIds.contains),
      iptvNav: nav.contains('iptv'),
      liveMatchesNav: nav.contains('live_matches'),
    );
  }
}
