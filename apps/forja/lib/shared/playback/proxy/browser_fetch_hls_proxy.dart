import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:forja/shared/webview/forja_headless_in_app_webview.dart';

/// Local HLS that fetches playlist + segments inside a headless WebView.
///
/// Some CDNs (TCPWE / fhlsport `hedy`) serve TS to real Chromium but
/// `302 → streambk → 487 Wtl108` for rustls / MediaKit / wreq JA3. MediaKit
/// still plays natively off loopback — the WebView is fetch-only, not a player
/// and not an unlock sniff.
class BrowserFetchHlsProxy {
  BrowserFetchHlsProxy._();
  static final BrowserFetchHlsProxy instance = BrowserFetchHlsProxy._();

  HttpServer? _server;
  ForjaHeadlessInAppWebView? _hw;
  InAppWebViewController? _controller;
  String _milUrl = '';
  Map<String, String> _headers = const {};
  Future<void> _gate = Future<void>.value();
  var _gen = 0;

  Future<String?> start({
    required String milUrl,
    required Map<String, String> headers,
  }) async {
    final origin = _originFromHeaders(headers);
    if (origin.isEmpty) {
      debugPrint('[BrowserFetchHls] missing player Origin/Referer');
      return null;
    }
    await stop();
    final gen = ++_gen;
    _milUrl = milUrl.trim();
    _headers = Map<String, String>.from(headers);

    final ready = Completer<void>();
    final page = '$origin/player.html?mdata=MA==&ilang=en';
    _hw = ForjaHeadlessInAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri(page),
        headers: {
          'Referer': '$origin/',
          'User-Agent': _headers['User-Agent'] ??
              _headers['user-agent'] ??
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
                  'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 '
                  'Safari/605.1.15',
        },
      ),
      onWebViewCreated: (c) => _controller = c,
      onLoadStop: (c, _) {
        _controller = c;
        if (!ready.isCompleted) ready.complete();
      },
      onReceivedError: (controller, request, error) {
        if (!ready.isCompleted) {
          ready.completeError(
            StateError('browser fetch page failed: ${error.description}'),
          );
        }
      },
    );

    try {
      await _hw!.run();
      await ready.future.timeout(const Duration(seconds: 20));
    } catch (e) {
      debugPrint('[BrowserFetchHls] webview boot failed: $e');
      await stop();
      return null;
    }
    if (gen != _gen) return null;

    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen(
      (req) => _onRequest(req, gen),
      onError: (Object e) => debugPrint('[BrowserFetchHls] server: $e'),
    );
    final play = 'http://127.0.0.1:${_server!.port}/index.m3u8';
    debugPrint('[BrowserFetchHls] $play ← $_milUrl (via $origin)');
    return play;
  }

  Future<void> stop() async {
    _gen++;
    final server = _server;
    _server = null;
    final hw = _hw;
    _hw = null;
    _controller = null;
    _milUrl = '';
    _headers = const {};
    try {
      await server?.close(force: true);
    } catch (_) {}
    try {
      await hw?.dispose();
    } catch (_) {}
  }

  static String _originFromHeaders(Map<String, String> headers) {
    String? take(String key) {
      for (final e in headers.entries) {
        if (e.key.toLowerCase() == key) {
          final v = e.value.trim();
          if (v.isNotEmpty) return v;
        }
      }
      return null;
    }

    final origin = take('origin');
    if (origin != null) {
      final u = Uri.tryParse(origin);
      if (u != null && u.hasScheme && u.host.isNotEmpty) {
        return '${u.scheme}://${u.host}';
      }
      if (origin.startsWith('http')) {
        return origin.replaceAll(RegExp(r'/$'), '');
      }
    }
    final ref = take('referer');
    if (ref != null) {
      final u = Uri.tryParse(ref);
      if (u != null && u.hasScheme && u.host.isNotEmpty) {
        return '${u.scheme}://${u.host}';
      }
    }
    return '';
  }

  Future<void> _onRequest(HttpRequest req, int gen) async {
    if (gen != _gen) {
      req.response.statusCode = HttpStatus.serviceUnavailable;
      await req.response.close();
      return;
    }
    try {
      final path = req.uri.path;
      if (path == '/index.m3u8' || path == '/') {
        await _servePlaylist(req);
      } else if (path == '/s') {
        await _serveSegment(req);
      } else {
        req.response.statusCode = HttpStatus.notFound;
        await req.response.close();
      }
    } catch (e) {
      debugPrint('[BrowserFetchHls] request error: $e');
      try {
        req.response.statusCode = HttpStatus.badGateway;
        await req.response.close();
      } catch (_) {}
    }
  }

  Future<void> _servePlaylist(HttpRequest req) async {
    final body = await _browserFetchText(_milUrl);
    if (body == null || !body.contains('#EXTM3U')) {
      req.response.statusCode = HttpStatus.badGateway;
      await req.response.close();
      return;
    }
    final base = _milUrl;
    final port = _server!.port;
    final out = StringBuffer();
    for (final line in body.split('\n')) {
      final t = line.trimRight();
      if (t.isEmpty || t.startsWith('#')) {
        out.writeln(t);
        continue;
      }
      final abs = Uri.parse(base).resolve(t.trim()).toString();
      out.writeln(
        'http://127.0.0.1:$port/s?u=${Uri.encodeQueryComponent(abs)}',
      );
    }
    final bytes = utf8.encode(out.toString());
    req.response.statusCode = HttpStatus.ok;
    req.response.headers.contentType =
        ContentType('application', 'vnd.apple.mpegurl', charset: 'utf-8');
    req.response.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
    req.response.contentLength = bytes.length;
    req.response.add(bytes);
    await req.response.close();
  }

  Future<void> _serveSegment(HttpRequest req) async {
    final u = req.uri.queryParameters['u']?.trim() ?? '';
    if (u.isEmpty || !u.startsWith('http')) {
      req.response.statusCode = HttpStatus.badRequest;
      await req.response.close();
      return;
    }
    final bytes = await _browserFetchBytes(u);
    if (bytes == null || bytes.isEmpty) {
      req.response.statusCode = HttpStatus.badGateway;
      await req.response.close();
      return;
    }
    req.response.statusCode = HttpStatus.ok;
    req.response.headers.contentType = ContentType('video', 'mp2t');
    req.response.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
    req.response.contentLength = bytes.length;
    req.response.add(bytes);
    await req.response.close();
  }

  Future<String?> _browserFetchText(String url) async {
    final raw = await _browserFetch(url, asText: true);
    if (raw == null) return null;
    final map = jsonDecode(raw);
    if (map is! Map || map['ok'] != true) return null;
    final status = map['status'];
    if (status is! num || status < 200 || status >= 300) return null;
    return (map['text'] ?? '').toString();
  }

  Future<Uint8List?> _browserFetchBytes(String url) async {
    final raw = await _browserFetch(url, asText: false);
    if (raw == null) return null;
    final map = jsonDecode(raw);
    if (map is! Map || map['ok'] != true) return null;
    final status = map['status'];
    if (status is! num || status < 200 || status >= 300) return null;
    final b64 = (map['b64'] ?? '').toString();
    if (b64.isEmpty) return null;
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _browserFetch(String url, {required bool asText}) {
    final prev = _gate;
    final done = Completer<void>();
    _gate = done.future;
    return prev
        .then((_) => _browserFetchUnlocked(url, asText: asText))
        .whenComplete(() {
      if (!done.isCompleted) done.complete();
    });
  }

  Future<String?> _browserFetchUnlocked(
    String url, {
    required bool asText,
  }) async {
    final c = _controller;
    if (c == null) return null;
    final hdrJson = jsonEncode(_headers);
    final urlJson = jsonEncode(url);
    final asTextLit = asText ? 'true' : 'false';
    try {
      final asyncResult = await c.callAsyncJavaScript(
        functionBody: '''
          const url = $urlJson;
          const headers = $hdrJson;
          const asText = $asTextLit;
          try {
            const resp = await fetch(url, {
              headers: headers,
              credentials: 'omit',
              redirect: 'follow',
            });
            const status = resp.status;
            if (asText) {
              const text = await resp.text();
              return JSON.stringify({ ok: true, status: status, text: text });
            }
            const ab = await resp.arrayBuffer();
            const bytes = new Uint8Array(ab);
            let s = '';
            const step = 8192;
            for (let i = 0; i < bytes.length; i += step) {
              s += String.fromCharCode.apply(
                null,
                bytes.subarray(i, Math.min(i + step, bytes.length)),
              );
            }
            return JSON.stringify({ ok: true, status: status, b64: btoa(s) });
          } catch (e) {
            return JSON.stringify({ ok: false, error: String(e) });
          }
        ''',
      );
      final v = asyncResult?.value;
      if (v == null) return null;
      final s = v.toString();
      if (s.isEmpty || s == 'null') return null;
      return s;
    } catch (e) {
      debugPrint('[BrowserFetchHls] fetch failed: $e');
      return null;
    }
  }
}
