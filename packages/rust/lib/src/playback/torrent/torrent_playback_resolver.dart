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
  String get displayMessage {
    final headline = this.headline;
    if (!hasStats) return headline;
    final parts = <String>[];
    if (hasHeadProgress) {
      parts.add('${headProgressLabel!} to start');
    }
    if (activePeers != null) {
      final peers = activePeers!;
      final seen = totalPeers;
      if (seen != null && seen > peers && seen > 0) {
        parts.add('$peers/$seen peers');
      } else {
        parts.add('$peers peers');
      }
    }
    if (speedLabel != null) parts.add(speedLabel!);
    if (bufferLabel != null) {
      parts.add('$bufferLabel cached');
    } else if (activePeers != null &&
        activePeers! > 0 &&
        !hasHeadProgress) {
      parts.add('buffering…');
    }
    if (parts.isEmpty) return headline;
    return '$headline · ${parts.join(' · ')}';
  }
}

String _torrentHeadTargetLabel([int? bytes]) {
  return TorrentStreamService.formatStorageBytes(
    bytes ?? torrentPlaybackHeadBytes,
  );
}

String? _torrentStartEtaLabel(TorrentStats stats) {
  if (!stats.hasHeadProgress) return null;
  final read = stats.headReadBytes!;
  final target = stats.headTargetBytes!;
  if (read >= target || stats.downloadMbps <= 0.001) return null;
  final remaining = target - read;
  final bps = stats.downloadMbps * 1024 * 1024;
  if (bps <= 0) return null;
  final secs = (remaining / bps).ceil();
  if (secs <= 0) return null;
  if (secs >= 3600) return null;
  if (secs < 60) return '~$secs sec at current speed';
  final m = secs ~/ 60;
  final s = secs % 60;
  if (s == 0) return '~${m}m at current speed';
  return '~${m}m ${s}s at current speed';
}

String? _torrentPlaybackStartHint(TorrentStats stats) {
  if (stats.hasHeadProgress) {
    final targetLabel =
        TorrentStreamService.formatStorageBytes(stats.headTargetBytes!);
    final readLabel =
        TorrentStreamService.formatStorageBytes(stats.headReadBytes!);
    var hint = '$readLabel of $targetLabel buffered at the start of the file';
    final eta = _torrentStartEtaLabel(stats);
    if (eta != null) hint = '$hint · $eta';
    return hint;
  }
  if (stats.activePeers > 0) {
    return 'Playback opens once ~${_torrentHeadTargetLabel()} from the start of the file is ready.';
  }
  return null;
}

TorrentLoadingStatus torrentLoadingStatusFromStats(TorrentStats? stats) {
  if (stats == null) {
    return TorrentLoadingStatus(
      headline: 'Finding peers…',
      hint:
          'Playback opens once ~${_torrentHeadTargetLabel()} from the start of the file is ready.',
    );
  }
  if (stats.activePeers <= 0) {
    if (stats.totalPeers > 0) {
      return TorrentLoadingStatus(
        headline: 'Looking for peers…',
        hint:
            '${stats.totalPeers} peers in the swarm — playback starts after ~${_torrentHeadTargetLabel()} from the file start.',
        totalPeers: stats.totalPeers,
        activePeers: 0,
      );
    }
    return TorrentLoadingStatus(
      headline: 'Finding peers…',
      hint:
          'Playback opens once ~${_torrentHeadTargetLabel()} from the start of the file is ready.',
    );
  }

  final preparingHead = stats.hasHeadProgress;
  final headline = preparingHead
      ? (stats.headProgressFraction >= 1.0
          ? 'Opening player…'
          : 'Preparing playback…')
      : stats.loadedBytes <= 0 && stats.downloadMbps < 0.001
          ? 'Connecting to peers…'
          : stats.downloadMbps >= 0.001
              ? 'Downloading from peers…'
              : 'Buffering playback…';
  final hint = _torrentPlaybackStartHint(stats) ??
      (stats.loadedBytes <= 0 && stats.downloadMbps < 0.001
          ? 'Connected — waiting for the first pieces.'
          : 'Please wait while we buffer enough to start playback.');

  return TorrentLoadingStatus(
    headline: headline,
    hint: hint,
    activePeers: stats.activePeers,
    totalPeers: stats.totalPeers,
    speedLabel: stats.downloadMbps > 0.001 ? stats.speedLabel : null,
    bufferLabel: stats.loadedBytes > 0
        ? TorrentStreamService.formatStorageBytes(stats.loadedBytes)
        : null,
    headReadBytes: stats.headReadBytes,
    headTargetBytes: stats.headTargetBytes,
    startEtaLabel: _torrentStartEtaLabel(stats),
  );
}

TorrentLoadingStatus torrentLoadingStatusGeneric(String headline, {String? hint}) {
  return TorrentLoadingStatus(headline: headline, hint: hint);
}

/// Human headline while the local engine finds peers / buffers the stream head.
String torrentEngineLoadingHeadline(TorrentStats? stats) {
  if (stats == null) return 'Finding peers…';
  if (stats.activePeers <= 0) {
    if (stats.totalPeers > 0) {
      return 'Looking for peers… (${stats.totalPeers} seen)';
    }
    return 'Finding peers…';
  }
  if (stats.loadedBytes <= 0 && stats.downloadMbps < 0.001) {
    return 'Connecting to peers…';
  }
  if (stats.downloadMbps >= 0.001) {
    return 'Downloading from peers…';
  }
  return 'Buffering playback…';
}

/// Live peer / speed / buffer line shown under [torrentEngineLoadingHeadline].
String? torrentEngineLoadingStatsDetail(TorrentStats? stats) {
  if (stats == null || stats.activePeers <= 0) return null;
  final peers = stats.activePeers;
  final seen = stats.totalPeers;
  final peerLabel =
      seen > peers && seen > 0 ? '$peers/$seen peers' : '$peers peers';
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
