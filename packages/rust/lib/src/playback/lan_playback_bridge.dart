import 'torrent_playback_resolver.dart';

/// Host-registered LAN desktop opener (set from `apps/forja` bootstrap).
abstract final class LanPlaybackBridge {
  static Future<TorrentPlaybackUrl?> Function({
    required String magnet,
    int? season,
    int? episode,
    int? fileIdx,
  })? openMagnetOnDesktop;
}
