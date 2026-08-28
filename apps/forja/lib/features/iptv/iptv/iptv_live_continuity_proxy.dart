import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Live HTTP TS continuity: mpv reads loopback; we reopen the CDN when it
/// closes the socket without tearing down mpv's connection.
///
/// On reconnect, Xtream often restarts a few seconds *behind* the previous
/// socket end — piping that raw would look like a replay. We:
/// 1. Keep a multi-second read-ahead queue so mpv rarely underruns mid-reconnect
/// 2. Skip the first ~3 MiB of each reconnect (CDN overlap) before feeding mpv
/// 3. Notify [onUpstreamReconnected] so the player can nudge playback (no flush
///    while demuxer still has a healthy ahead cushion — play-through)
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

  /// Fresh GET usually overlaps the last seconds we already sent.
  static const int _reconnectSkipBytes = 3 * 1024 * 1024;

  int _maxQueueBytes = 12 * 1024 * 1024;

  Uri? get localUri {
    final p = _server?.port;
    if (p == null || p <= 0) return null;
    return Uri.parse('http://127.0.0.1:$p/live.ts');
  }

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

  Future<void> _onRequest(HttpRequest request) async {
    final gen = _generation;
    final res = request.response;
    _clearQueue();
    unawaited(_runProducer(gen));
    try {
      res.statusCode = HttpStatus.ok;
      res.headers.clear();
      res.headers.set(HttpHeaders.contentTypeHeader, 'video/mp2t');
      res.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      res.bufferOutput = false;

      var pending = 0;
      while (!_closed && gen == _generation) {
        final chunk = _dequeue();
        if (chunk == null) {
          await _waitForData().timeout(
            const Duration(seconds: 30),
            onTimeout: () {},
          );
          if (_closed || gen != _generation) break;
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

  Future<void> _runProducer(int gen) async {
    var firstConnect = true;
    var fatalUpstream = 0;
    while (!_closed && gen == _generation) {
      HttpClientResponse? up;
      try {
        up = await _openUpstream();
        if (_closed || gen != _generation) break;
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
        if (firstConnect) {
          debugPrint('[IPTV Proxy] upstream connected (${up.statusCode})');
          firstConnect = false;
        } else {
          // Overlap from fresh live GET → would replay. Skip at byte layer;
          // player plays through demuxer cushion when cache is healthy.
          skipLeft = _reconnectSkipBytes;
          debugPrint(
            '[IPTV Proxy] upstream reconnected — skip ${skipLeft >> 20}MiB overlap',
          );
          try {
            onUpstreamReconnected?.call();
          } catch (_) {}
        }

        await for (final raw in up) {
          if (_closed || gen != _generation) break;
          var data = raw is Uint8List ? raw : Uint8List.fromList(raw);
          if (skipLeft > 0) {
            if (data.length <= skipLeft) {
              skipLeft -= data.length;
              continue;
            }
            data = data.sublist(skipLeft);
            skipLeft = 0;
            debugPrint('[IPTV Proxy] overlap skip done — feeding live');
          }
          while (!_closed &&
              gen == _generation &&
              _queuedBytes + data.length > _maxQueueBytes) {
            await Future<void>.delayed(const Duration(milliseconds: 15));
          }
          if (_closed || gen != _generation) break;
          _enqueue(data);
        }
        debugPrint('[IPTV Proxy] upstream EOF — reconnecting');
      } catch (e) {
        if (_closed || gen != _generation) break;
        debugPrint('[IPTV Proxy] upstream error: $e — reconnecting');
      } finally {
        try {
          await up?.drain<void>();
        } catch (_) {}
      }
      if (_closed || gen != _generation) break;
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
