import 'package:rust/rust.dart';

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

  bool get isStreamable => Engine.isVideoFile(name);
}
