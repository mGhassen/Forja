import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:rust/rust.dart';
import '../../engine_jobs.dart';
import '../platform/playback_profile.dart';
import '../domain/torrent_engine_backend.dart';

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
  });

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
  String? _rustActiveHash;

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
      _rustActiveHash = null;
      _setState(EngineState.stopped);
      await start();
    }
    _log('Connections limit set to $clamped');
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
        return null;
      }
      final url = parsed['url'];
      if (url is String && url.isNotEmpty) {
        if (hash != null) _rustActiveHash = hash;
        _log('Stream started (Rust): $url');
        return url;
      }
      _log('torrentStream returned no url: $json');
    } catch (e) {
      _log('Rust streamTorrent error: $e');
    }
    return null;
  }

  void removeTorrent(String magnetOrHash) {
    if (retainForExternalHandoff) return;
    final hash = _extractHash(magnetOrHash);
    if (hash == null || hash != _rustActiveHash) return;
    if (RustLib.isInitialized) RustLib.instance.torrentStop();
    _rustActiveHash = null;
    _log('Removed torrent $hash (Rust)');
  }

  TorrentStats? getTorrentStats(String magnetOrHash) {
    final hash = _extractHash(magnetOrHash);
    if (hash == null || hash != _rustActiveHash) return null;
    if (!RustLib.isInitialized) return null;
    return _rustStatsFromJson(RustLib.instance.torrentStatusJson(), hash);
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
    RustLib.instance.torrentStop();
    _rustActiveHash = null;
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

  /// Total bytes on disk under [cacheDirectory] (stream cache, not search results).
  Future<int> cacheDirectoryBytes() async {
    if (!PlatformPlayback.capabilities.localTorrentEngine) return 0;
    final dir = cacheDirectory();
    if (!await dir.exists()) return 0;
    return _directorySizeBytes(dir);
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

  Future<void> clearCacheDirectory() async {
    final dir = cacheDirectory();
    if (!await dir.exists()) return;
    await stop();
    try {
      await dir.delete(recursive: true);
      _log('Cleared torrent stream cache (${dir.path})');
    } catch (e) {
      _log('Failed to clear torrent cache: $e');
      rethrow;
    }
  }

  static final _hashRegExp = RegExp(r'[0-9a-fA-F]{40}');

  String? _extractHash(String magnetOrHash) {
    final match = _hashRegExp.firstMatch(magnetOrHash);
    return match?.group(0)?.toLowerCase();
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
      return TorrentStats(
        downloadMbps: downloadRate / 1024 / 1024,
        uploadMbps: uploadRate / 1024 / 1024,
        activePeers: numPeers,
        totalPeers: numSeen,
        cachePercent: progress * 100,
        loadedBytes: progressBytes,
        totalBytes: totalBytes,
        etaSeconds: etaSecs > 0 ? etaSecs : null,
        hash: hash,
        isConnected: numPeers > 0,
      );
    } catch (_) {
      return null;
    }
  }
}
