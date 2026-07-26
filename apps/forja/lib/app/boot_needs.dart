import 'package:forja/shell/nav_config.dart';
import 'package:rust/rust.dart';

/// Profile-scoped boot requirements from navbar + play-source prefs.
///
/// Resolve only after the active profile's settings are merged (profile splash
/// or guest local settings).
///
/// Play-source engines (torrent / stremio / nuvio / webstreaming) also require
/// a VOD tab that can open media details. IPTV + Live Matches alone never warm
/// them.
class BootNeeds {
  const BootNeeds({
    required this.visibleNavIds,
    required this.homeTab,
    required this.tmdb,
    required this.torrent,
    required this.stremio,
    required this.nuvio,
    required this.webstreaming,
    required this.playSourceTorrent,
    required this.playSourceStremio,
    required this.playSourceNuvio,
    required this.playSourceWebstreaming,
    required this.vodTab,
  });

  final List<String> visibleNavIds;
  final bool homeTab;

  /// Prefetch TMDB lists for Home / Search / My List.
  final bool tmdb;

  /// Effective: Direct torrent on **and** a VOD tab visible.
  final bool torrent;

  /// Effective: Stremio on **and** a VOD tab visible.
  final bool stremio;

  /// Effective: Nuvio on **and** a VOD tab visible.
  final bool nuvio;

  /// Effective: Webstreaming on **and** a VOD tab visible.
  final bool webstreaming;

  /// Raw Settings toggles (for skip-reason logs).
  final bool playSourceTorrent;
  final bool playSourceStremio;
  final bool playSourceNuvio;
  final bool playSourceWebstreaming;

  /// Any tab that can open VOD details / Sources.
  final bool vodTab;

  static const _tmdbNavIds = {'home', 'search', 'mylist'};

  /// Working-set tabs that can reach torrent / Stremio / webstreaming Sources.
  static const vodNavIds = {
    'home',
    'search',
    'anime',
    'asian_drama',
    'mylist',
  };

  static Future<BootNeeds> resolve([SettingsService? settings]) async {
    final s = settings ?? SettingsService();
    var nav = await s.getNavbarConfig();
    nav = nav.where((id) => !temporarilyHiddenNavIds.contains(id)).toList();

    final caps = PlatformPlayback.capabilities;
    final playSourceTorrent =
        caps.playSourceTorrent && await s.isPlaySourceTorrentEnabled();
    final playSourceStremio =
        caps.playSourceStremio && await s.isPlaySourceStremioEnabled();
    final playSourceNuvio =
        caps.playSourceNuvio && await s.isPlaySourceNuvioEnabled();
    final playSourceWebstreaming = await s.isPlaySourceWebstreamingEnabled();
    final homeTab = nav.contains('home');
    final tmdb = nav.any(_tmdbNavIds.contains);
    final vodTab = nav.any(vodNavIds.contains);

    return BootNeeds(
      visibleNavIds: nav,
      homeTab: homeTab,
      tmdb: tmdb,
      vodTab: vodTab,
      playSourceTorrent: playSourceTorrent,
      playSourceStremio: playSourceStremio,
      playSourceNuvio: playSourceNuvio,
      playSourceWebstreaming: playSourceWebstreaming,
      torrent: playSourceTorrent && vodTab,
      stremio: playSourceStremio && vodTab,
      nuvio: playSourceNuvio && vodTab,
      webstreaming: playSourceWebstreaming && vodTab,
    );
  }

  @override
  String toString() =>
      'BootNeeds(nav=$visibleNavIds, vodTab=$vodTab, tmdb=$tmdb, '
      'torrent=$torrent (flag=$playSourceTorrent), '
      'stremio=$stremio (flag=$playSourceStremio), '
      'nuvio=$nuvio (flag=$playSourceNuvio), '
      'webstreaming=$webstreaming (flag=$playSourceWebstreaming))';
}
