import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:flutter/foundation.dart';
import 'package:rust/rust.dart';
import 'package:scrapers/scrapers/scraper_aggregator.dart';
import 'package:api/api/subtitlecat_service.dart';

class LocalServerService {
  static final LocalServerService _instance = LocalServerService._internal();
  factory LocalServerService() => _instance;
  LocalServerService._internal();

  HttpServer? _server;
  final Router _router = Router();
  int _port = 0;
  int _rustProxyPort = 0;

  // Persistent HTTP client for connection reuse (keep-alive)
  final http.Client _httpClient = http.Client();

  int get port => _port;
  String get baseUrl => 'http://localhost:$_port';

  Future<void> start() async {
    if (_server != null) return;

    _setupRoutes();

    try {
      _server = await io.serve(_router.call, InternetAddress.loopbackIPv4, 0);
      _port = _server!.port;
      if (ForjaEngine.isReady) {
        final rustPort = ForjaRust.instance.proxyStart(0);
        if (rustPort > 0) {
          _rustProxyPort = rustPort;
          debugPrint('[LocalServer] Rust proxy on 127.0.0.1:$rustPort');
        }
      }
      debugPrint('[LocalServer] Started on $baseUrl');
    } catch (e) {
      debugPrint('[LocalServer] Error starting server: $e');
    }
  }

  void _setupRoutes() {
    _router.get('/api/ultimate', (Request request) async {
      final params = request.url.queryParameters;
      final query = params['query'];
      if (query == null || query.isEmpty) {
        return Response(400, body: json.encode({'error': 'Query parameter is required'}), headers: {'content-type': 'application/json'});
      }
      try {
        final results = await ScraperAggregator.searchAll(query);
        return Response.ok(json.encode({'query': query, 'totalResults': results.length, 'results': results}), headers: {'content-type': 'application/json'});
      } catch (e) {
        return Response(500, body: json.encode({'error': e.toString()}), headers: {'content-type': 'application/json'});
      }
    });

    // --- Tokybook Specialized Proxy ---
    _router.get('/toky-proxy', _handleTokyProxy);

    // --- Comic Specialized Proxy ---
    _router.get('/comic-proxy', _handleComicProxy);

    // --- Jellyfin Streaming Proxy ---
    _router.add('GET', '/jellyfin-stream', _handleJellyfinStream);
    _router.add('HEAD', '/jellyfin-stream', _handleJellyfinStream);

    _router.add('GET', '/proxy', _handleProxyRequest);
    _router.add('HEAD', '/proxy', _handleProxyRequest);

    // --- HLS-aware streaming proxy (rewrites m3u8 segment URLs) ---
    _router.add('GET', '/hls-proxy', _handleHlsProxy);
    _router.add('HEAD', '/hls-proxy', _handleHlsProxy);

    _router.get('/health', (Request request) {
      return Response.ok(json.encode({'status': 'ok', 'port': _port}), headers: {'content-type': 'application/json'});
    });

    // --- SubtitleCat on-demand translation ---
    // GET /subtitlecat-translate?orig=<absolute orig.srt URL>&tl=<lang>&name=<base>
    // Returns the translated SRT text/plain.
    _router.get('/subtitlecat-translate', (Request request) async {
      final p = request.url.queryParameters;
      final orig = p['orig'];
      final tl = p['tl'];
      final name = p['name'] ?? 'subtitle';
      if (orig == null || orig.isEmpty || tl == null || tl.isEmpty) {
        return Response(400,
            body: 'Missing orig or tl',
            headers: {'content-type': 'text/plain'});
      }
      try {
        final srt = await SubtitleCatService.instance.translateSrt(
          origUrl: orig,
          targetLang: tl,
        );
        return Response.ok(srt, headers: {
          'Content-Type': 'application/x-subrip; charset=utf-8',
          'Access-Control-Allow-Origin': '*',
          'Content-Disposition':
              'inline; filename="$name-$tl.srt"',
        });
      } catch (e) {
        debugPrint('[SubtitleCat] translate failed: $e');
        return Response.internalServerError(
          body: 'Translation failed: $e',
          headers: {'content-type': 'text/plain'},
        );
      }
    });
  }

  Future<Response> _handleTokyProxy(Request request) async {
    final params = request.url.queryParameters;
    final targetUrl = params['url'];
    final audiobookId = params['id'];
    final token = params['token'];
    final trackSrc = params['src'];

    if (targetUrl == null) return Response.notFound('Missing url');

    // FIX: Decode the path before passing to Uri.https to prevent double-encoding (%2520)
    // targetUrl comes in already decoded by shelf from the query param
    final baseUri = Uri.parse(targetUrl);
    final decodedPath = Uri.decodeComponent(baseUri.path);
    
    // Construct final URL with single encoding
    final finalUrl = Uri.https('tokybook.com', decodedPath).toString();

    // Construct track source header with single encoding
    final String finalTrackSrc;
    if (trackSrc != null) {
      finalTrackSrc = Uri.https('tokybook.com', Uri.decodeComponent(trackSrc)).path;
    } else {
      finalTrackSrc = '';
    }

    final headers = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36',
      'Referer': 'https://tokybook.com/',
      'Origin': 'https://tokybook.com',
      'Accept': '*/*',
      ...?audiobookId != null ? {'x-audiobook-id': audiobookId} : null,
      ...?token != null ? {'x-stream-token': token} : null,
      'x-track-src': finalTrackSrc,
    };

    debugPrint('[TokyProxy] GET $finalUrl');

    try {
      final res = await http.get(Uri.parse(finalUrl), headers: headers);
      
      if (res.statusCode != 200) {
        debugPrint('[TokyProxy] Error ${res.statusCode} from Tokybook');
        return Response(res.statusCode, body: res.body);
      }

      if (targetUrl.endsWith('.m3u8')) {
        String body = res.body;
        final baseDir = targetUrl.substring(0, targetUrl.lastIndexOf('/') + 1);
        final baseSrcDir = trackSrc?.substring(0, trackSrc.lastIndexOf('/') + 1) ?? '';
        
        final lines = body.split('\n');
        final rewrittenLines = lines.map((line) {
          if (line.isEmpty || line.startsWith('#')) return line;
          
          final segmentUrl = line.startsWith('http') ? line : '$baseDir$line';
          final segmentSrc = line.startsWith('http') ? line : '$baseSrcDir$line';
          
          return getTokyProxyUrl(segmentUrl, audiobookId ?? '', token ?? '', segmentSrc);
        }).toList();
        
        return Response.ok(
          rewrittenLines.join('\n'),
          headers: {'Content-Type': 'application/x-mpegURL'},
        );
      }

      return Response.ok(res.bodyBytes, headers: {
        'Content-Type': res.headers['content-type'] ?? 'video/mp2t',
        'Access-Control-Allow-Origin': '*',
      });
    } catch (e) {
      debugPrint('[TokyProxy] Fatal Error: $e');
      return Response.internalServerError(body: e.toString());
    }
  }

  String getTokyProxyUrl(String url, String id, String token, String src) {
    return '$baseUrl/toky-proxy?url=${Uri.encodeComponent(url)}&id=$id&token=${Uri.encodeComponent(token)}&src=${Uri.encodeComponent(src)}';
  }

  Future<Response> _handleComicProxy(Request request) async {
    // Get the raw query string to avoid shelf splitting it at '&'
    final queryStr = request.requestedUri.query;
    final urlMatch = RegExp(r'url=(.*)').firstMatch(queryStr);
    
    if (urlMatch == null) return Response.notFound('Missing url');
    
    final targetUrl = Uri.decodeComponent(urlMatch.group(1)!);
    
    debugPrint('[ComicProxy] Fetching: $targetUrl');

    // Pick the Referer per source so each origin's hotlink check passes.
    String referer = 'https://rcostation.xyz/';
    try {
      final host = Uri.parse(targetUrl).host;
      if (host.contains('readcomicsonline.ru')) {
        referer = 'https://readcomicsonline.ru/';
      } else if (host.contains('readcomiconline.li')) {
        referer = 'https://readcomiconline.li/';
      }
    } catch (_) {}

    final headers = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36',
      'Referer': referer,
      'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9',
      'Accept-Encoding': 'gzip, deflate, br',
      'Connection': 'keep-alive',
      'Sec-Fetch-Dest': 'image',
      'Sec-Fetch-Mode': 'no-cors',
      'Sec-Fetch-Site': 'cross-site',
    };

    try {
      final res = await http.get(Uri.parse(targetUrl), headers: headers);
      
      if (res.statusCode != 200) {
        debugPrint('[ComicProxy] Error ${res.statusCode} from ${Uri.parse(targetUrl).host}');
        debugPrint('[ComicProxy] Response body: ${res.body.length > 200 ? res.body.substring(0, 200) : res.body}');
        return Response(res.statusCode, body: res.body);
      }

      return Response.ok(res.bodyBytes, headers: {
        'Content-Type': res.headers['content-type'] ?? 'image/jpeg',
        'Access-Control-Allow-Origin': '*',
        'Cache-Control': 'public, max-age=86400',
      });
    } catch (e) {
      debugPrint('[ComicProxy] Fatal Error: $e');
      return Response.internalServerError(body: e.toString());
    }
  }

  String getComicProxyUrl(String url) {
    // URL encode the entire URL to preserve special characters
    return '$baseUrl/comic-proxy?url=${Uri.encodeComponent(url)}';
  }

  /// Jellyfin streaming proxy — forwards requests with proper auth headers
  /// so that mpv / media_kit can play from servers that reject api_key query params.
  /// Also rewrites HLS m3u8 playlists so segment URLs go through the proxy too.
  Future<Response> _handleJellyfinStream(Request request) async {
    final params = request.url.queryParameters;
    final targetUrl = params['url'];
    final authHeader = params['auth'];

    if (targetUrl == null || authHeader == null) {
      return Response(400, body: 'Missing url or auth parameter');
    }

    final decodedUrl = Uri.decodeComponent(targetUrl);
    final targetUri = Uri.parse(decodedUrl);
    final serverBase = '${targetUri.scheme}://${targetUri.host}${targetUri.hasPort ? ':${targetUri.port}' : ''}';
    debugPrint('[JellyfinProxy] ${request.method} $decodedUrl');

    try {
      final client = http.Client();
      final req = http.Request(request.method, targetUri);

      // Set Jellyfin auth headers
      req.headers['X-Emby-Authorization'] = authHeader;
      req.headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36';
      req.headers['Accept'] = '*/*';
      req.headers['Connection'] = 'keep-alive';

      // Forward Range header for seeking support
      final range = request.headers['range'];
      if (range != null) {
        req.headers['Range'] = range;
        debugPrint('[JellyfinProxy] Range: $range');
      }

      final streamedResponse = await client.send(req);

      if (streamedResponse.statusCode >= 400) {
        debugPrint('[JellyfinProxy] Upstream error: ${streamedResponse.statusCode}');
      }

      final contentType = streamedResponse.headers['content-type'] ?? '';

      // HLS playlist? Rewrite segment/sub-playlist URLs to go through proxy
      if (contentType.contains('mpegurl') ||
          contentType.contains('x-mpegurl') ||
          decodedUrl.contains('.m3u8')) {
        final body = await streamedResponse.stream.bytesToString();
        final basePath = decodedUrl.substring(0, decodedUrl.lastIndexOf('/') + 1);

        final rewrittenLines = body.split('\n').map((line) {
          final trimmed = line.trim();
          if (trimmed.isEmpty || trimmed.startsWith('#')) {
            // Rewrite URI= attributes inside #EXT-X-MAP or #EXT-X-MEDIA
            if (trimmed.contains('URI="')) {
              return trimmed.replaceAllMapped(
                RegExp(r'URI="([^"]+)"'),
                (m) {
                  final uri = m.group(1)!;
                  final fullUri = uri.startsWith('http') ? uri
                      : uri.startsWith('/') ? '$serverBase$uri'
                      : '$basePath$uri';
                  return 'URI="${getJellyfinProxyUrl(fullUri, authHeader)}"';
                },
              );
            }
            return line;
          }
          // Non-comment, non-empty line = segment or sub-playlist URL
          final fullUrl = trimmed.startsWith('http') ? trimmed
              : trimmed.startsWith('/') ? '$serverBase$trimmed'
              : '$basePath$trimmed';
          return getJellyfinProxyUrl(fullUrl, authHeader);
        }).toList();

        return Response.ok(
          rewrittenLines.join('\n'),
          headers: {
            'Content-Type': 'application/vnd.apple.mpegurl',
            'Access-Control-Allow-Origin': '*',
          },
        );
      }

      final responseHeaders = <String, String>{
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
        'Access-Control-Allow-Headers': '*',
        'Accept-Ranges': 'bytes',
        'Connection': 'keep-alive',
      };

      // Forward critical headers for playback
      final fwd = ['content-type', 'content-length', 'content-range',
                    'accept-ranges', 'content-disposition', 'etag',
                    'last-modified', 'x-emby-content-duration'];
      for (final h in fwd) {
        final v = streamedResponse.headers[h];
        if (v != null) responseHeaders[h] = v;
      }

      return Response(
        streamedResponse.statusCode,
        body: streamedResponse.stream,
        headers: responseHeaders,
      );
    } catch (e) {
      debugPrint('[JellyfinProxy] Fatal Error: $e');
      return Response.internalServerError(body: 'Jellyfin proxy error: $e');
    }
  }

  /// Returns a local proxy URL for a Jellyfin stream.
  String getJellyfinProxyUrl(String targetUrl, String authHeaderValue) {
    return '$baseUrl/jellyfin-stream'
        '?url=${Uri.encodeComponent(targetUrl)}'
        '&auth=${Uri.encodeComponent(authHeaderValue)}';
  }

  Future<Response> _handleProxyRequest(Request request) async {
    final params = request.url.queryParameters;
    final targetUrl = params['url'];
    if (targetUrl == null) return Response.notFound('Missing url parameter');

    if (_rustProxyPort > 0) {
      return _forwardProxyToRust(request, params);
    }

    final decodedUrl = Uri.decodeComponent(targetUrl);
    Map<String, String> customHeaders = {};
    if (params['headers'] != null) {
      try {
        customHeaders = Map<String, String>.from(json.decode(params['headers']!));
      } catch (e) {
        // Ignore invalid JSON headers
      }
    }

    try {
      final proxyHeaders = <String, String>{
        'User-Agent': customHeaders['User-Agent'] ?? 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Referer': customHeaders['Referer'] ?? 'https://www.youtube.com/',
        if (customHeaders.containsKey('Origin')) 'Origin': customHeaders['Origin']!,
        'Accept': '*/*',
        'Accept-Language': 'en-US,en;q=0.9',
        'Accept-Encoding': 'identity',
        'Connection': 'keep-alive',
      };

      final range = request.headers['range'];
      if (range != null) {
        proxyHeaders['Range'] = range;
        debugPrint('[LocalProxy] Range: $range');
      }

      final client = http.Client();
      final req = http.Request(request.method, Uri.parse(decodedUrl));
      req.headers.addAll(proxyHeaders);
      
      final streamedResponse = await client.send(req);

      final responseHeaders = <String, String>{
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS, POST',
        'Access-Control-Allow-Headers': '*',
        'Accept-Ranges': 'bytes',
        'Connection': 'keep-alive',
        'Content-Type': streamedResponse.headers['content-type'] ?? 'audio/mpeg',
      };

      // Forward these critical headers for seeking
      if (streamedResponse.headers.containsKey('content-length')) {
        responseHeaders['Content-Length'] = streamedResponse.headers['content-length']!;
      }
      if (streamedResponse.headers.containsKey('content-range')) {
        responseHeaders['Content-Range'] = streamedResponse.headers['content-range']!;
      }
      if (streamedResponse.headers.containsKey('accept-ranges')) {
        responseHeaders['Accept-Ranges'] = streamedResponse.headers['accept-ranges']!;
      }

      return Response(streamedResponse.statusCode, body: streamedResponse.stream, headers: responseHeaders);
    } catch (e) {
      return Response.internalServerError(body: 'Proxy error: $e');
    }
  }

  Future<Response> _forwardProxyToRust(
    Request request,
    Map<String, String> params,
  ) async {
    try {
      final rustUri = Uri(
        scheme: 'http',
        host: '127.0.0.1',
        port: _rustProxyPort,
        path: '/proxy',
        queryParameters: params,
      );
      final req = http.Request(request.method, rustUri);
      final range = request.headers['range'];
      if (range != null) req.headers['range'] = range;

      final streamedResponse = await _httpClient.send(req);
      final responseHeaders = <String, String>{
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS, POST',
        'Access-Control-Allow-Headers': '*',
        'Accept-Ranges': 'bytes',
        'Connection': 'keep-alive',
      };

      for (final key in [
        'content-type',
        'content-length',
        'content-range',
        'accept-ranges',
        'content-disposition',
        'etag',
        'last-modified',
      ]) {
        final v = streamedResponse.headers[key];
        if (v != null) responseHeaders[key] = v;
      }
      if (!responseHeaders.containsKey('content-type')) {
        responseHeaders['content-type'] = 'audio/mpeg';
      }

      return Response(
        streamedResponse.statusCode,
        body: streamedResponse.stream,
        headers: responseHeaders,
      );
    } catch (e) {
      return Response.internalServerError(body: 'Rust proxy error: $e');
    }
  }

  /// HLS-aware proxy: fetches with custom headers, rewrites m3u8 playlists
  /// so that segment/sub-playlist URLs also go through the proxy.
  Future<Response> _handleHlsProxy(Request request) async {
    final params = request.url.queryParameters;
    final targetUrl = params['url'];
    final headersJson = params['headers'];
    final stripMode = params['strip']; // e.g. "png"

    if (targetUrl == null) {
      return Response(400, body: 'Missing url parameter');
    }

    final decodedUrl = Uri.decodeComponent(targetUrl);
    final targetUri = Uri.parse(decodedUrl);
    final serverBase = '${targetUri.scheme}://${targetUri.host}${targetUri.hasPort ? ':${targetUri.port}' : ''}';

    Map<String, String> customHeaders = {};
    if (headersJson != null) {
      try {
        customHeaders = Map<String, String>.from(json.decode(headersJson));
      } catch (_) {}
    }

    final proxyHeaders = <String, String>{
      'User-Agent': customHeaders['User-Agent'] ?? 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36',
      if (customHeaders.containsKey('Referer')) 'Referer': customHeaders['Referer']!,
      if (customHeaders.containsKey('Origin')) 'Origin': customHeaders['Origin']!,
      'Accept': '*/*',
      'Accept-Encoding': 'identity',
      'Connection': 'keep-alive',
    };

    final range = request.headers['range'];
    if (range != null) proxyHeaders['Range'] = range;

    try {
      final req = http.Request(request.method, targetUri);
      req.headers.addAll(proxyHeaders);
      final streamedResponse = await _httpClient.send(req);

      if (streamedResponse.statusCode >= 400) {
        debugPrint('[HlsProxy] Upstream ${streamedResponse.statusCode} for $decodedUrl');
      }

      final contentType = streamedResponse.headers['content-type'] ?? '';

      // HLS playlist? Rewrite URLs so sub-playlists & segments also go through proxy
      if (contentType.contains('mpegurl') ||
          contentType.contains('x-mpegurl') ||
          decodedUrl.contains('.m3u8')) {
        final body = await streamedResponse.stream.bytesToString();
        final basePath = decodedUrl.substring(0, decodedUrl.lastIndexOf('/') + 1);

        final rewrittenLines = body.split('\n').map((line) {
          final trimmed = line.trim();
          if (trimmed.isEmpty || trimmed.startsWith('#')) {
            // Rewrite URI= attributes inside EXT tags
            if (trimmed.contains('URI="')) {
              return trimmed.replaceAllMapped(
                RegExp(r'URI="([^"]+)"'),
                (m) {
                  final uri = m.group(1)!;
                  final fullUri = uri.startsWith('http') ? uri
                      : uri.startsWith('/') ? '$serverBase$uri'
                      : '$basePath$uri';
                  return 'URI="${getHlsProxyUrl(fullUri, customHeaders, stripMode: stripMode)}"';
                },
              );
            }
            return line;
          }
          // Non-comment line = segment or sub-playlist URL
          final fullUrl = trimmed.startsWith('http') ? trimmed
              : trimmed.startsWith('/') ? '$serverBase$trimmed'
              : '$basePath$trimmed';
          return getHlsProxyUrl(fullUrl, customHeaders, stripMode: stripMode);
        }).toList();

        return Response.ok(
          rewrittenLines.join('\n'),
          headers: {
            'Content-Type': 'application/vnd.apple.mpegurl',
            'Access-Control-Allow-Origin': '*',
          },
        );
      }

      // Non-HLS (segments, mp4, etc.) — stream through
      final responseHeaders = <String, String>{
        'Access-Control-Allow-Origin': '*',
        'Accept-Ranges': 'bytes',
        'Connection': 'keep-alive',
      };
      for (final h in ['content-type', 'content-length', 'content-range', 'accept-ranges']) {
        final v = streamedResponse.headers[h];
        if (v != null) responseHeaders[h] = v;
      }

      // Optional segment transform: strip PNG wrapper used by some hosts
      // (e.g. RG Shows / 1shows.app) which serve TS segments as fake PNG
      // files on TikTok CDN. The real MPEG-TS data starts at the first
      // 0x47 sync byte after the PNG IEND chunk.
      if (stripMode == 'png') {
        final raw = await _collectBytes(streamedResponse.stream);
        final stripped = _stripPngWrapper(raw);
        responseHeaders['content-type'] = 'video/mp2t';
        responseHeaders['content-length'] = stripped.length.toString();
        responseHeaders.remove('content-range');
        return Response(streamedResponse.statusCode,
            body: stripped, headers: responseHeaders);
      }

      return Response(streamedResponse.statusCode, body: streamedResponse.stream, headers: responseHeaders);
    } catch (e) {
      debugPrint('[HlsProxy] Error: $e');
      return Response.internalServerError(body: 'HLS proxy error: $e');
    }
  }

  /// Returns a local proxy URL for an HLS stream with custom headers.
  String getHlsProxyUrl(String targetUrl, Map<String, String> headers,
      {String? stripMode}) {
    final base = '$baseUrl/hls-proxy'
        '?url=${Uri.encodeComponent(targetUrl)}'
        '&headers=${Uri.encodeComponent(json.encode(headers))}';
    return stripMode == null ? base : '$base&strip=$stripMode';
  }

  /// Read the entire body of a streamed response into memory.
  static Future<List<int>> _collectBytes(Stream<List<int>> stream) async {
    final out = <int>[];
    await for (final chunk in stream) {
      out.addAll(chunk);
    }
    return out;
  }

  /// Strip a fake PNG wrapper that hides MPEG-TS segment data.
  /// Returns the original bytes unchanged if no PNG signature is present.
  static List<int> _stripPngWrapper(List<int> raw) {
    if (raw.length < 16) return raw;
    // PNG signature: 89 50 4E 47 0D 0A 1A 0A
    if (raw[0] != 0x89 ||
        raw[1] != 0x50 ||
        raw[2] != 0x4E ||
        raw[3] != 0x47) {
      return raw;
    }
    // Find IEND chunk type (49 45 4E 44) — its CRC trails for 4 bytes.
    var idx = -1;
    for (var i = 8; i < raw.length - 8; i++) {
      if (raw[i] == 0x49 &&
          raw[i + 1] == 0x45 &&
          raw[i + 2] == 0x4E &&
          raw[i + 3] == 0x44) {
        idx = i + 8; // skip "IEND" + 4-byte CRC
        break;
      }
    }
    if (idx < 0) return raw;
    // Find the first MPEG-TS sync byte (0x47) at a packet boundary.
    // Validate by checking the next byte 188 bytes later is also 0x47.
    for (var p = idx; p < raw.length - 188; p++) {
      if (raw[p] == 0x47 && raw[p + 188] == 0x47) {
        return raw.sublist(p);
      }
    }
    // Fallback: first 0x47 we find.
    for (var p = idx; p < raw.length; p++) {
      if (raw[p] == 0x47) return raw.sublist(p);
    }
    return raw;
  }

  Future<void> stop() async {
    if (_rustProxyPort > 0 && ForjaEngine.isReady) {
      ForjaRust.instance.proxyStop();
      _rustProxyPort = 0;
    }
    await _server?.close(force: true);
    _server = null;
    _port = 0;
  }
}
