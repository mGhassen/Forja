import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:forja/features/iptv/iptv_proxy_reconnect_skip.dart';

/// Live HTTP TS continuity: player reads loopback; we reopen the CDN when it
/// closes the socket without tearing down the player's connection.
///
/// Used by MediaKit and ExoPlayer for Xtream / M3U live (not Stalker —
/// create_link must mint a fresh URL). On reconnect, Xtream often restarts a
/// few seconds *behind* the previous socket end — piping that raw would look
/// like a replay. We:
/// 1. Keep a multi-second read-ahead queue so the player rarely underruns mid-reconnect
/// 2. Skip ~[iptvProxyReconnectSkipBytes] of each reconnect (bitrate-adaptive)
///    — abort early if the loopback queue would starve (prefer short overlap
///    over underrun freeze on Android TV)
/// 3. Notify [onUpstreamReconnected] so MediaKit / watchdog can grace refill
///    (Exo plays through LoadControl cushion — no drop-buffers)
class IptvLiveContinuityProxy {
  IptvLiveContinuityProxy({this.onUpstreamReconnected});

  /// Fired on every upstream reopen after the first.
  final VoidCallback? onUpstreamReconnected;

  HttpServer? _server;
  HttpClient? _client;
  String _upstream = '';
  Map<String, String> _headers = const {};
  var _closed = false;
  int _generation = 0;

  final Queue<Uint8List> _queue = Queue<Uint8List>();
  int _queuedBytes = 0;
  Completer<void>? _waitData;

  int _maxQueueBytes = 12 * 1024 * 1024;

  /// Rolling upstream fill rate (bytes/sec) for adaptive overlap skip.
  int _estimatedBytesPerSec = 0;
  int _rateSampleBytes = 0;
  DateTime? _rateSampleStarted;
  DateTime? _lastUpstreamEofAt;

  /// Only one loopback client producer at a time (Exo soft-reopen opens a
  /// second GET while the old socket is still draining).
  int _producerEpoch = 0;

  Uri? get localUri {
    final p = _server?.port;
    if (p == null || p <= 0) return null;
    return Uri.parse('http://127.0.0.1:$p/live.ts');
  }

  /// Current loopback queue size (player has not drained these bytes yet).
  int get queuedBytes => _queuedBytes;

  int get estimatedBytesPerSec => _estimatedBytesPerSec;

  Future<Uri> start({
    required String upstreamUrl,
    required Map<String, String> headers,
    int maxQueueBytes = 12 * 1024 * 1024,
  }) async {
    await stop();
    _closed = false;
    _maxQueueBytes = maxQueueBytes.clamp(4 * 1024 * 1024, 20 * 1024 * 1024);
    _upstream = upstreamUrl;
    _headers = Map<String, String>.from(headers);
    _estimatedBytesPerSec = 0;
    _rateSampleBytes = 0;
    _rateSampleStarted = null;
    _lastUpstreamEofAt = null;
    _client = HttpClient()
      // macOS/Linux env proxies return 407 for IPTV CDNs — mpv/libmpv is direct.
      ..findProxy = ((_) => 'DIRECT')
      ..connectionTimeout = const Duration(seconds: 12)
      ..idleTimeout = const Duration(seconds: 30)
      ..autoUncompress = false;
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen(
      _onRequest,
      onError: (Object e) => debugPrint('[IPTV Proxy] server error: $e'),
    );
    final uri = localUri!;
    debugPrint('[IPTV Proxy] $uri ← $upstreamUrl (queue=${_maxQueueBytes >> 20}MiB)');
    return uri;
  }

  Future<void> stop() async {
    _closed = true;
    _generation++;
    _producerEpoch++;
    _clearQueue();
    _wakeWaiters();
    final server = _server;
    _server = null;
    final client = _client;
    _client = null;
    try {
      await server?.close(force: true);
    } catch (_) {}
    try {
      client?.close(force: true);
    } catch (_) {}
  }

  void _clearQueue() {
    _queue.clear();
    _queuedBytes = 0;
  }

  void _wakeWaiters() {
    final c = _waitData;
    _waitData = null;
    if (c != null && !c.isCompleted) c.complete();
  }

  Future<void> _waitForData() {
    if (_queuedBytes > 0 || _closed) return Future<void>.value();
    final existing = _waitData;
    if (existing != null) return existing.future;
    final c = Completer<void>();
    _waitData = c;
    return c.future;
  }

  void _enqueue(Uint8List data) {
    _queue.add(data);
    _queuedBytes += data.length;
    _wakeWaiters();
  }

  Uint8List? _dequeue() {
    if (_queue.isEmpty) return null;
    final chunk = _queue.removeFirst();
    _queuedBytes -= chunk.length;
    return chunk;
  }

  void _noteUpstreamBytes(int n) {
    if (n <= 0) return;
    _rateSampleBytes += n;
    final started = _rateSampleStarted ??= DateTime.now();
    final elapsedMs = DateTime.now().difference(started).inMilliseconds;
    if (elapsedMs >= 2000 && _rateSampleBytes > 0) {
      _estimatedBytesPerSec = (_rateSampleBytes * 1000) ~/ elapsedMs;
      _rateSampleBytes = 0;
      _rateSampleStarted = DateTime.now();
    }
  }

  Future<void> _onRequest(HttpRequest request) async {
    final gen = _generation;
    final producerEpoch = ++_producerEpoch;
    final res = request.response;
    _clearQueue();
    unawaited(_runProducer(gen, producerEpoch));
    try {
      res.statusCode = HttpStatus.ok;
      res.headers.clear();
      res.headers.set(HttpHeaders.contentTypeHeader, 'video/mp2t');
      res.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      res.bufferOutput = false;

      var pending = 0;
      while (!_closed &&
          gen == _generation &&
          producerEpoch == _producerEpoch) {
        final chunk = _dequeue();
        if (chunk == null) {
          await _waitForData().timeout(
            const Duration(seconds: 30),
            onTimeout: () {},
          );
          if (_closed ||
              gen != _generation ||
              producerEpoch != _producerEpoch) {
            break;
          }
          continue;
        }
        res.add(chunk);
        pending += chunk.length;
        if (pending >= 64 * 1024) {
          pending = 0;
          await res.flush();
        }
      }
      if (pending > 0) {
        try {
          await res.flush();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[IPTV Proxy] client gone: $e');
    } finally {
      // Do NOT set [_closed] here — that flag is only for [stop].
      // mpv disconnect / soft reopen races a new [start] generation; marking
      // closed kills the fresh producer → empty loopback → format fail → crash.
      _wakeWaiters();
      try {
        await res.close();
      } catch (_) {}
    }
  }

  static const _fatalUpstreamCodes = {401, 403, 407};

  bool _producerAlive(int gen, int producerEpoch) =>
      !_closed && gen == _generation && producerEpoch == _producerEpoch;

  Future<void> _runProducer(int gen, int producerEpoch) async {
    var firstConnect = true;
    var fatalUpstream = 0;
    while (_producerAlive(gen, producerEpoch)) {
      HttpClientResponse? up;
      try {
        up = await _openUpstream();
        if (!_producerAlive(gen, producerEpoch)) break;
        if (up.statusCode < 200 || up.statusCode >= 300) {
          debugPrint('[IPTV Proxy] upstream HTTP ${up.statusCode}');
          await up.drain<void>();
          if (_fatalUpstreamCodes.contains(up.statusCode)) {
            fatalUpstream++;
            if (fatalUpstream >= 3) {
              debugPrint(
                '[IPTV Proxy] upstream auth/proxy failure — stopping producer',
              );
              break;
            }
          }
          await Future<void>.delayed(const Duration(milliseconds: 350));
          continue;
        }
        fatalUpstream = 0;

        var skipLeft = 0;
        var skipPlanned = 0;
        var minSkip = 0;
        var skipAborted = false;
        final reconnectAt = DateTime.now();
        if (firstConnect) {
          debugPrint('[IPTV Proxy] upstream connected (${up.statusCode})');
          firstConnect = false;
        } else {
          skipPlanned = iptvProxyReconnectSkipBytes(
            estimatedBytesPerSec: _estimatedBytesPerSec,
          );
          minSkip = iptvProxyMinSkipBytes(
            estimatedBytesPerSec: _estimatedBytesPerSec,
          );
          if (minSkip > skipPlanned) minSkip = skipPlanned;
          skipLeft = skipPlanned;
          final sinceEof = _lastUpstreamEofAt == null
              ? null
              : reconnectAt.difference(_lastUpstreamEofAt!);
          final queueSecs = _estimatedBytesPerSec > 0
              ? _queuedBytes / _estimatedBytesPerSec
              : 0.0;
          debugPrint(
            '[IPTV Proxy] upstream reconnected — skip '
            '${(skipPlanned / (1024 * 1024)).toStringAsFixed(2)}MiB '
            '(min=${(minSkip / (1024 * 1024)).toStringAsFixed(2)}MiB '
            'bps=$_estimatedBytesPerSec '
            'queue=${(_queuedBytes / (1024 * 1024)).toStringAsFixed(2)}MiB'
            '${queueSecs > 0 ? ' ~${queueSecs.toStringAsFixed(1)}s' : ''} '
            'gap=${sinceEof?.inMilliseconds ?? -1}ms)',
          );
          try {
            onUpstreamReconnected?.call();
          } catch (_) {}
        }

        final abortFloor = iptvProxySkipAbortQueueFloorBytes(
          estimatedBytesPerSec: _estimatedBytesPerSec,
        );
        final skipStarted = DateTime.now();

        await for (final raw in up) {
          if (!_producerAlive(gen, producerEpoch)) break;
          var data = raw is Uint8List ? raw : Uint8List.fromList(raw);
          _noteUpstreamBytes(data.length);
          if (skipLeft > 0) {
            final skipped = skipPlanned - skipLeft;
            final elapsedMs =
                DateTime.now().difference(skipStarted).inMilliseconds;
            if (iptvProxyShouldAbortSkip(
              skippedBytes: skipped,
              minSkipBytes: minSkip,
              queuedBytes: _queuedBytes,
              abortFloorBytes: abortFloor,
              elapsedMs: elapsedMs,
            )) {
              skipAborted = true;
              debugPrint(
                '[IPTV Proxy] overlap skip early-abort '
                '(skipped=${(skipped / (1024 * 1024)).toStringAsFixed(2)}MiB '
                'of ${(skipPlanned / (1024 * 1024)).toStringAsFixed(2)}MiB '
                'queue=${(_queuedBytes / 1024).toStringAsFixed(0)}KiB '
                'floor=${(abortFloor / 1024).toStringAsFixed(0)}KiB '
                '${elapsedMs}ms) — feeding live',
              );
              skipLeft = 0;
            } else if (data.length <= skipLeft) {
              skipLeft -= data.length;
              continue;
            } else {
              data = data.sublist(skipLeft);
              skipLeft = 0;
              debugPrint(
                '[IPTV Proxy] overlap skip done '
                '(${(skipPlanned / (1024 * 1024)).toStringAsFixed(2)}MiB '
                '${elapsedMs}ms) — feeding live',
              );
            }
          }
          while (_producerAlive(gen, producerEpoch) &&
              _queuedBytes + data.length > _maxQueueBytes) {
            await Future<void>.delayed(const Duration(milliseconds: 15));
          }
          if (!_producerAlive(gen, producerEpoch)) break;
          _enqueue(data);
        }
        if (skipLeft > 0 && !skipAborted) {
          debugPrint(
            '[IPTV Proxy] overlap skip incomplete '
            '(left=${(skipLeft / 1024).toStringAsFixed(0)}KiB) — EOF',
          );
        }
        _lastUpstreamEofAt = DateTime.now();
        debugPrint('[IPTV Proxy] upstream EOF — reconnecting');
      } catch (e) {
        if (!_producerAlive(gen, producerEpoch)) break;
        debugPrint('[IPTV Proxy] upstream error: $e — reconnecting');
        _lastUpstreamEofAt = DateTime.now();
      } finally {
        try {
          await up?.drain<void>();
        } catch (_) {}
      }
      if (!_producerAlive(gen, producerEpoch)) break;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<HttpClientResponse> _openUpstream() async {
    final client = _client;
    if (client == null) {
      throw StateError('IPTV continuity proxy stopped');
    }
    final req = await client.getUrl(Uri.parse(_upstream));
    req.followRedirects = true;
    req.maxRedirects = 8;
    for (final e in _headers.entries) {
      req.headers.set(e.key, e.value);
    }
    if (!_headers.keys.any(
      (k) => k.toLowerCase() == HttpHeaders.userAgentHeader,
    )) {
      req.headers.set(
        HttpHeaders.userAgentHeader,
        'VLC/3.0.20 LibVLC/3.0.20',
      );
    }
    if (!_headers.keys.any(
      (k) => k.toLowerCase() == HttpHeaders.acceptHeader,
    )) {
      req.headers.set(HttpHeaders.acceptHeader, '*/*');
    }
    req.headers.set(HttpHeaders.connectionHeader, 'keep-alive');
    return req.close().timeout(const Duration(seconds: 20));
  }
}
