import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:storage/storage.dart';
import 'torrent_engine_backend.dart';

/// Rich torrent statistics object.
class TorrentStats {
  final double speedMbps;
  final int activePeers;
  final int totalPeers;
  final double cachePercent;
  final int loadedBytes;
  final int totalBytes;
  final String hash;
  final bool isConnected;

  const TorrentStats({
    required this.speedMbps,
    required this.activePeers,
    required this.totalPeers,
    required this.cachePercent,
    required this.loadedBytes,
    required this.totalBytes,
    required this.hash,
    required this.isConnected,
  });

  double get speedKbps => speedMbps * 1024;
  String get speedLabel => speedMbps >= 1.0
      ? '${speedMbps.toStringAsFixed(2)} MB/s'
      : '${speedKbps.toStringAsFixed(0)} KB/s';
  String get peersLabel => '$activePeers / $totalPeers';
  String get cacheLabel => '${cachePercent.toStringAsFixed(1)}%';
}

/// Engine lifecycle states.
enum EngineState { stopped, starting, ready, error }

/// Magnet playback via Rust/librqbit FFI ([TorrentEngineBackend]).
class TorrentStreamService {
  static final TorrentStreamService _instance = TorrentStreamService._internal();
  factory TorrentStreamService() => _instance;
  TorrentStreamService._internal();

  EngineState _state = EngineState.stopped;
  EngineState get state => _state;

  void Function(EngineState state)? onStateChanged;
  void Function(String line)? onLogLine;

  int _rustEnginePort = 0;
  String? _rustActiveHash;

  final SettingsService _settings = SettingsService();

  bool get _rustReady => _rustEnginePort > 0;

  Future<bool> start() async {
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
      final rustStart = TorrentEngineBackend.engineStart;
      if (rustStart == null) {
        _log('Rust torrent engine not wired — run ForjaEngine.init()');
        _setState(EngineState.error);
        return false;
      }
      final port = rustStart(0);
      if (port <= 0) {
        _log('Rust torrent engine failed to start');
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
    if (_state != EngineState.ready || !_rustReady) return;
    _log('Connections limit saved ($clamped); librqbit session config not wired yet');
  }

  Future<List<TorrentFileEntry>?> listTorrentFiles(String magnetLink) async {
    if (_state != EngineState.ready) {
      final started = await start();
      if (!started) return null;
    }
    final listFiles = TorrentEngineBackend.listFiles;
    if (listFiles == null) return null;
    try {
      return listFiles(magnetLink);
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
    final rustStream = TorrentEngineBackend.streamTorrent;
    if (rustStream == null) return null;

    try {
      final url = rustStream(
        magnetLink,
        season: season,
        episode: episode,
        fileIdx: fileIdx,
      );
      if (url != null && url.isNotEmpty) {
        if (hash != null) _rustActiveHash = hash;
        _log('Stream started (Rust): $url');
        return url;
      }
    } catch (e) {
      _log('Rust streamTorrent error: $e');
    }
    return null;
  }

  void removeTorrent(String magnetOrHash) {
    final hash = _extractHash(magnetOrHash);
    if (hash == null || hash != _rustActiveHash) return;
    TorrentEngineBackend.stop?.call();
    _rustActiveHash = null;
    _log('Removed torrent $hash (Rust)');
  }

  TorrentStats? getTorrentStats(String magnetOrHash) {
    final hash = _extractHash(magnetOrHash);
    if (hash == null || hash != _rustActiveHash) return null;
    final statusJson = TorrentEngineBackend.statusJson;
    if (statusJson == null) return null;
    return _rustStatsFromJson(statusJson(), hash);
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
    if (!_rustReady) return;
    TorrentEngineBackend.stop?.call();
    _rustActiveHash = null;
    _log('All torrents stopped (Rust).');
  }

  Future<void> cleanup() async {
    await stop();
    if (_rustReady) {
      TorrentEngineBackend.engineStop?.call();
      _rustEnginePort = 0;
      _setState(EngineState.stopped);
      _log('Engine cleaned up (Rust).');
    }
  }

  static final _hashRegExp = RegExp(r'[0-9a-fA-F]{40}');

  String? _extractHash(String magnetOrHash) {
    final match = _hashRegExp.firstMatch(magnetOrHash);
    return match?.group(0)?.toLowerCase();
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
      final progress = (m['progress'] as num?)?.toDouble() ?? 0.0;
      final numPeers = (m['num_peers'] as num?)?.toInt() ?? 0;
      final speedMbps = downloadRate / 1024 / 1024;
      return TorrentStats(
        speedMbps: speedMbps,
        activePeers: numPeers,
        totalPeers: numPeers,
        cachePercent: progress * 100,
        loadedBytes: 0,
        totalBytes: 0,
        hash: hash,
        isConnected: numPeers > 0,
      );
    } catch (_) {
      return null;
    }
  }
}
