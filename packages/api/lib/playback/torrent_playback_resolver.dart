import 'package:api/api/debrid_api.dart';
import 'package:rust/rust.dart';

class TorrentPlaybackUrl {
  final String url;
  final int? fileIndex;

  const TorrentPlaybackUrl(this.url, {this.fileIndex});
}

/// Resolves a magnet to a playable HTTP URL via debrid or the local engine.
///
/// When [useDebrid] is true, only debrid is used — invalid credentials fail
/// fast with [DebridAuthException] (no silent fallback to local engine).
Future<TorrentPlaybackUrl?> resolveMagnetForPlayback({
  required String magnet,
  required bool useDebrid,
  required String debridService,
  required bool localTorrentEngine,
  int? season,
  int? episode,
  int? fileIdx,
}) async {
  if (useDebrid && debridService != 'None') {
    try {
      final files = await DebridApi().resolveByService(
        debridService,
        magnet,
        season: season,
        episode: episode,
      );
      if (files.isNotEmpty) {
        return TorrentPlaybackUrl(files.first.downloadUrl, fileIndex: 0);
      }
    } catch (e) {
      if (isDebridAuthFailure(e)) {
        throw DebridAuthException(debridService, e);
      }
      rethrow;
    }
    return null;
  }

  if (!localTorrentEngine) return null;

  final url = await TorrentStreamService().streamTorrent(
    magnet,
    season: season,
    episode: episode,
    fileIdx: fileIdx,
  );
  if (url == null || url.isEmpty) return null;

  int? fileIndex = fileIdx;
  final idx = Uri.parse(url).queryParameters['index'];
  if (idx != null) fileIndex = int.tryParse(idx);
  return TorrentPlaybackUrl(url, fileIndex: fileIndex);
}
