import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'package:forja/features/live_matches/live_embed_nav.dart';

/// Local HTTP front for Streamed Android handoff.
///
/// Exo only talks to loopback. Upstream `strmd.st` bytes are fetched **inside**
/// the embed WebView (Chromium cookies + CORS), then returned to Exo — OkHttp /
/// Rust re-GETs of the same URL get CDN 403.
class LiveEmbedWebViewProxy {
  LiveEmbedWebViewProxy();

  HttpServer? _server;
  InAppWebViewController? _controller;
  String? _playlistBody;
  int _nextId = 0;
  final Map<String, Completer<_ProxyFetchResult>> _pending = {};
  var _closed = false;

  int get port => _server?.port ?? 0;

  String get playlistUrl =>
      port > 0 ? 'http://127.0.0.1:$port/playlist.m3u8' : '';

  void attachController(InAppWebViewController? controller) {
    _controller = controller;
  }

  /// Complete a JS `liveProxyFetchResult` handler call.
  void onFetchResult(
    String id,
    int status,
    String base64Body,
    String contentType,
  ) {
    final c = _pending[id];
    if (c == null || c.isCompleted) return;
    // Ignore empty CORS failures briefly so a sibling iframe can still win.
    if (status <= 0 && base64Body.isEmpty) {
      debugPrint('[LiveMatches] WebView proxy ignore empty fail id=$id');
      Future<void>.delayed(const Duration(milliseconds: 1200), () {
        final pending = _pending[id];
        if (pending == null || pending.isCompleted) return;
        _pending.remove(id);
        pending.complete(
          _ProxyFetchResult(
            status: 502,
            bytes: Uint8List(0),
            contentType: '',
          ),
        );
      });
      return;
    }
    _pending.remove(id);
    try {
      final bytes =
          base64Body.isEmpty ? Uint8List(0) : base64Decode(base64Body);
      c.complete(
        _ProxyFetchResult(
          status: status,
          bytes: bytes,
          contentType: contentType,
        ),
      );
    } catch (e) {
      c.completeError(e);
    }
  }

  Future<void> start({
    required String playlistBody,
    required String playlistSourceUrl,
  }) async {
    await stop();
    _closed = false;
    final absolute =
        liveEmbedRewriteM3u8Absolute(playlistBody, playlistSourceUrl);
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final p = _server!.port;
    final proxyPrefix = 'http://127.0.0.1:$p/u?url=';
    _playlistBody = liveEmbedRewriteM3u8ThroughProxy(
      absolute,
      proxyPrefix: proxyPrefix,
    );
    debugPrint(
      '[LiveMatches] WebView proxy on 127.0.0.1:$p '
      '(playlist ${_playlistBody!.length} chars)',
    );
    unawaited(_serve());
  }

  Future<void> stop() async {
    _closed = true;
    for (final c in _pending.values) {
      if (!c.isCompleted) {
        c.completeError(StateError('proxy stopped'));
      }
    }
    _pending.clear();
    final s = _server;
    _server = null;
    _playlistBody = null;
    if (s != null) {
      try {
        await s.close(force: true);
      } catch (_) {}
    }
  }

  Future<void> _serve() async {
    final server = _server;
    if (server == null) return;
    await for (final req in server) {
      if (_closed) {
        try {
          await req.response.close();
        } catch (_) {}
        continue;
      }
      try {
        await _handle(req);
      } catch (e) {
        debugPrint('[LiveMatches] WebView proxy handler error: $e');
        try {
          req.response.statusCode = 502;
          await req.response.close();
        } catch (_) {}
      }
    }
  }

  Future<void> _handle(HttpRequest req) async {
    final path = req.uri.path;
    if (path == '/playlist.m3u8') {
      final body = _playlistBody ?? '';
      req.response.statusCode = 200;
      req.response.headers.contentType =
          ContentType('application', 'vnd.apple.mpegurl', charset: 'utf-8');
      req.response.headers.set('Access-Control-Allow-Origin', '*');
      req.response.write(body);
      await req.response.close();
      return;
    }

    if (path == '/u') {
      final target = req.uri.queryParameters['url'] ?? '';
      if (target.isEmpty) {
        req.response.statusCode = 400;
        await req.response.close();
        return;
      }
      final result = await _fetchViaWebView(target);
      var bytes = result.bytes;
      var status = result.status <= 0 ? 502 : result.status;
      var ct = result.contentType;

      // Child playlists must also stay on loopback.
      final text = _tryUtf8(bytes);
      if (text != null && text.trimLeft().startsWith('#EXTM3U')) {
        final rewritten = liveEmbedRewriteM3u8ThroughProxy(
          liveEmbedRewriteM3u8Absolute(text, target),
          proxyPrefix: 'http://127.0.0.1:$port/u?url=',
        );
        bytes = Uint8List.fromList(utf8.encode(rewritten));
        ct = 'application/vnd.apple.mpegurl';
        status = 200;
      }

      req.response.statusCode = status;
      if (ct.isNotEmpty) {
        req.response.headers.set(HttpHeaders.contentTypeHeader, ct);
      } else if (target.contains('.m3u8')) {
        req.response.headers.contentType =
            ContentType('application', 'vnd.apple.mpegurl');
      } else {
        req.response.headers.contentType = ContentType('video', 'mp2t');
      }
      req.response.headers.set('Access-Control-Allow-Origin', '*');
      req.response.add(bytes);
      await req.response.close();
      return;
    }

    req.response.statusCode = 404;
    await req.response.close();
  }

  /// Re-GET an `#EXTM3U` body inside Chromium (embed iframe). Use when the
  /// JS spy never saw the playlist text — Dart/OkHttp re-GETs get CDN 403.
  Future<String?> fetchPlaylistText(String url) async {
    final result = await _fetchViaWebView(url);
    if (result.status < 200 || result.status >= 400 || result.bytes.isEmpty) {
      debugPrint(
        '[LiveMatches] WebView playlist seed status=${result.status} '
        'bytes=${result.bytes.length}',
      );
      return null;
    }
    try {
      final text = utf8.decode(result.bytes);
      if (text.trimLeft().startsWith('#EXTM3U')) {
        debugPrint(
          '[LiveMatches] WebView playlist seeded (${text.length} chars)',
        );
        return text;
      }
      final snip = text.length > 60 ? text.substring(0, 60) : text;
      debugPrint(
        '[LiveMatches] WebView playlist seed not m3u8: '
        '${snip.replaceAll('\n', ' ')}',
      );
    } catch (e) {
      debugPrint('[LiveMatches] WebView playlist seed decode failed: $e');
    }
    return null;
  }

  Future<_ProxyFetchResult> _fetchViaWebView(String url) async {
    final ctrl = _controller;
    if (ctrl == null) {
      return _ProxyFetchResult(
        status: 502,
        bytes: Uint8List(0),
        contentType: '',
      );
    }
    final id = 'p${_nextId++}';
    final c = Completer<_ProxyFetchResult>();
    _pending[id] = c;

    final js = '''
(function(){
  var msg = {__forjaProxyFetch:true, id:${jsonEncode(id)}, url:${jsonEncode(url)}};
  // Only the embed iframe has CORS access to strmd.st — never fetch from
  // the catalog wrapper origin (that races a 0-status failure into Dart).
  try {
    var iframes = document.querySelectorAll('iframe');
    var n = 0;
    for (var i = 0; i < iframes.length; i++) {
      try { iframes[i].contentWindow.postMessage(msg, '*'); n++; } catch (_) {}
    }
    if (n === 0) {
      try { window.postMessage(msg, '*'); } catch (_) {}
    }
  } catch (_) {}
})();
''';
    try {
      await ctrl.evaluateJavascript(source: js);
    } catch (e) {
      _pending.remove(id);
      return _ProxyFetchResult(
        status: 502,
        bytes: Uint8List(0),
        contentType: '',
      );
    }

    try {
      return await c.future.timeout(const Duration(seconds: 20));
    } on TimeoutException {
      _pending.remove(id);
      debugPrint('[LiveMatches] WebView proxy fetch timeout: $url');
      return _ProxyFetchResult(
        status: 504,
        bytes: Uint8List(0),
        contentType: '',
      );
    } catch (e) {
      _pending.remove(id);
      debugPrint('[LiveMatches] WebView proxy fetch failed: $e');
      return _ProxyFetchResult(
        status: 502,
        bytes: Uint8List(0),
        contentType: '',
      );
    }
  }

  static String? _tryUtf8(Uint8List bytes) {
    if (bytes.isEmpty) return null;
    try {
      final s = utf8.decode(bytes);
      final head = s.trimLeft();
      if (head.startsWith('#EXTM3U')) return s;
      return null;
    } catch (_) {
      return null;
    }
  }
}

class _ProxyFetchResult {
  _ProxyFetchResult({
    required this.status,
    required this.bytes,
    required this.contentType,
  });

  final int status;
  final Uint8List bytes;
  final String contentType;
}

/// After absolutes: point every `http(s)` media URI at the local WebView proxy.
String liveEmbedRewriteM3u8ThroughProxy(
  String body, {
  required String proxyPrefix,
}) {
  String wrap(String raw) {
    final t = raw.trim();
    if (t.startsWith('http://') || t.startsWith('https://')) {
      return '$proxyPrefix${Uri.encodeComponent(t)}';
    }
    return raw;
  }

  final out = StringBuffer();
  for (final raw in body.split('\n')) {
    final line = raw.replaceAll('\r', '');
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      out.writeln(line);
      continue;
    }
    if (trimmed.startsWith('#')) {
      out.writeln(
        line.replaceAllMapped(
          RegExp(r'URI="([^"]+)"', caseSensitive: false),
          (m) {
            final u = m.group(1) ?? '';
            if (u.startsWith('http://') || u.startsWith('https://')) {
              return 'URI="${wrap(u)}"';
            }
            return m.group(0)!;
          },
        ),
      );
      continue;
    }
    out.writeln(wrap(trimmed));
  }
  return out.toString();
}
