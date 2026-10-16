import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Size;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:forja/shared/webview/forja_headless_in_app_webview.dart';

/// Local HLS that fetches playlist + segments inside a headless WebView.
///
/// Some CDNs (TCPWE / fhlsport `hedy`) serve TS to real Chromium/WebKit on the
/// **player origin** but `302 → streambk → 487 Wtl108` for rustls / MediaKit /
/// wreq JA3 — and also for `file://` / wrong Origin. MediaKit plays loopback;
/// the WebView is fetch-only (not a player, not sniff).
class BrowserFetchHlsProxy {
  BrowserFetchHlsProxy._();
  static final BrowserFetchHlsProxy instance = BrowserFetchHlsProxy._();

  HttpServer? _server;
  ForjaHeadlessInAppWebView? _hw;
  InAppWebViewController? _controller;
  String _milUrl = '';
  String _playerOrigin = '';
  String _playerReferrer = '';
  Map<String, String> _fetchHeaders = const {};
  Future<void> _gate = Future<void>.value();
  var _gen = 0;

  /// Pack tool (`ctx.live.browserFetchHls`): Chromium-fetch HLS → loopback URL.
  ///
  /// Same player origin reuses one WebView + server so multi-channel resolve
  /// does not reboot the hop per stream.
  Future<String?> open({
    required String milUrl,
    required Map<String, String> headers,
  }) async {
    final mil = milUrl.trim();
    if (mil.isEmpty || !mil.startsWith('http')) return null;
    final playerOrigin = _originFromHeaders(headers);
    if (playerOrigin.isEmpty) {
      debugPrint('[BrowserFetchHls] missing player Origin/Referer');
      return null;
    }
    if (_server != null &&
        _controller != null &&
        _playerOrigin == playerOrigin) {
      _fetchHeaders = _safeFetchHeaders(headers);
      final probe = await _browserFetchText(mil);
      if (probe == null || !probe.contains('#EXTM3U')) {
        debugPrint('[BrowserFetchHls] playlist probe failed for $mil');
        return null;
      }
      final play =
          'http://127.0.0.1:${_server!.port}/p?u=${Uri.encodeQueryComponent(mil)}';
      debugPrint('[BrowserFetchHls] reuse $play ← $mil');
      return play;
    }
    return start(milUrl: mil, headers: headers);
  }

  Future<String?> start({
    required String milUrl,
    required Map<String, String> headers,
  }) async {
    final playerOrigin = _originFromHeaders(headers);
    if (playerOrigin.isEmpty) {
      debugPrint('[BrowserFetchHls] missing player Origin/Referer');
      return null;
    }
    await stop();
    final gen = ++_gen;
    _milUrl = milUrl.trim();
    _playerOrigin = playerOrigin;
    _playerReferrer = '$playerOrigin/';
    _fetchHeaders = _safeFetchHeaders(headers);

    final ready = Completer<void>();
    // Real navigation to the CDN allowlist host — Origin/Referer + cookies.
    // initialData+baseUrl alone still got streambk TypeError on .json segments.
    _hw = ForjaHeadlessInAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri(_playerReferrer),
        headers: {
          'User-Agent': _fetchHeaders['User-Agent'] ??
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
                  'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 '
                  'Safari/605.1.15',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        },
      ),
      initialSize: const Size(64, 64),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        isInspectable: kDebugMode,
        transparentBackground: true,
        supportZoom: false,
        mediaPlaybackRequiresUserGesture: false,
        mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
        userAgent: _fetchHeaders['User-Agent'],
      ),
      onWebViewCreated: (c) => _controller = c,
      onLoadStop: (c, _) {
        _controller = c;
        if (!ready.isCompleted) ready.complete();
      },
      onReceivedError: (controller, request, error) {
        // Player shell 403/404 is fine — we only need the document origin.
        if (!ready.isCompleted) ready.complete();
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

    // Replace player shell with a blank same-origin doc (no their JS).
    try {
      await _controller?.loadData(
        data:
            '<!doctype html><html><head><meta charset="utf-8"></head>'
            '<body></body></html>',
        mimeType: 'text/html',
        encoding: 'utf-8',
        baseUrl: WebUri(_playerReferrer),
      );
      await Future<void>.delayed(const Duration(milliseconds: 80));
    } catch (_) {}
    if (gen != _gen) return null;

    final probe = await _browserFetchText(_milUrl);
    if (probe == null || !probe.contains('#EXTM3U')) {
      debugPrint('[BrowserFetchHls] playlist probe failed for $_milUrl');
      await stop();
      return null;
    }
    if (gen != _gen) return null;

    // Warm one segment. Do NOT fail-closed — playlist hop is enough to list
    // Providers; /s retries segments during play (streambk can flake once).
    final warmSeg = _firstSegmentUrl(probe, _milUrl);
    if (warmSeg != null) {
      final warm = await _browserFetchBytes(warmSeg);
      if (warm == null || warm.isEmpty) {
        debugPrint(
          '[BrowserFetchHls] segment warm miss (continuing) $warmSeg',
        );
      }
    }
    if (gen != _gen) return null;

    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen(
      (req) => _onRequest(req, gen),
      onError: (Object e) => debugPrint('[BrowserFetchHls] server: $e'),
    );
    final play = 'http://127.0.0.1:${_server!.port}/index.m3u8';
    debugPrint(
      '[BrowserFetchHls] $play ← $_milUrl (origin $_playerOrigin, '
      '${probe.length}b)',
    );
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
    _playerOrigin = '';
    _playerReferrer = '';
    _fetchHeaders = const {};
    try {
      await server?.close(force: true);
    } catch (_) {}
    try {
      await hw?.dispose();
    } catch (_) {}
  }

  static String? _firstSegmentUrl(String playlist, String base) {
    for (final line in playlist.split('\n')) {
      final t = line.trim();
      if (t.isEmpty || t.startsWith('#')) continue;
      final abs = Uri.parse(base).resolve(t).toString();
      if (!_looksLikePlaylist(abs)) return abs;
    }
    return null;
  }

  static Map<String, String> _safeFetchHeaders(Map<String, String> headers) {
    // Origin/Referer come from document + fetch referrer — do not forge them.
    const blocked = {
      'origin',
      'referer',
      'host',
      'connection',
      'content-length',
      'accept-encoding',
    };
    final out = <String, String>{};
    headers.forEach((k, v) {
      final key = k.trim();
      final val = v.trim();
      if (key.isEmpty || val.isEmpty) return;
      if (blocked.contains(key.toLowerCase())) return;
      out[key] = val;
    });
    // Chrome UA — fhlsport serves primary TS to Chromium; WebKit often 302→streambk.
    out.putIfAbsent(
      'User-Agent',
      () =>
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
          'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 '
          'Safari/537.36',
    );
    out.putIfAbsent('Accept', () => '*/*');
    out.putIfAbsent('Accept-Language', () => 'en-US,en;q=0.9');
    out.putIfAbsent('Sec-Fetch-Dest', () => 'empty');
    out.putIfAbsent('Sec-Fetch-Mode', () => 'cors');
    out.putIfAbsent('Sec-Fetch-Site', () => 'cross-site');
    return out;
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

  static bool _looksLikePlaylist(String url) {
    final lower = url.toLowerCase();
    final q = lower.indexOf('?');
    final path = q < 0 ? lower : lower.substring(0, q);
    return path.endsWith('.m3u8') || path.endsWith('.m3u');
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
        await _servePlaylist(req, _milUrl);
      } else if (path == '/p') {
        final u = req.uri.queryParameters['u']?.trim() ?? '';
        if (u.isEmpty || !u.startsWith('http')) {
          req.response.statusCode = HttpStatus.badRequest;
          await req.response.close();
          return;
        }
        await _servePlaylist(req, u);
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

  Future<void> _servePlaylist(HttpRequest req, String milUrl) async {
    final body = await _browserFetchText(milUrl);
    if (body == null || !body.contains('#EXTM3U')) {
      debugPrint('[BrowserFetchHls] playlist miss ${req.uri.path}');
      req.response.statusCode = HttpStatus.badGateway;
      await req.response.close();
      return;
    }
    final port = _server!.port;
    final out = StringBuffer();
    for (final line in body.split('\n')) {
      final t = line.trimRight();
      if (t.isEmpty || t.startsWith('#')) {
        out.writeln(_rewriteTagUris(t, milUrl, port));
        continue;
      }
      final abs = Uri.parse(milUrl).resolve(t.trim()).toString();
      if (_looksLikePlaylist(abs)) {
        out.writeln(
          'http://127.0.0.1:$port/p?u=${Uri.encodeQueryComponent(abs)}',
        );
      } else {
        out.writeln(
          'http://127.0.0.1:$port/s?u=${Uri.encodeQueryComponent(abs)}',
        );
      }
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

  String _rewriteTagUris(String line, String base, int port) {
    if (!line.contains('URI="')) return line;
    return line.replaceAllMapped(RegExp(r'URI="([^"]+)"'), (m) {
      final raw = m.group(1) ?? '';
      if (raw.isEmpty) return m.group(0)!;
      final abs = Uri.parse(base).resolve(raw).toString();
      if (!abs.startsWith('http')) return m.group(0)!;
      final path = _looksLikePlaylist(abs) ? 'p' : 's';
      return 'URI="http://127.0.0.1:$port/$path?u=${Uri.encodeQueryComponent(abs)}"';
    });
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
      debugPrint('[BrowserFetchHls] segment miss $u');
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
    final map = _decodeFetchJson(raw);
    if (map == null) return null;
    if (map['ok'] != true) {
      debugPrint('[BrowserFetchHls] fetch !ok text: ${map['error']} url=$url');
      return null;
    }
    final status = map['status'];
    if (status is! num || status < 200 || status >= 300) {
      debugPrint('[BrowserFetchHls] fetch status=$status text url=$url');
      return null;
    }
    return (map['text'] ?? '').toString();
  }

  Future<Uint8List?> _browserFetchBytes(String url) async {
    final raw = await _browserFetch(url, asText: false);
    if (raw == null) return null;
    final map = _decodeFetchJson(raw);
    if (map == null) return null;
    if (map['ok'] != true) {
      debugPrint('[BrowserFetchHls] fetch !ok bin: ${map['error']} url=$url');
      return null;
    }
    final status = map['status'];
    if (status is! num || status < 200 || status >= 300) {
      debugPrint('[BrowserFetchHls] fetch status=$status bin url=$url');
      return null;
    }
    final b64 = (map['b64'] ?? '').toString();
    if (b64.isEmpty) return null;
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _decodeFetchJson(String raw) {
    try {
      final v = jsonDecode(raw);
      if (v is Map<String, dynamic>) return v;
      if (v is Map) return v.cast<String, dynamic>();
    } catch (e) {
      debugPrint('[BrowserFetchHls] bad fetch json: $e');
    }
    return null;
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
    final hdrJson = jsonEncode(_fetchHeaders);
    final urlJson = jsonEncode(url);
    final refJson = jsonEncode(_playerReferrer);
    final asTextLit = asText ? 'true' : 'false';
    try {
      final asyncResult = await c.callAsyncJavaScript(
        functionBody: '''
          const startUrl = $urlJson;
          const headers = $hdrJson;
          const referrer = $refJson;
          const asText = $asTextLit;
          try {
            // Manual redirects: auto-follow to streambk without ACAO → TypeError.
            let url = startUrl;
            let resp = null;
            for (let hop = 0; hop < 8; hop++) {
              resp = await fetch(url, {
                headers: headers,
                credentials: 'omit',
                redirect: 'manual',
                referrer: referrer,
                referrerPolicy: 'unsafe-url',
                mode: 'cors',
                cache: 'no-store',
              });
              const st = resp.status;
              if (st >= 300 && st < 400) {
                const loc = resp.headers.get('Location') || resp.headers.get('location');
                if (!loc) {
                  return JSON.stringify({
                    ok: false,
                    error: 'redirect without Location',
                    status: st,
                  });
                }
                url = new URL(loc, url).href;
                continue;
              }
              break;
            }
            if (!resp) {
              return JSON.stringify({ ok: false, error: 'no response' });
            }
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
      if (v is Map) return jsonEncode(v);
      final s = v.toString();
      if (s.isEmpty || s == 'null') return null;
      return s;
    } catch (e) {
      debugPrint('[BrowserFetchHls] fetch failed: $e');
      return null;
    }
  }
}
