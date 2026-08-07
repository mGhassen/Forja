import 'dart:async';

import '../../engine_jobs.dart';
import '../lan_playback_bridge.dart';
import 'debrid_api.dart';
import 'torrent_stream_service.dart';

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

/// Loading copy while the local engine finds peers / buffers the stream head.
String formatTorrentEngineLoadingMessage(TorrentStats? stats) {
  if (stats == null) return 'Finding peers…';
  final peers = stats.activePeers;
  final seen = stats.totalPeers;
  final peerLabel = seen > peers && seen > 0 ? '$peers/$seen peers' : '$peers peers';
  if (peers == 0 && stats.loadedBytes <= 0) {
    return seen > 0 ? 'Looking for peers… ($seen seen)' : 'Looking for peers…';
  }
  final parts = <String>[peerLabel];
  if (stats.downloadMbps > 0.001) {
    parts.add(stats.speedLabel);
  }
  if (stats.loadedBytes > 0) {
    parts.add(
      '${TorrentStreamService.formatStorageBytes(stats.loadedBytes)} buffered',
    );
  } else {
    parts.add('buffering…');
  }
  return parts.join(' · ');
}

/// Resolves a magnet to a playable HTTP URL via debrid or the local engine.
///
/// When [useDebrid] is true, only debrid is used — invalid credentials fail
/// fast with [DebridAuthException] (no silent fallback to local engine).
///
/// [onStatus] receives live peer/buffer lines while the local engine resolves.
/// Status FFI runs on the EngineJobs waiter isolate — not the UI isolate.
Future<TorrentPlaybackUrl?> resolveMagnetForPlayback({
  required String magnet,
  required bool useDebrid,
  required String debridService,
  required bool localTorrentEngine,
  int? season,
  int? episode,
  int? fileIdx,
  void Function(String status)? onStatus,
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
      return lan(
        magnet: magnet,
        season: season,
        episode: episode,
        fileIdx: fileIdx,
      );
    }
    return null;
  }

  // Prefer paired desktop when available (phone / TV with local engine off).
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

  StreamSubscription<String>? statusSub;
  if (onStatus != null) {
    onStatus(formatTorrentEngineLoadingMessage(null));
    var last = '';
    statusSub = EngineJobs.torrentStatusJsonStream().listen((json) {
      final message = formatTorrentEngineLoadingMessage(
        TorrentStreamService().statsFromStatusJson(json),
      );
      if (message == last) return;
      last = message;
      onStatus(message);
    });
  }

  try {
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
  } finally {
    await statusSub?.cancel();
  }
}
