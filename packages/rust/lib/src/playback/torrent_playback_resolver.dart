import 'debrid_api.dart';
import 'lan_playback_bridge.dart';
import 'package:rust/rust.dart';

enum TorrentPlaybackSource { debrid, localEngine }

class TorrentPlaybackUrl {
  final String url;
  final int? fileIndex;
  final TorrentPlaybackSource source;
  final String sourceLabel;

  const TorrentPlaybackUrl(
    this.url, {
    this.fileIndex,
    required this.source,
    required this.sourceLabel,
  });
}

String playbackResolveLabel({
  required bool useDebrid,
  required String debridService,
}) {
  if (useDebrid && debridService != 'None') {
    return 'Resolving with $debridService';
  }
  return 'Starting Local Torrent Engine';
}

String playbackSourceHint({
  required bool useDebrid,
  required String debridService,
}) {
  if (useDebrid && debridService != 'None') {
    return 'Source: $debridService (cloud)';
  }
  return 'Source: Local torrent engine';
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
        return TorrentPlaybackUrl(
          files.first.downloadUrl,
          fileIndex: 0,
          source: TorrentPlaybackSource.debrid,
          sourceLabel: debridService,
        );
      }
    } catch (e) {
      if (isDebridAuthFailure(e)) {
        throw DebridAuthException(debridService, e);
      }
      rethrow;
    }
    return null;
  }

  if (!localTorrentEngine) {
    final lan = LanPlaybackBridge.openMagnetOnDesktop;
    if (lan != null) {
      final viaLan = await lan(
        magnet: magnet,
        season: season,
        episode: episode,
        fileIdx: fileIdx,
      );
      if (viaLan != null) return viaLan;
    }
    return null;
  }

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
  return TorrentPlaybackUrl(
    url,
    fileIndex: fileIndex,
    source: TorrentPlaybackSource.localEngine,
    sourceLabel: 'Local Torrent Engine',
  );
}
