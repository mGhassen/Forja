import 'package:api/api/torrent_filter.dart';

/// A file entry inside a torrent payload.
class TorrentFileEntry {
  final int index;
  final String name;
  final int size;

  const TorrentFileEntry({
    required this.index,
    required this.name,
    required this.size,
  });

  bool get isStreamable => TorrentFilter.isVideoFile(name);
}

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

  static List<TorrentFileEntry> Function(String magnet)? listFiles;
}
