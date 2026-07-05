/// Optional Rust torrent engine hooks. Set from app bootstrap when [ForjaEngine] loads.
abstract final class TorrentEngineBackend {
  static bool Function(String magnet)? start;
  static void Function()? stop;
  static bool Function()? isRunning;
  static String Function()? statusJson;
}
