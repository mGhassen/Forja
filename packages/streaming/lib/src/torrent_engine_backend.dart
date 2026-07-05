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
