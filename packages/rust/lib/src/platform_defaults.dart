import 'built_in_player_engine.dart';
import 'platform_profile.dart';

/// Per-platform first-run defaults and getter fallbacks.
///
/// [visibleNavIds] is empty on a fresh install — host-core tabs (`iptv`,
/// `live_matches`) stay off until Settings → Addons / Features (RFC-084).
/// Catalog VOD hubs (`home`, `anime`, …) come from packs via
/// [SettingsService.ensureNavIdsKnown].
class PlatformDefaults {
  const PlatformDefaults({
    required this.visibleNavIds,
    required this.externalPlayer,
    required this.builtInPlayerEngine,
    required this.subSize,
    required this.subBottomPadding,
    required this.iptvEpgEnabled,
    required this.playSourceTorrent,
    required this.playSourceStremio,
    required this.playSourceNuvio,
    required this.playSourceEngine,
    required this.playSourceWebstreaming,
    required this.torrentDiskCacheGb,
    required this.showTorrentStatsOverlay,
    required this.playInBackground,
  });

  final List<String> visibleNavIds;
  final String externalPlayer;
  final BuiltInPlayerEngine builtInPlayerEngine;
  final double subSize;
  final double subBottomPadding;
  final bool iptvEpgEnabled;
  final bool playSourceTorrent;
  final bool playSourceStremio;
  final bool playSourceNuvio;
  final bool playSourceEngine;
  final bool playSourceWebstreaming;
  final int torrentDiskCacheGb;
  final bool showTorrentStatsOverlay;

  /// Desktop keeps audio/video when the window blurs; phone/TV pause (process stays warm).
  final bool playInBackground;

  /// Fresh install: no feature tabs on. Addons / Features / packs turn them on.
  static const List<String> defaultNavIds = <String>[];
  static const List<String> phoneNavIds = defaultNavIds;
  static const List<String> androidTvNavIds = defaultNavIds;

  static PlatformDefaults forProfile(PlatformProfile profile) {
    return switch (profile) {
      PlatformProfile.androidTv => const PlatformDefaults(
        visibleNavIds: androidTvNavIds,
        externalPlayer: 'Built-in Player',
        builtInPlayerEngine: BuiltInPlayerEngine.mediaKit,
        subSize: 52,
        subBottomPadding: 48,
        iptvEpgEnabled: true,
        playSourceTorrent: false,
        playSourceStremio: false,
        playSourceNuvio: false,
        playSourceEngine: true,
        playSourceWebstreaming: false,
        torrentDiskCacheGb: 1,
        showTorrentStatsOverlay: false,
        playInBackground: false,
      ),
      PlatformProfile.desktop => const PlatformDefaults(
        visibleNavIds: phoneNavIds,
        externalPlayer: 'Built-in Player',
        builtInPlayerEngine: BuiltInPlayerEngine.mediaKit,
        subSize: 44,
        subBottomPadding: 24,
        iptvEpgEnabled: true,
        playSourceTorrent: false,
        playSourceStremio: false,
        playSourceNuvio: false,
        playSourceEngine: true,
        playSourceWebstreaming: false,
        torrentDiskCacheGb: 2,
        showTorrentStatsOverlay: false,
        playInBackground: true,
      ),
      PlatformProfile.phone => const PlatformDefaults(
        visibleNavIds: phoneNavIds,
        externalPlayer: 'Built-in Player',
        builtInPlayerEngine: BuiltInPlayerEngine.mediaKit,
        subSize: 24,
        subBottomPadding: 24,
        iptvEpgEnabled: true,
        playSourceTorrent: false,
        playSourceStremio: false,
        playSourceNuvio: false,
        playSourceEngine: true,
        playSourceWebstreaming: false,
        torrentDiskCacheGb: 1,
        showTorrentStatsOverlay: false,
        playInBackground: false,
      ),
    };
  }
}
