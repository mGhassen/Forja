import 'platform_profile.dart';

/// Per-platform first-run defaults and getter fallbacks.
class PlatformDefaults {
  const PlatformDefaults({
    required this.visibleNavIds,
    required this.externalPlayer,
    required this.subSize,
    required this.subBottomPadding,
    required this.iptvEpgEnabled,
    required this.playSourceTorrent,
    required this.playSourceStremio,
    required this.playSourceWebstreaming,
    required this.torrentRamCacheMb,
    required this.showTorrentStatsOverlay,
  });

  final List<String> visibleNavIds;
  final String externalPlayer;
  final double subSize;
  final double subBottomPadding;
  final bool iptvEpgEnabled;
  final bool playSourceTorrent;
  final bool playSourceStremio;
  final bool playSourceWebstreaming;
  final int torrentRamCacheMb;
  final bool showTorrentStatsOverlay;

  static const List<String> defaultNavIds = [
    'search',
    'home',
    'asian_drama',
    'anime',
    'iptv',
    'live_matches',
    'mylist',
  ];
  static const List<String> phoneNavIds = defaultNavIds;
  static const List<String> androidTvNavIds = defaultNavIds;

  static PlatformDefaults forProfile(PlatformProfile profile) {
    return switch (profile) {
      PlatformProfile.androidTv => const PlatformDefaults(
        visibleNavIds: androidTvNavIds,
        externalPlayer: 'Built-in Player',
        subSize: 52,
        subBottomPadding: 48,
        iptvEpgEnabled: true,
        playSourceTorrent: false,
        playSourceStremio: false,
        playSourceWebstreaming: true,
        torrentRamCacheMb: 128,
        showTorrentStatsOverlay: false,
      ),
      PlatformProfile.desktop => const PlatformDefaults(
        visibleNavIds: phoneNavIds,
        externalPlayer: 'Built-in Player',
        subSize: 44,
        subBottomPadding: 24,
        iptvEpgEnabled: true,
        playSourceTorrent: true,
        playSourceStremio: true,
        playSourceWebstreaming: true,
        torrentRamCacheMb: 200,
        showTorrentStatsOverlay: false,
      ),
      PlatformProfile.phone => const PlatformDefaults(
        visibleNavIds: phoneNavIds,
        externalPlayer: 'Built-in Player',
        subSize: 24,
        subBottomPadding: 24,
        iptvEpgEnabled: true,
        playSourceTorrent: true,
        playSourceStremio: true,
        playSourceWebstreaming: true,
        torrentRamCacheMb: 200,
        showTorrentStatsOverlay: false,
      ),
    };
  }
}
