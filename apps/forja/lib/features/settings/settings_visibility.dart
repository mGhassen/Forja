import 'package:forja/app/boot_needs.dart';
import 'package:forja/shell/nav_config.dart';
import 'package:rust/rust.dart';

/// Which Settings hub tiles / rows match the active profile (nav + play sources).
///
/// VOD tabs ([BootNeeds.vodNavIds]) gate movie/series Settings the same way boot
/// gates engines. IPTV-only / Live-only profiles keep Profile, Playback (IPTV +
/// player), Data, Navigation, About.
class SettingsVisibility {
  const SettingsVisibility({
    required this.playSourceTorrent,
    required this.playSourceStremio,
    required this.playSourceNuvio,
    required this.playSourceWebstreaming,
    required this.vodTab,
    required this.iptvNav,
  });

  final bool playSourceTorrent;
  final bool playSourceStremio;
  final bool playSourceNuvio;
  final bool playSourceWebstreaming;

  /// Any tab that can open VOD details / Sources (same set as [BootNeeds]).
  final bool vodTab;
  final bool iptvNav;

  /// Play-source toggles under Playback (need a VOD tab to matter).
  bool get showPlaySources => vodTab;

  /// Torrent search / engine / Jackett / Prowlarr.
  bool get showTorrentEngine =>
      vodTab &&
      playSourceTorrent &&
      PlatformPlayback.capabilities.builtinTorrentSearch;

  /// Nuvio scrapers (own play source). Hidden on Android TV for all accounts.
  bool get showNuvio => vodTab && playSourceNuvio;

  /// Stremio addons. Hidden on Android TV for all accounts.
  bool get showStremioAddons => vodTab && playSourceStremio;

  /// Settings → Sources hub tile (torrent / Stremio / Nuvio only).
  ///
  /// Never true on Android TV — [resolve] ANDs platform capabilities so synced
  /// phone prefs cannot reopen these tiles.
  bool get showSourcesCategory =>
      vodTab && (playSourceTorrent || playSourceStremio || playSourceNuvio);

  /// Debrid serves torrent + Stremio hashes (+ Nuvio magnets).
  bool get showDebrid =>
      vodTab && (playSourceTorrent || playSourceStremio || playSourceNuvio);

  bool get showWebstreamr => vodTab && playSourceWebstreaming;

  /// Server reliability / provider order (webstreaming extractors).
  bool get showProviderScoring => vodTab && playSourceWebstreaming;

  /// Trakt / Simkl / MDBlist.
  bool get showAccounts => vodTab;

  /// Embedded Lists screen.
  bool get showLists => vodTab;

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
    return SettingsVisibility(
      playSourceTorrent:
          caps.playSourceTorrent && await s.isPlaySourceTorrentEnabled(),
      playSourceStremio:
          caps.playSourceStremio && await s.isPlaySourceStremioEnabled(),
      playSourceNuvio:
          caps.playSourceNuvio && await s.isPlaySourceNuvioEnabled(),
      playSourceWebstreaming: await s.isPlaySourceWebstreamingEnabled(),
      vodTab: nav.any(BootNeeds.vodNavIds.contains),
      iptvNav: nav.contains('iptv'),
    );
  }
}
