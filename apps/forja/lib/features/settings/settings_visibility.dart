import 'package:forja/app/boot_needs.dart';
import 'package:forja/shared/playback/play_source_effective.dart';
import 'package:forja/shell/nav_config.dart';
import 'package:rust/rust.dart';

/// Which Settings hub tiles / rows match the active profile (nav + play sources).
///
/// VOD tabs ([BootNeeds.vodNavIds]) gate movie/series Settings the same way boot
/// gates engines. IPTV-only / Live-only profiles keep Profile, Playback (IPTV +
/// player), Navigation, About. Android TV also hides Sources, WebStreamr, Lists,
/// and Data & backup (lean leanback Settings).
class SettingsVisibility {
  const SettingsVisibility({
    required this.playSourceTorrent,
    required this.playSourceStremio,
    required this.playSourceNuvio,
    required this.playSourceWebstreaming,
    required this.showPlaySourceTorrentToggle,
    required this.showPlaySourceStremioToggle,
    required this.showPlaySourceNuvioToggle,
    required this.vodTab,
    required this.iptvNav,
    required this.liveMatchesNav,
  });

  final bool playSourceTorrent;
  final bool playSourceStremio;
  final bool playSourceNuvio;
  final bool playSourceWebstreaming;

  /// Settings → Playback rows (caps, or LAN-paired ATV client).
  final bool showPlaySourceTorrentToggle;
  final bool showPlaySourceStremioToggle;
  final bool showPlaySourceNuvioToggle;

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

  /// Nuvio scrapers (own play source). Hidden on Android TV for all accounts.
  bool get showNuvio => vodTab && playSourceNuvio;

  /// Stremio addons — VOD Sources and/or Live Matches sport servers.
  bool get showStremioAddons =>
      (vodTab && playSourceStremio) || liveMatchesNav;

  /// Settings → Sources hub tile (torrent / Stremio / Nuvio / server reliability).
  ///
  /// Never on Android TV — phone/desktop only. Torrent / Stremio / Nuvio stay
  /// gated by [resolve] platform caps as well.
  bool get showSourcesCategory =>
      !_isAndroidTv &&
      ((vodTab &&
              (playSourceTorrent ||
                  playSourceStremio ||
                  playSourceNuvio ||
                  playSourceWebstreaming)) ||
          liveMatchesNav);

  /// Debrid serves torrent + Stremio hashes (+ Nuvio magnets).
  /// Lean Android TV Settings keep Debrid off (desktop relay only).
  bool get showDebrid =>
      !_isAndroidTv &&
      vodTab &&
      (playSourceTorrent || playSourceStremio || playSourceNuvio);

  bool get showWebstreamr =>
      !_isAndroidTv && vodTab && playSourceWebstreaming;

  /// Server reliability / provider order (webstreaming extractors).
  /// Lives under Sources — hidden with that category on Android TV.
  bool get showProviderScoring =>
      !_isAndroidTv && vodTab && playSourceWebstreaming;

  /// Trakt / Simkl / MDBlist.
  bool get showAccounts => vodTab;

  /// Embedded Lists screen.
  bool get showLists => !_isAndroidTv && vodTab;

  /// Settings → Data & backup (cache clear, export/import, IPTV portals CSV).
  bool get showDataCategory => !_isAndroidTv;

  /// Auto next / auto skip (episode flow).
  bool get showVodPlayerExtras => vodTab;

  /// IPTV EPG, portals CSV, portal cache clear.
  bool get showIptvSettings => iptvNav;

  static Future<SettingsVisibility> resolve([SettingsService? settings]) async {
    final s = settings ?? SettingsService();
    var nav = await s.getNavbarConfig();
    nav = nav.where((id) => !temporarilyHiddenNavIds.contains(id)).toList();

    return SettingsVisibility(
      playSourceTorrent: await PlaySourceEffective.torrent(s),
      playSourceStremio: await PlaySourceEffective.stremio(s),
      playSourceNuvio: await PlaySourceEffective.nuvio(s),
      playSourceWebstreaming: await s.isPlaySourceWebstreamingEnabled(),
      showPlaySourceTorrentToggle: await PlaySourceEffective.showTorrentToggle(),
      showPlaySourceStremioToggle: await PlaySourceEffective.showStremioToggle(),
      showPlaySourceNuvioToggle: await PlaySourceEffective.showNuvioToggle(),
      vodTab: nav.any(BootNeeds.vodNavIds.contains),
      iptvNav: nav.contains('iptv'),
      liveMatchesNav: nav.contains('live_matches'),
    );
  }
}
