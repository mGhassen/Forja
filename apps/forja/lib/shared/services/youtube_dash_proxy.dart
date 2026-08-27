import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Loopback so mpv sees a file.
///
/// Does **not** call YouTube `getManifest`. Isolate resolve already did that.
/// A second client walk (WEB / iOS / VR) is what 403s AAC and trips bot-check.
///
/// Bytes: C# MediaStream query `range=` (window 9898989). AAC first, then video.
class YoutubeDashProxy {
  static const int _chunk = 9898989;
  static const _androidUa =
      'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip';
  static const _iosUa =
      'com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)';
  static const _tvUa =
      'Mozilla/5.0 (ChromiumStylePlatform) Cobalt/Version,gzip(gfe)';
  static const _webUa =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.5 Safari/605.1.15';
  static const _androidVrUa =
      'com.google.android.apps.youtube.vr.oculus/1.56.21 (Linux; U; Android 12; Quest 3) gzip';

  http.Client? _http;
  _Gvs? _video;
  Uint8List? _aac;
  HttpServer? _server;
  var _closed = false;
  String? videoLocalUrl;
  String? audioLocalUrl;

  Future<YoutubeDashProxy> start({
    required Uri videoUrl,
    required Uri audioUrl,
    required int videoBytes,
    required int audioBytes,
  }) async {
    await stop();
    _closed = false;

    if (!_isHttp(videoUrl) || !_isHttp(audioUrl)) {
      throw StateError('SABR / hostless GVS');
    }
    // Isolate ANDROID googlevideo: 1 KB probe 206, real window 403.
    if (_isAndroid(videoUrl) || _isAndroid(audioUrl)) {
      throw StateError('ANDROID GVS');
    }
    if (videoBytes <= 0 || audioBytes <= 0) {
      throw StateError('missing clen');
    }

    _http = http.Client();
    final audio = _Gvs(audioUrl, audioBytes);
    debugPrint(
      '[YT dash proxy] pipe c=${audioUrl.queryParameters['c']} '
      'v=${videoUrl.queryParameters['itag']}/$videoBytes '
      'a=${audioUrl.queryParameters['itag']}/$audioBytes',
    );
    final aac = await _readAll(audio);
    if (aac == null || aac.isEmpty) {
      throw StateError('AAC GVS 403');
    }
    _video = _Gvs(videoUrl, videoBytes);
    _aac = aac;
    debugPrint('[YT dash proxy] aac ${aac.length} bytes');

    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen(_onRequest, onError: (Object e) {
      debugPrint('[YT dash proxy] $e');
    });
    final port = _server!.port;
    videoLocalUrl = 'http://127.0.0.1:$port/v';
    audioLocalUrl = 'http://127.0.0.1:$port/a';
    debugPrint('[YT dash proxy] $videoLocalUrl + $audioLocalUrl');
    return this;
  }

  Future<void> stop() async {
    _closed = true;
    final server = _server;
    _server = null;
    videoLocalUrl = null;
    audioLocalUrl = null;
    _video = null;
    _aac = null;
    final client = _http;
    _http = null;
    try {
      await server?.close(force: true);
    } catch (_) {}
    try {
      client?.close();
    } catch (_) {}
  }

  static bool _isHttp(Uri url) =>
      url.host.isNotEmpty &&
      (url.scheme == 'http' || url.scheme == 'https');

  static bool _isAndroid(Uri url) => url.queryParameters['c'] == 'ANDROID';

  static String _uaFor(Uri url) {
    switch (url.queryParameters['c']) {
      case 'ANDROID':
        return _androidUa;
      case 'ANDROID_VR':
        return _androidVrUa;
      case 'IOS':
        return _iosUa;
      case 'TVHTML5':
        return _tvUa;
      default:
        return _webUa;
    }
  }

  static Uri _rangeUrl(Uri url, int from, int to) {
    var s = url.toString();
    s = s.replaceAll(RegExp(r'&range=\d+-\d+'), '');
    s = s.replaceAll(RegExp(r'\?range=\d+-\d+&'), '?');
    s = s.replaceAll(RegExp(r'\?range=\d+-\d+$'), '');
    final join = s.contains('?') ? '&' : '?';
    return Uri.parse('$s${join}range=$from-$to');
  }

  /// One C# window. A 403 is a session reject, not a dialect miss.
  Future<http.StreamedResponse?> _gvsGet(
    Uri url, {
    required int from,
    required int clen,
  }) async {
    final client = _http;
    if (client == null) return null;
    final to = from + _chunk - 1;
    if (from >= clen) return null;
    final req = http.Request('GET', _rangeUrl(url, from, to));
    req.headers['user-agent'] = _uaFor(url);
    req.headers['accept-encoding'] = 'identity';
    req.headers['accept'] = '*/*';
    debugPrint(
      '[YT dash proxy] GVS c=${url.queryParameters['c']} '
      'qrange $from-$to itag=${url.queryParameters['itag']}',
    );
    try {
      final res = await client.send(req).timeout(const Duration(seconds: 20));
      if (res.statusCode < 400) return res;
      debugPrint('[YT dash proxy] ${res.statusCode} qrange=$from-$to');
      try {
        await res.stream.drain<void>();
      } catch (_) {}
    } catch (e) {
      debugPrint('[YT dash proxy] get $e');
    }
    return null;
  }

  Future<Uint8List?> _readAll(_Gvs info) async {
    final out = BytesBuilder(copy: false);
    var at = 0;
    while (!_closed && at < info.bytes) {
      final res = await _gvsGet(info.url, from: at, clen: info.bytes);
      if (res == null) return null;
      await for (final data in res.stream) {
        if (_closed) return null;
        at += data.length;
        out.add(data);
      }
    }
    if (out.isEmpty) return null;
    return out.takeBytes();
  }

  Future<void> _pipe(_Gvs info, IOSink sink, int pos) async {
    var at = pos;
    while (!_closed && at < info.bytes) {
      final res = await _gvsGet(info.url, from: at, clen: info.bytes);
      if (res == null) {
        debugPrint(
          '[YT dash proxy] stop itag=${info.url.queryParameters['itag']} '
          'pos=$at clen=${info.bytes}',
        );
        break;
      }
      await for (final data in res.stream) {
        if (_closed) break;
        at += data.length;
        sink.add(data);
      }
    }
  }

  Future<void> _onRequest(HttpRequest req) async {
    if (req.uri.path == '/a' && _aac != null) {
      await _serveBytes(req, _aac!, ContentType('audio', 'mp4'));
      return;
    }
    final info = req.uri.path == '/v' ? _video : null;
    if (info == null) {
      req.response.statusCode = 404;
      await req.response.close();
      return;
    }
    final res = req.response;
    final mime = info.url.queryParameters['mime'] ?? '';
    final webm = mime.contains('webm');
    res.headers.contentType = ContentType('video', webm ? 'webm' : 'mp4');
    final start = _rangeStart(req, info.bytes);
    if (req.method == 'HEAD') {
      _writeLengthHeaders(res, start, info.bytes);
      await res.close();
      return;
    }
    _writeLengthHeaders(res, start, info.bytes);
    try {
      await _pipe(info, res, start);
    } catch (e) {
      debugPrint('[YT dash proxy] serve $e');
    } finally {
      try {
        await res.close();
      } catch (_) {}
    }
  }

  Future<void> _serveBytes(
    HttpRequest req,
    Uint8List data,
    ContentType type,
  ) async {
    final res = req.response;
    res.headers.contentType = type;
    final clen = data.length;
    final start = _rangeStart(req, clen);
    if (req.method == 'HEAD') {
      _writeLengthHeaders(res, start, clen);
      await res.close();
      return;
    }
    _writeLengthHeaders(res, start, clen);
    try {
      res.add(start == 0 ? data : data.sublist(start));
    } catch (e) {
      debugPrint('[YT dash proxy] aac serve $e');
    } finally {
      try {
        await res.close();
      } catch (_) {}
    }
  }

  static int _rangeStart(HttpRequest req, int clen) {
    final h = req.headers.value(HttpHeaders.rangeHeader);
    if (h == null) return 0;
    final m = RegExp(r'bytes=(\d+)').firstMatch(h);
    if (m == null) return 0;
    final n = int.tryParse(m.group(1)!) ?? 0;
    if (n < 0 || n >= clen) return 0;
    return n;
  }

  static void _writeLengthHeaders(HttpResponse res, int start, int clen) {
    final remain = clen - start;
    if (start > 0) {
      res.statusCode = HttpStatus.partialContent;
      res.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes $start-${clen - 1}/$clen',
      );
    } else {
      res.statusCode = HttpStatus.ok;
    }
    res.headers.contentLength = remain;
  }
}

class _Gvs {
  final Uri url;
  final int bytes;
  const _Gvs(this.url, this.bytes);
}
