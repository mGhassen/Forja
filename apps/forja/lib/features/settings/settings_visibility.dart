import 'package:forja/app/boot_needs.dart';
import 'package:forja/shared/lan/lan.dart';
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
    required this.vodTab,
    required this.iptvNav,
    required this.liveMatchesNav,
  });

  final bool playSourceTorrent;
  final bool playSourceStremio;
  final bool playSourceNuvio;
  final bool playSourceWebstreaming;

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
  bool get showDebrid =>
      vodTab && (playSourceTorrent || playSourceStremio || playSourceNuvio);

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

    // Same capability AND as [BootNeeds] — Android TV caps force torrent /
    // Stremio / Nuvio off even if cloud sync wrote phone prefs into KV.
    final caps = PlatformPlayback.capabilities;
    final lanPaired = await LanPrefs.instance.isPaired;
    return SettingsVisibility(
      playSourceTorrent:
          (caps.playSourceTorrent && await s.isPlaySourceTorrentEnabled()) ||
          lanPaired,
      playSourceStremio:
          (caps.playSourceStremio && await s.isPlaySourceStremioEnabled()) ||
          lanPaired,
      playSourceNuvio:
          caps.playSourceNuvio && await s.isPlaySourceNuvioEnabled(),
      playSourceWebstreaming: await s.isPlaySourceWebstreamingEnabled(),
      vodTab: nav.any(BootNeeds.vodNavIds.contains),
      iptvNav: nav.contains('iptv'),
      liveMatchesNav: nav.contains('live_matches'),
    );
  }
}
