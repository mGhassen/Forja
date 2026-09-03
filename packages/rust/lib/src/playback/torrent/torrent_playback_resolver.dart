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

/// Human-readable torrent loading state for overlay UI.
class TorrentLoadingStatus {
  const TorrentLoadingStatus({
    required this.headline,
    this.hint,
    this.activePeers,
    this.totalPeers,
    this.speedLabel,
    this.bufferLabel,
    this.headReadBytes,
    this.headTargetBytes,
    this.startEtaLabel,
    this.headWaitStalled = false,
  });

  final String headline;
  final String? hint;
  final int? activePeers;
  final int? totalPeers;
  final String? speedLabel;
  final String? bufferLabel;
  final int? headReadBytes;
  final int? headTargetBytes;
  final String? startEtaLabel;
  /// Swarm is downloading but contiguous bytes at file start are not ready yet.
  final bool headWaitStalled;

  bool get hasHeadProgress =>
      headReadBytes != null &&
      headTargetBytes != null &&
      headTargetBytes! > 0;

  double get headProgressFraction {
    if (!hasHeadProgress) return 0;
    return (headReadBytes! / headTargetBytes!).clamp(0.0, 1.0);
  }

  String? get headProgressLabel {
    if (!hasHeadProgress) return null;
    final read = TorrentStreamService.formatStorageBytes(headReadBytes!);
    final target = TorrentStreamService.formatStorageBytes(headTargetBytes!);
    return '$read / $target';
  }

  bool get hasStats =>
      activePeers != null ||
      speedLabel != null ||
      bufferLabel != null ||
      hasHeadProgress;

  /// Flat line for callers that still expect a single string.
  String get displayMessage => headline;
}

String _torrentLoadingHeadline(TorrentStats? stats) {
  if (stats == null) return 'Preparing playback…';
  if (stats.hasHeadProgress && stats.headProgressFraction >= 1.0) {
    return 'Opening player…';
  }
  if (stats.activePeers <= 0 && stats.totalPeers <= 0) {
    return 'Finding peers…';
  }
  return 'Preparing playback…';
}

TorrentLoadingStatus torrentLoadingStatusFromStats(TorrentStats? stats) {
  return TorrentLoadingStatus(headline: _torrentLoadingHeadline(stats));
}

TorrentLoadingStatus torrentLoadingStatusGeneric(String headline, {String? hint}) {
  return TorrentLoadingStatus(headline: headline, hint: hint);
}

/// Human headline while the local engine finds peers / buffers the stream head.
String torrentEngineLoadingHeadline(TorrentStats? stats) {
  return _torrentLoadingHeadline(stats);
}

/// Live peer / speed / buffer line shown under [torrentEngineLoadingHeadline].
String? torrentEngineLoadingStatsDetail(TorrentStats? stats) => null;

/// Loading copy while the local engine finds peers / buffers the stream head.
String formatTorrentEngineLoadingMessage(TorrentStats? stats) {
  return torrentLoadingStatusFromStats(stats).displayMessage;
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
  void Function(TorrentLoadingStatus status)? onStatus,
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
    onStatus(torrentLoadingStatusFromStats(null));
    var last = '';
    statusSub = EngineJobs.torrentStatusJsonStream().listen((json) {
      final status = torrentLoadingStatusFromStats(
        TorrentStreamService().statsFromStatusJson(json),
      );
      final message = status.displayMessage;
      if (message == last) return;
      last = message;
      onStatus(status);
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
