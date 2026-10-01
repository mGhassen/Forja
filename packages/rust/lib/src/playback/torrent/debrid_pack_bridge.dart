import 'torrent_playback_resolver.dart';

typedef DebridPackResolveFn = Future<TorrentPlaybackUrl?> Function({
  required String magnet,
  int? season,
  int? episode,
  int? fileIdx,
});

/// Host registers pack debrid resolve here — [resolveMagnetForPlayback] forks.
abstract final class DebridPackBridge {
  static DebridPackResolveFn? resolve;
  static String? Function()? activePluginId;
  static String? Function()? activePluginLabel;

  static void register({
    required DebridPackResolveFn resolveFn,
    required String? Function() pluginId,
    required String? Function() pluginLabel,
  }) {
    resolve = resolveFn;
    activePluginId = pluginId;
    activePluginLabel = pluginLabel;
  }
}
