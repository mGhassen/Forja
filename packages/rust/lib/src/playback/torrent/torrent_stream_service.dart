import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:rust/rust.dart';

/// Bytes of file head the local engine waits for before returning a play URL.
const int torrentPlaybackHeadBytes = 256 * 1024;

/// Minimum head accepted after a long wait (matches Rust [`STREAM_HEAD_MIN_ACCEPT`]).
const int torrentPlaybackHeadMinBytes = 64 * 1024;

/// Rich torrent statistics object.
class TorrentStats {
  final double downloadMbps;
  final double uploadMbps;
  final int activePeers;
  final int totalPeers;
  final double cachePercent;
  final int loadedBytes;
  final int totalBytes;
  final int? etaSeconds;
  final String hash;
  final bool isConnected;
  final int? headReadBytes;
  final int? headTargetBytes;

  const TorrentStats({
    required this.downloadMbps,
    required this.uploadMbps,
    required this.activePeers,
    required this.totalPeers,
    required this.cachePercent,
    required this.loadedBytes,
    required this.totalBytes,
    required this.etaSeconds,
    required this.hash,
    required this.isConnected,
    this.headReadBytes,
    this.headTargetBytes,
  });

  bool get hasHeadProgress =>
      headReadBytes != null &&
      headTargetBytes != null &&
      headTargetBytes! > 0;

  double get headProgressFraction {
    if (!hasHeadProgress) return 0;
    return (headReadBytes! / headTargetBytes!).clamp(0.0, 1.0);
  }

  /// Backward-compatible alias for download speed.
  double get speedMbps => downloadMbps;

  double get downloadKbps => downloadMbps * 1024;
  double get uploadKbps => uploadMbps * 1024;

  String get speedLabel => _formatMbps(downloadMbps);
  String get uploadLabel => _formatMbps(uploadMbps);
  String get peersLabel => '$activePeers / $totalPeers';
  String get cacheLabel => '${cachePercent.toStringAsFixed(1)}%';
  String get sizeLabel {
    final loaded = TorrentStreamService.formatStorageBytes(loadedBytes);
    final total = TorrentStreamService.formatStorageBytes(totalBytes);
    return '$loaded / $total';
  }

  String get etaLabel {
    final secs = etaSeconds;
    if (secs == null || secs <= 0) return '—';
    final h = secs ~/ 3600;
    final m = (secs % 3600) ~/ 60;
    final s = secs % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  static String _formatMbps(double mbps) {
    if (mbps >= 1.0) return '${mbps.toStringAsFixed(2)} MB/s';
    return '${(mbps * 1024).toStringAsFixed(0)} KB/s';
  }
}

/// Engine lifecycle states.
enum EngineState { stopped, starting, ready, error }

/// Session + disk usage for the Sources panel torrent cache row.
class TorrentDownloadCacheSnapshot {
  const TorrentDownloadCacheSnapshot({
    required this.cacheDir,
    required this.diskBytes,
    required this.progressBytes,
    required this.totalBytes,
    required this.torrentCount,
    required this.active,
  });

  final String cacheDir;
  final int diskBytes;
  final int progressBytes;
  final int totalBytes;
  final int torrentCount;
  final bool active;

  static const empty = TorrentDownloadCacheSnapshot(
    cacheDir: '',
    diskBytes: 0,
    progressBytes: 0,
    totalBytes: 0,
    torrentCount: 0,
    active: false,
  );

  /// Best single number for the cache row — disk files or in-flight swarm bytes.
  int get displayBytes {
    var best = diskBytes;
    if (progressBytes > best) best = progressBytes;
    return best;
  }

  bool get hasClearableData => displayBytes > 0 || torrentCount > 0;

  TorrentDownloadCacheSnapshot copyWith({
    String? cacheDir,
    int? diskBytes,
    int? progressBytes,
    int? totalBytes,
    int? torrentCount,
    bool? active,
  }) {
    return TorrentDownloadCacheSnapshot(
      cacheDir: cacheDir ?? this.cacheDir,
      diskBytes: diskBytes ?? this.diskBytes,
      progressBytes: progressBytes ?? this.progressBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      torrentCount: torrentCount ?? this.torrentCount,
      active: active ?? this.active,
    );
  }

  String label({String? speedLabel}) {
    if (torrentCount > 0 && totalBytes > 0 && progressBytes < totalBytes) {
      final loaded = TorrentStreamService.formatStorageBytes(progressBytes);
      final total = TorrentStreamService.formatStorageBytes(totalBytes);
      if (speedLabel != null && speedLabel.isNotEmpty) {
        return 'Downloading: $loaded / $total · $speedLabel';
      }
      return 'Downloading: $loaded / $total';
    }
    return 'Torrent cache: ${TorrentStreamService.formatStorageBytes(displayBytes)}';
  }

  static TorrentDownloadCacheSnapshot fromJson(String json) {
    if (json.isEmpty) return empty;
    try {
      final m = jsonDecode(json) as Map<String, dynamic>;
      return TorrentDownloadCacheSnapshot(
        cacheDir: m['cache_dir'] as String? ?? '',
        diskBytes: (m['disk_bytes'] as num?)?.toInt() ?? 0,
        progressBytes: (m['progress_bytes'] as num?)?.toInt() ?? 0,
        totalBytes: (m['total_bytes'] as num?)?.toInt() ?? 0,
        torrentCount: (m['torrent_count'] as num?)?.toInt() ?? 0,
        active: m['active'] == true,
      );
    } catch (_) {
      return empty;
    }
  }
}

/// One swarm in the engine session ([TorrentStreamService.listSessionTorrents]).
class TorrentSessionEntry {
  const TorrentSessionEntry({
    required this.id,
    required this.infoHash,
    required this.name,
    required this.progressBytes,
    required this.totalBytes,
    required this.downloadRate,
    required this.uploadRate,
    required this.numPeers,
    required this.numSeen,
    required this.state,
    required this.finished,
    required this.active,
  });

  final int id;
  final String infoHash;
  final String name;
  final int progressBytes;
  final int totalBytes;
  /// Bytes per second.
  final int downloadRate;
  final int uploadRate;
  final int numPeers;
  final int numSeen;
  /// `initializing` · `live` · `paused` · `finished` · `error`.
  final String state;
  final bool finished;
  /// The swarm the player is reading from right now.
  final bool active;

  double get progressFraction =>
      totalBytes <= 0 ? 0 : (progressBytes / totalBytes).clamp(0.0, 1.0);

  String get displayName => name.isNotEmpty ? name : infoHash;

  String get speedLabel => TorrentStats._formatMbps(downloadRate / 1024 / 1024);

  /// "1.2 GB / 4.5 GB · 3 peers · 2.1 MB/s" style status line.
  String get statusLine {
    final loaded = TorrentStreamService.formatStorageBytes(progressBytes);
    final parts = <String>[];
    if (totalBytes > 0) {
      parts.add('$loaded / ${TorrentStreamService.formatStorageBytes(totalBytes)}');
    } else {
      parts.add(loaded);
    }
    if (finished) {
      parts.add('complete');
    } else if (state == 'paused') {
      parts.add('paused');
    } else if (state == 'error') {
      parts.add('error');
    } else if (state == 'initializing') {
      parts.add('starting');
    } else {
      parts.add(numPeers == 1 ? '1 peer' : '$numPeers peers');
      if (downloadRate > 0) parts.add(speedLabel);
    }
    if (active) parts.add('playing now');
    return parts.join(' · ');
  }

  static List<TorrentSessionEntry> listFromJson(String json) {
    if (json.isEmpty) return const [];
    final parsed = jsonDecode(json);
    if (parsed is! Map<String, dynamic>) return const [];
    final rows = parsed['torrents'];
    if (rows is! List) return const [];
    return rows
        .whereType<Map>()
        .map((m) => TorrentSessionEntry(
              id: (m['id'] as num?)?.toInt() ?? -1,
              infoHash: (m['info_hash'] as String? ?? '').toLowerCase(),
              name: m['name'] as String? ?? '',
              progressBytes: (m['progress_bytes'] as num?)?.toInt() ?? 0,
              totalBytes: (m['total_bytes'] as num?)?.toInt() ?? 0,
              downloadRate: (m['download_rate'] as num?)?.toInt() ?? 0,
              uploadRate: (m['upload_rate'] as num?)?.toInt() ?? 0,
              numPeers: (m['num_peers'] as num?)?.toInt() ?? 0,
              numSeen: (m['num_seen'] as num?)?.toInt() ?? 0,
              state: m['state'] as String? ?? '',
              finished: m['finished'] == true,
              active: m['active'] == true,
            ))
        .where((e) => e.id >= 0)
        .toList();
  }
}

/// librqbit download dir usage from [TorrentStreamService.queryDiskCacheStats].
class TorrentDiskCacheStats {
  const TorrentDiskCacheStats({
    required this.usedBytes,
    required this.protectedBytes,
    required this.reclaimedBytes,
    required this.evictions,
  });

  final int usedBytes;
  final int protectedBytes;
  final int reclaimedBytes;
  final int evictions;

  static const empty = TorrentDiskCacheStats(
    usedBytes: 0,
    protectedBytes: 0,
    reclaimedBytes: 0,
    evictions: 0,
  );

  static TorrentDiskCacheStats fromJson(String json) {
    if (json.isEmpty) return empty;
    try {
      final m = jsonDecode(json) as Map<String, dynamic>;
      return TorrentDiskCacheStats(
        usedBytes: (m['used_bytes'] as num?)?.toInt() ?? 0,
        protectedBytes: (m['protected_bytes'] as num?)?.toInt() ?? 0,
        reclaimedBytes: (m['reclaimed_bytes'] as num?)?.toInt() ?? 0,
        evictions: (m['evictions'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return empty;
    }
  }
}

/// Magnet playback via Rust/librqbit FFI.
class TorrentStreamService {
  static final TorrentStreamService _instance =
      TorrentStreamService._internal();
  factory TorrentStreamService() => _instance;
  TorrentStreamService._internal();

  EngineState _state = EngineState.stopped;
  EngineState get state => _state;

  void Function(EngineState state)? onStateChanged;
  void Function(String line)? onLogLine;

  int _rustEnginePort = 0;
  /// Hex info hash of the swarm the player reads (from the Rust response).
  String? _rustActiveHash;
  /// Raw magnet the host passed to [streamTorrent] for that swarm.
  String? _rustActiveMagnet;
  int? _rustActiveTorrentId;
  /// Magnet resolving in [streamTorrent] right now; null when idle.
  String? _pendingMagnet;
  String? _pendingHash;
  /// Host left (loading Cancel / Back, player closed) while [_pendingMagnet]
  /// was still resolving — stop the swarm as soon as the job returns.
  bool _abandonPending = false;
  /// Player entry surfaces mounted right now. A route replacement (next
  /// episode, resume) briefly has two; the outgoing one must not stop the
  /// swarm the incoming one is resolving.
  int _playerSurfaces = 0;

  /// When true, [removeTorrent] is a no-op so an external player can keep
  /// reading the localhost librqbit URL after the built-in player disposes.
  bool retainForExternalHandoff = false;

  final SettingsService _settings = SettingsService();

  bool get _rustReady => RustLib.isInitialized && _rustEnginePort > 0;

  Future<bool> start() async {
    if (!PlatformPlayback.capabilities.localTorrentEngine) {
      _log('Torrent engine not available on this platform profile');
      _setState(EngineState.error);
      return false;
    }
    if (_state == EngineState.ready) return true;
    if (_state == EngineState.starting) {
      for (int i = 0; i < 50; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (_state == EngineState.ready) return true;
        if (_state == EngineState.error) return false;
      }
      return false;
    }

    _setState(EngineState.starting);
    try {
      if (!RustLib.isInitialized) {
        _log('Rust torrent engine not loaded — run Engine.init()');
        _setState(EngineState.error);
        return false;
      }
      final connLimit = (await _settings.getTorrentConnectionsLimit()).clamp(
        5,
        200,
      );
      RustLib.instance.torrentSetPeerLimit(connLimit);
      await _applyDiskCacheBudget();
      final port = RustLib.instance.torrentEngineStart(0);
      if (port <= 0) {
        final detail = RustLib.instance.torrentEngineLastError();
        _log(
          detail.isEmpty
              ? 'Rust torrent engine failed to start'
              : 'Rust torrent engine failed to start: $detail',
        );
        _setState(EngineState.error);
        return false;
      }
      _rustEnginePort = port;
      _setState(EngineState.ready);
      _log('Engine ready (Rust/librqbit on $port)');
      return true;
    } catch (e, st) {
      _log('Failed to start engine: $e\n$st');
      _setState(EngineState.error);
      return false;
    }
  }

  Future<void> applyConnectionsLimit(int limit) async {
    final clamped = limit.clamp(5, 200);
    await _settings.setTorrentConnectionsLimit(clamped);
    if (RustLib.isInitialized) {
      RustLib.instance.torrentSetPeerLimit(clamped);
    }
    if (_state == EngineState.ready && _rustReady) {
      RustLib.instance.torrentEngineStop();
      _rustEnginePort = 0;
      _clearActive();
      _setState(EngineState.stopped);
      await start();
    }
    _log('Connections limit set to $clamped');
  }

  static const int _bytesPerGb = 1024 * 1024 * 1024;

  Future<void> _applyDiskCacheBudget() async {
    if (!RustLib.isInitialized) return;
    final gb = await _settings.getTorrentDiskCacheGb();
    RustLib.instance.torrentSetDiskCacheBytes(gb * _bytesPerGb);
  }

  Future<void> applyDiskCacheGb(int gb) async {
    final clamped = gb.clamp(
      SettingsService.minTorrentDiskCacheGb,
      SettingsService.maxTorrentDiskCacheGb,
    );
    await _settings.setTorrentDiskCacheGb(clamped);
    if (RustLib.isInitialized) {
      RustLib.instance.torrentSetDiskCacheBytes(clamped * _bytesPerGb);
    }
    _log('Disk cache budget set to $clamped GB');
  }

  /// Prioritize swarm pieces at [byteOffset] while the user hovers/drags the seekbar.
  void prefetchByteOffset(int byteOffset) {
    if (byteOffset < 0 || !RustLib.isInitialized) return;
    RustLib.instance.torrentPrefetchByteOffset(byteOffset);
  }

  Future<List<TorrentFileEntry>?> listTorrentFiles(String magnetLink) async {
    if (_state != EngineState.ready) {
      final started = await start();
      if (!started) return null;
    }
    if (!RustLib.isInitialized) return null;
    try {
      return _parseFileList(RustLib.instance.torrentListFilesJson(magnetLink));
    } catch (e) {
      _log('Rust listTorrentFiles error: $e');
      return null;
    }
  }

  Future<String?> streamTorrent(
    String magnetLink, {
    int? season,
    int? episode,
    int? fileIdx,
  }) async {
    if (_state != EngineState.ready) {
      final started = await start();
      if (!started) {
        _log('Cannot stream: engine failed to start.');
        return null;
      }
    }

    final hash = _extractHash(magnetLink);
    if (!RustLib.isInitialized) return null;

    _pendingMagnet = magnetLink;
    _pendingHash = hash;
    _abandonPending = false;
    try {
      _log('Submitting torrentStream job…');
      final json = await EngineJobs.run(EngineAsyncJob.torrentStream, {
        'magnet': magnetLink,
        'season': season ?? -1,
        'episode': episode ?? -1,
        'file_idx': fileIdx ?? -1,
      });
      final parsed = jsonDecode(json) as Map<String, dynamic>;
      final err = parsed['error'];
      if (err != null) {
        _log('torrentStream failed: $err');
        if (_abandonPending) _removeByHandle(hash, null);
        return null;
      }
      final url = parsed['url'];
      if (url is String && url.isNotEmpty) {
        final rustHash = (parsed['info_hash'] as String?)?.trim().toLowerCase();
        final torrentId = (parsed['torrent_id'] as num?)?.toInt();
        final resolvedHash =
            (rustHash != null && rustHash.isNotEmpty) ? rustHash : hash;
        if (_abandonPending) {
          // Nobody will read this URL — the host left while we resolved.
          _log('Stream resolved after cancel — stopping $resolvedHash');
          _removeByHandle(resolvedHash, torrentId);
          return null;
        }
        _rustActiveHash = resolvedHash;
        _rustActiveMagnet = magnetLink;
        _rustActiveTorrentId = torrentId;
        _log('Stream started (Rust): $url');
        return url;
      }
      _log('torrentStream returned no url: $json');
    } catch (e) {
      _log('Rust streamTorrent error: $e');
    } finally {
      _pendingMagnet = null;
      _pendingHash = null;
      _abandonPending = false;
    }
    return null;
  }

  /// Abort an in-flight [streamTorrent] (loading page Cancel / Back).
  ///
  /// The Rust job aborts at its next cancel check and deletes the half-added
  /// swarm; if it already returned a URL, [streamTorrent] stops it instead.
  void cancelResolve() {
    if (_pendingMagnet == null) return;
    _abandonPending = true;
    if (RustLib.isInitialized) {
      RustLib.instance.engineCancelJobsOfKind(EngineAsyncJob.torrentStream);
    }
    _log('Cancelled torrent resolve');
  }

  /// A player entry screen mounted. Pair with [leavePlayerSurface].
  void enterPlayerSurface() => _playerSurfaces++;

  /// A player entry screen left. Returns true when another player is still
  /// mounted (route replacement) — the swarm now belongs to that one.
  bool leavePlayerSurface() {
    if (_playerSurfaces > 0) _playerSurfaces--;
    return _playerSurfaces > 0;
  }

  /// True while a replacement player is mounted beside the outgoing one.
  bool get replacementPlayerAlive => _playerSurfaces > 1;

  /// Stop the swarm the host opened for [magnetOrUrl] — a magnet, a hex or
  /// base32 info hash, or the localhost stream URL — and delete its files.
  ///
  /// Only touches that swarm: a swarm another player is resolving right now
  /// is left alone, and an in-flight resolve for the same magnet is aborted.
  void removeTorrent(String magnetOrUrl) {
    if (retainForExternalHandoff) return;
    final hash = _extractHash(magnetOrUrl);
    final streamId = _streamUrlTorrentId(magnetOrUrl);
    if (_matchesPending(magnetOrUrl, hash)) cancelResolve();
    if (_matchesActive(magnetOrUrl, hash, streamId)) {
      _removeByHandle(_rustActiveHash ?? hash, _rustActiveTorrentId ?? streamId);
      _clearActive();
      return;
    }
    // Not tracked (engine restart, stale bookkeeping) — still make sure no
    // session swarm with this hash keeps downloading.
    if (hash != null || streamId != null) _removeByHandle(hash, streamId);
  }

  TorrentStats? getTorrentStats(String magnetOrHash) {
    final hash = _extractHash(magnetOrHash);
    final streamId = _streamUrlTorrentId(magnetOrHash);
    if (!_matchesActive(magnetOrHash, hash, streamId)) return null;
    if (!RustLib.isInitialized) return null;
    return _rustStatsFromJson(
      RustLib.instance.torrentStatusJson(),
      _rustActiveHash ?? hash ?? '',
    );
  }

  void _clearActive() {
    _rustActiveHash = null;
    _rustActiveMagnet = null;
    _rustActiveTorrentId = null;
  }

  bool _matchesPending(String raw, String? hash) {
    final pending = _pendingMagnet;
    if (pending == null) return false;
    if (raw == pending) return true;
    final pendingHash = _pendingHash;
    return hash != null && pendingHash != null && hash == pendingHash;
  }

  bool _matchesActive(String raw, String? hash, int? streamId) {
    if (_rustActiveMagnet != null && raw == _rustActiveMagnet) return true;
    if (hash != null && _rustActiveHash != null && hash == _rustActiveHash) {
      return true;
    }
    return streamId != null &&
        _rustActiveTorrentId != null &&
        streamId == _rustActiveTorrentId;
  }

  /// Delete one session swarm by hex hash (preferred) or session id.
  void _removeByHandle(String? hash, int? id) {
    if (!RustLib.isInitialized) return;
    final handle = (hash != null && hash.isNotEmpty) ? hash : id?.toString();
    if (handle == null || handle.isEmpty) return;
    try {
      final json = RustLib.instance.torrentRemoveJson(handle);
      _log('Removed torrent $handle (Rust): $json');
    } catch (e) {
      _log('Rust removeTorrent error: $e');
    }
  }

  /// Every swarm in the engine session — Settings → Direct torrent list.
  ///
  /// Does not start the engine: an idle engine has nothing to list.
  Future<List<TorrentSessionEntry>> listSessionTorrents() async {
    if (!PlatformPlayback.capabilities.localTorrentEngine) return const [];
    if (!RustLib.isInitialized) return const [];
    if (RustLib.instance.torrentEnginePort() <= 0) return const [];
    try {
      return TorrentSessionEntry.listFromJson(RustLib.instance.torrentListJson());
    } catch (e) {
      _log('Rust listSessionTorrents error: $e');
      return const [];
    }
  }

  /// Stop one listed swarm and delete its files.
  Future<bool> removeSessionTorrent(TorrentSessionEntry entry) async {
    if (!RustLib.isInitialized) return false;
    try {
      final json = RustLib.instance.torrentRemoveJson(entry.infoHash);
      final parsed = jsonDecode(json) as Map<String, dynamic>;
      final removed = parsed['removed'] == true;
      if (removed &&
          (_rustActiveHash == entry.infoHash ||
              _rustActiveTorrentId == entry.id)) {
        _clearActive();
      }
      _log('Removed session torrent ${entry.infoHash}: $removed');
      return removed;
    } catch (e) {
      _log('Rust removeSessionTorrent error: $e');
      return false;
    }
  }

  /// Stop every swarm in the session and delete their files.
  Future<int> removeAllSessionTorrents() async {
    var removed = 0;
    for (final entry in await listSessionTorrents()) {
      if (await removeSessionTorrent(entry)) removed++;
    }
    return removed;
  }

  /// Active swarm stats — readable while [streamTorrent] is still resolving.
  ///
  /// Prefer [EngineJobs.torrentStatusJsonStream] + [statsFromStatusJson] from
  /// the UI so status FFI stays off the main isolate.
  TorrentStats? activeStats() {
    if (!RustLib.isInitialized) return null;
    if (RustLib.instance.torrentEnginePort() <= 0) return null;
    return statsFromStatusJson(RustLib.instance.torrentStatusJson());
  }

  /// Parse [torrentStatusJson] / waiter stream payloads.
  TorrentStats? statsFromStatusJson(String json) {
    if (json == 'null' || json.isEmpty) return null;
    return _rustStatsFromJson(json, _rustActiveHash ?? '');
  }

  Stream<TorrentStats> statsStream(
    String magnetOrHash, {
    Duration interval = const Duration(seconds: 1),
  }) {
    final controller = StreamController<TorrentStats>();
    Timer? timer;

    controller.onListen = () {
      timer = Timer.periodic(interval, (_) {
        final stats = getTorrentStats(magnetOrHash);
        if (stats != null && !controller.isClosed) {
          controller.add(stats);
        }
      });
    };

    controller.onCancel = () {
      timer?.cancel();
      controller.close();
    };

    return controller.stream;
  }

  Future<void> stop() async {
    if (!RustLib.isInitialized) return;
    cancelResolve();
    RustLib.instance.torrentStop();
    _clearActive();
    _log('All torrents stopped (Rust).');
  }

  Future<void> cleanup() async {
    await stop();
    if (RustLib.isInitialized && _rustEnginePort > 0) {
      RustLib.instance.torrentEngineStop();
      _rustEnginePort = 0;
      _setState(EngineState.stopped);
      _log('Engine cleaned up (Rust).');
    }
  }

  /// librqbit session download dir — `{temp}/torrent` (see `crates/torrent`).
  static Directory cacheDirectory() =>
      Directory('${Directory.systemTemp.path}${Platform.pathSeparator}torrent');

  /// Session swarms + on-disk bytes under `{temp}/torrent`.
  ///
  /// Always walks the download folder on disk, then merges engine session
  /// stats and [activeStats] so the row matches real files while downloading.
  Future<TorrentDownloadCacheSnapshot> queryDownloadCacheSnapshot() async {
    if (!PlatformPlayback.capabilities.localTorrentEngine) {
      return TorrentDownloadCacheSnapshot.empty;
    }

    final cacheDir = cacheDirectory().path;
    final diskBytes = await _cacheDirectoryBytesOnDisk();
    var snap = TorrentDownloadCacheSnapshot(
      cacheDir: cacheDir,
      diskBytes: diskBytes,
      progressBytes: 0,
      totalBytes: 0,
      torrentCount: 0,
      active: false,
    );

    if (RustLib.isInitialized) {
      if (RustLib.instance.torrentEnginePort() <= 0) {
        await start();
      }
      try {
        final rust = TorrentDownloadCacheSnapshot.fromJson(
          RustLib.instance.torrentDownloadCacheSnapshotJson(),
        );
        snap = snap.copyWith(
          cacheDir: rust.cacheDir.isNotEmpty ? rust.cacheDir : cacheDir,
          diskBytes: rust.diskBytes > diskBytes ? rust.diskBytes : diskBytes,
          progressBytes: rust.progressBytes,
          totalBytes: rust.totalBytes,
          torrentCount: rust.torrentCount,
          active: rust.active,
        );
      } catch (e, st) {
        _log('download cache snapshot FFI failed: $e\n$st');
      }
    }

    final active = activeStats();
    if (active != null) {
      final loaded = active.loadedBytes;
      final total = active.totalBytes;
      snap = snap.copyWith(
        progressBytes: loaded > snap.progressBytes ? loaded : snap.progressBytes,
        totalBytes: total > snap.totalBytes ? total : snap.totalBytes,
        torrentCount: snap.torrentCount > 0 ? snap.torrentCount : 1,
        active: total > 0 && loaded < total,
      );
    }

    return snap;
  }

  /// Legacy disk-only stats (Settings / LAN).
  Future<TorrentDiskCacheStats> queryDiskCacheStats() async {
    final snap = await queryDownloadCacheSnapshot();
    return TorrentDiskCacheStats(
      usedBytes: snap.diskBytes,
      protectedBytes: 0,
      reclaimedBytes: 0,
      evictions: 0,
    );
  }

  /// Total bytes on disk under [cacheDirectory].
  Future<int> cacheDirectoryBytes() async {
    return (await queryDiskCacheStats()).usedBytes;
  }

  static String formatStorageBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    if (unit == 0) return '${value.round()} ${units[unit]}';
    return '${value.toStringAsFixed(1)} ${units[unit]}';
  }

  static Future<int> _directorySizeBytes(Directory dir) async {
    var total = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      try {
        total += await entity.length();
      } catch (_) {}
    }
    return total;
  }

  static Future<int> _cacheDirectoryBytesOnDisk() async {
    final dir = cacheDirectory();
    if (!await dir.exists()) return 0;
    return _directorySizeBytes(dir);
  }

  Future<TorrentDownloadCacheSnapshot> clearCacheDirectory() async {
    if (!PlatformPlayback.capabilities.localTorrentEngine) {
      return TorrentDownloadCacheSnapshot.empty;
    }
    if (RustLib.isInitialized) {
      final snap = TorrentDownloadCacheSnapshot.fromJson(
        RustLib.instance.torrentClearAllDownloadsJson(),
      );
      final diskBytes = await _cacheDirectoryBytesOnDisk();
      final merged = snap.copyWith(
        diskBytes: diskBytes > snap.diskBytes ? diskBytes : snap.diskBytes,
      );
      _log(
        merged.torrentCount == 0 && merged.displayBytes == 0
            ? 'Stopped and cleared all torrent downloads'
            : 'Torrent downloads: ${merged.label()} remaining',
      );
      return merged;
    }
    final dir = cacheDirectory();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    return TorrentDownloadCacheSnapshot.empty;
  }

  static final _hexHashRegExp = RegExp(r'[0-9a-fA-F]{40}');
  static final _base32HashRegExp = RegExp(r'[A-Za-z2-7]{32}');
  static final _streamUrlIdRegExp = RegExp(r'/torrents/(\d+)/stream/');

  /// Lower-case hex info hash from a magnet / bare hash (base32 is decoded).
  String? _extractHash(String magnetOrHash) {
    final hex = _hexHashRegExp.firstMatch(magnetOrHash)?.group(0);
    if (hex != null) return hex.toLowerCase();
    final match = _base32HashRegExp.firstMatch(magnetOrHash);
    if (match == null) return null;
    return _base32ToHex(match.group(0)!);
  }

  /// Session torrent id from a localhost stream URL, else null.
  int? _streamUrlTorrentId(String url) {
    if (!url.startsWith('http')) return null;
    final match = _streamUrlIdRegExp.firstMatch(url);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  static const _base32Alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  static String? _base32ToHex(String base32) {
    final bytes = <int>[];
    var buffer = 0;
    var bits = 0;
    for (final rune in base32.toUpperCase().runes) {
      final value = _base32Alphabet.indexOf(String.fromCharCode(rune));
      if (value < 0) return null;
      buffer = (buffer << 5) | value;
      bits += 5;
      if (bits >= 8) {
        bits -= 8;
        bytes.add((buffer >> bits) & 0xff);
      }
    }
    if (bytes.length != 20) return null;
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  List<TorrentFileEntry> _parseFileList(String json) {
    final parsed = jsonDecode(json) as Map<String, dynamic>;
    if (parsed.containsKey('error')) return const [];
    final files = parsed['files'];
    if (files is! List) return const [];
    return files
        .whereType<Map>()
        .map(
          (f) => TorrentFileEntry(
            index: (f['index'] as num?)?.toInt() ?? 0,
            name: f['name'] as String? ?? '',
            size: (f['size'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList();
  }

  void _setState(EngineState s) {
    if (_state == s) return;
    _state = s;
    onStateChanged?.call(s);
  }

  void _log(String message) {
    debugPrint('[TorrentStream] $message');
    onLogLine?.call(message);
  }

  TorrentStats? _rustStatsFromJson(String json, String hash) {
    if (json == 'null') return null;
    try {
      final m = jsonDecode(json) as Map<String, dynamic>;
      final downloadRate = (m['download_rate'] as num?)?.toInt() ?? 0;
      final uploadRate = (m['upload_rate'] as num?)?.toInt() ?? 0;
      final progress = (m['progress'] as num?)?.toDouble() ?? 0.0;
      final numPeers = (m['num_peers'] as num?)?.toInt() ?? 0;
      final numSeen = (m['num_seen'] as num?)?.toInt() ?? numPeers;
      final progressBytes = (m['progress_bytes'] as num?)?.toInt() ?? 0;
      final totalBytes = (m['total_bytes'] as num?)?.toInt() ?? 0;
      final etaSecs = (m['eta_secs'] as num?)?.toInt() ?? 0;
      final headRead = (m['head_read_bytes'] as num?)?.toInt();
      final headTarget = (m['head_target_bytes'] as num?)?.toInt();
      final statusHash = (m['info_hash'] as String?)?.trim().toLowerCase();
      return TorrentStats(
        downloadMbps: downloadRate / 1024 / 1024,
        uploadMbps: uploadRate / 1024 / 1024,
        activePeers: numPeers,
        totalPeers: numSeen,
        cachePercent: progress * 100,
        loadedBytes: progressBytes,
        totalBytes: totalBytes,
        etaSeconds: etaSecs > 0 ? etaSecs : null,
        hash: (statusHash != null && statusHash.isNotEmpty) ? statusHash : hash,
        isConnected: numPeers > 0,
        headReadBytes: headRead,
        headTargetBytes: headTarget,
      );
    } catch (_) {
      return null;
    }
  }
}
