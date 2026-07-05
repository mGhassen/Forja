/// Optional Rust torrent engine hooks. Set from app bootstrap when [ForjaEngine] loads.
abstract final class TorrentEngineBackend {
  static bool Function(String magnet)? start;
  static void Function()? stop;
  static bool Function()? isRunning;
  static String Function()? statusJson;

  /// Starts the librqbit HTTP stream server. Returns bound port or 0 on failure.
  static int Function(int preferredPort)? engineStart;

  static int Function()? enginePort;

  static void Function()? engineStop;

  /// Returns stream URL or null on failure.
  static String? Function(
    String magnet, {
    int? season,
    int? episode,
    int? fileIdx,
  })? streamTorrent;
}
