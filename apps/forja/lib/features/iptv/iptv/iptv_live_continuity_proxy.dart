import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Live HTTP TS continuity: mpv reads loopback; we reopen the CDN when it
/// closes the socket (~every 15–70MB on many Xtream panels) without tearing
/// down mpv's connection. That is what makes the stop invisible.
class IptvLiveContinuityProxy {
  HttpServer? _server;
  HttpClient? _client;
  String _upstream = '';
  Map<String, String> _headers = const {};
  var _closed = false;
  int _generation = 0;
  int _upstreamEpoch = 0;

  Uri? get localUri {
    final p = _server?.port;
    if (p == null || p <= 0) return null;
    return Uri.parse('http://127.0.0.1:$p/live.ts');
  }

  Future<Uri> start({
    required String upstreamUrl,
    required Map<String, String> headers,
  }) async {
    await stop();
    _closed = false;
    _upstream = upstreamUrl;
    _headers = Map<String, String>.from(headers);
    _client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12)
      ..idleTimeout = const Duration(seconds: 30)
      ..autoUncompress = false;
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen(
      _onRequest,
      onError: (Object e) => debugPrint('[IPTV Proxy] server error: $e'),
    );
    final uri = localUri!;
    debugPrint('[IPTV Proxy] $uri ← $upstreamUrl');
    return uri;
  }

  Future<void> stop() async {
    _closed = true;
    _generation++;
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

  Future<void> _onRequest(HttpRequest request) async {
    final gen = _generation;
    final res = request.response;
    var wrote = false;
    try {
      res.statusCode = HttpStatus.ok;
      res.headers.clear();
      res.headers.set(HttpHeaders.contentTypeHeader, 'video/mp2t');
      res.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      res.bufferOutput = false;

      while (!_closed && gen == _generation) {
        final epoch = ++_upstreamEpoch;
        HttpClientResponse? up;
        try {
          up = await _openUpstream();
          if (_closed || gen != _generation) break;
          if (up.statusCode < 200 || up.statusCode >= 300) {
            debugPrint('[IPTV Proxy] upstream HTTP ${up.statusCode}');
            await up.drain<void>();
            await Future<void>.delayed(const Duration(milliseconds: 350));
            continue;
          }
          if (epoch == 1 || !wrote) {
            debugPrint('[IPTV Proxy] upstream connected (${up.statusCode})');
          } else {
            debugPrint('[IPTV Proxy] upstream reconnected');
          }
          var pending = 0;
          await for (final chunk in up) {
            if (_closed || gen != _generation) break;
            res.add(chunk);
            wrote = true;
            pending += chunk.length;
            // Flush often enough for live, not every packet.
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
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
    } catch (e) {
      debugPrint('[IPTV Proxy] client gone: $e');
    } finally {
      try {
        await res.close();
      } catch (_) {}
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
    _headers.forEach(req.headers.set);
    return req.close().timeout(const Duration(seconds: 20));
  }
}
