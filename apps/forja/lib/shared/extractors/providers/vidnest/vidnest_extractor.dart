// VidNest extractor - mirrors vidnest.fun player (new.vidnest.fun API).
//
// Pipeline:
//   1. GET https://new.vidnest.fun/{server}/movie|tv/{tmdb}[/{s}/{e}]
//   2. Decrypt custom-alphabet base64 when `encrypted: true`
//   3. Parse every server that responds (bounded parallel) - show all streams
//
// MovieBox CDN (`*.hakunaymatata.com`) returns HTTP 429 if Referer is set -
// playback headers are User-Agent only for those URLs.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/extractors/core/bounded_parallel.dart';
import 'package:forja/shared/playback/provider_runtime_config.dart';
import 'package:http/http.dart' as http;
import 'package:rust/rust.dart';

class VidnestExtractor {
  VidnestExtractor({this.onLog});

  final void Function(String)? onLog;

  static String get _apiBase =>
      ProviderRuntimeConfig.instance.api('vidnestApi') ??
      'https://new.vidnest.fun';
  static String get _embedOrigin =>
      ProviderRuntimeConfig.instance.api('vidnestEmbed') ??
      'https://vidnest.fun';
  static const _fetchTimeout = Duration(seconds: 15);
  static const _defaultTimeout = Duration(seconds: 45);
  static const _maxInFlight = 3;

  /// Custom alphabet from player chunk `decryptCipherResponse`.
  static const _cipherAlphabet =
      'RB0fpH8ZEyVLkv7c2i6MAJ5u3IKFDxlS1NTsnGaqmXYdUrtzjwObCgQP94hoeW+/=';

  static const userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';

  /// Every listed API server - collect all responsive streams (no first-hit stop).
  static const _servers = <_VidnestServer>[
    _VidnestServer('gama', 'Gama', 'moviebox/movie', 'moviebox/tv'),
    _VidnestServer('hexa', 'Hexa', 'vidlink/movie', 'vidlink/tv'),
    _VidnestServer('lamda', 'Lamda', 'allmovies/movie', 'allmovies/tv'),
    _VidnestServer('delta', 'Delta', 'allmovies/movie', 'allmovies/tv'),
    _VidnestServer('beta', 'Beta', 'videasy/movie', 'videasy/tv'),
    _VidnestServer('prime', 'Prime', 'hollymoviehd/movie', 'hollymoviehd/tv'),
    _VidnestServer('sigma', 'Sigma', 'hollymoviehd', 'hollymoviehd'),
    _VidnestServer('alfa', 'Alfa', 'moviesapi/movie', 'moviesapi/tv'),
    _VidnestServer('catflix', 'Catflix', 'movies5f/movie', 'movies5f/tv'),
    _VidnestServer('ophim', 'Ophim', 'klikxxi/movie', 'klikxxi/tv'),
  ];

  /// Mirror labels used in stream titles (`Gama · …`) - ownership filter.
  static List<String> get serverDisplayNames =>
      [for (final s in _servers) s.displayName];

  static var _generation = 0;
  static http.Client? _sharedClient;

  static void cancelPending() {
    _generation++;
    _sharedClient?.close();
    _sharedClient = null;
  }

  void _log(String msg) {
    final line = '[vidnest] $msg';
    onLog?.call(line);
    debugPrint(line);
  }

  Future<ExtractedMedia?> extract({
    required String tmdbId,
    required bool isMovie,
    int? season,
    int? episode,
    bool Function()? isCancelled,
    Duration timeout = _defaultTimeout,
  }) async {
    final id = tmdbId.trim();
    if (id.isEmpty) return null;
    final gen = _generation;
    bool cancelled() => gen != _generation || (isCancelled?.call() ?? false);

    final deadline = DateTime.now().add(timeout);
    final client = _sharedClient ??= http.Client();

    final batches =
        await mapBoundedParallel<_VidnestServer, List<StreamSource>>(
          items: _servers,
          concurrency: _maxInFlight,
          isCancelled: cancelled,
          work: (server, _) async {
            if (cancelled()) return null;
            if (DateTime.now().isAfter(deadline)) {
              _log('timed out before ${server.id}');
              return null;
            }
            try {
              final path = server.pathFor(
                isMovie: isMovie,
                tmdbId: id,
                season: season,
                episode: episode,
              );
              final uri = Uri.parse('$_apiBase/$path');
              _log('GET $uri');
              final res = await client
                  .get(
                    uri,
                    headers: {
                      'User-Agent': userAgent,
                      'Accept': 'application/json, text/plain, */*',
                      'Origin': _embedOrigin,
                      'Referer': '$_embedOrigin/',
                    },
                  )
                  .timeout(_fetchTimeout);
              if (cancelled()) return null;
              if (res.statusCode < 200 || res.statusCode >= 300) {
                _log('${server.id} HTTP ${res.statusCode}');
                return null;
              }
              final decoded = _decodeBody(res.body);
              if (decoded == null) {
                _log('${server.id} decrypt/parse failed');
                return null;
              }
              final sources = _parseSources(decoded, server);
              if (sources.isEmpty) {
                _log('${server.id} no streams');
                return null;
              }
              _log('${server.id} → ${sources.length} source(s)');
              return sources;
            } on TimeoutException {
              _log('${server.id} fetch timeout');
              return null;
            } catch (e) {
              _log('${server.id} error: $e');
              return null;
            }
          },
        );

    if (cancelled()) return null;
    final allSources = <StreamSource>[for (final batch in batches) ...batch];
    if (allSources.isEmpty) return null;
    final playable = dedupeStreamSources(allSources)
        .map(
          (s) => StreamSource(
            url: s.url,
            title: s.title,
            type: s.type,
            headers: s.headers,
            providerId: 'vidnest',
            catalogUrl: s.catalogUrl ?? s.url,
          ),
        )
        .toList();
    _log('${batches.length} server(s) → ${playable.length} source(s)');
    return ExtractedMedia(
      url: playable.first.url,
      headers: Map<String, String>.from(
        playable.first.headers ?? _uaOnlyHeaders(),
      ),
      sources: playable,
      provider: 'vidnest',
    );
  }

  Map<String, dynamic>? _decodeBody(String body) {
    try {
      final raw = jsonDecode(body);
      if (raw is! Map) return null;
      final map = Map<String, dynamic>.from(raw);
      if (map['encrypted'] == true) {
        final data = map['data']?.toString();
        if (data == null || data.isEmpty) return null;
        final plain = _decryptCipher(data);
        final parsed = jsonDecode(plain);
        if (parsed is Map) return Map<String, dynamic>.from(parsed);
        return null;
      }
      return map;
    } catch (_) {
      return null;
    }
  }

  /// Custom base64 (not AES) - same alphabet as the embed player.
  @visibleForTesting
  static String decryptCipherForTest(String data) => _decryptCipher(data);

  static String _decryptCipher(String data) {
    final alphabet = _cipherAlphabet;
    final index = <String, int>{
      for (var i = 0; i < alphabet.length; i++) alphabet[i]: i,
    };
    final out = <int>[];
    for (var t = 0; t < data.length; t += 4) {
      final end = t + 4 > data.length ? data.length : t + 4;
      var chunk = data.substring(t, end);
      while (chunk.length < 4) {
        chunk += '=';
      }
      final l = List<int>.generate(4, (e) => index[chunk[e]] ?? 64);
      out.add((l[0] << 2) | (l[1] >> 4));
      if (l[2] != 64) {
        out.add(((l[1] & 15) << 4) | (l[2] >> 2));
      }
      if (l[3] != 64) {
        out.add(((l[2] & 3) << 6) | l[3]);
      }
    }
    return utf8.decode(out, allowMalformed: true);
  }

  List<StreamSource> _parseSources(
    Map<String, dynamic> json,
    _VidnestServer server,
  ) {
    final out = <StreamSource>[];

    // Gama / MovieBox: { url: [{ link, resolution, type, lang }] }
    final urlField = json['url'];
    if (urlField is List) {
      final rows = urlField
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((e) => (e['link'] ?? e['url'])?.toString().isNotEmpty == true)
          .toList();
      rows.sort((a, b) {
        final ra =
            int.tryParse(
              '${a['resolution']}'.replaceAll(RegExp(r'[^0-9]'), ''),
            ) ??
            0;
        final rb =
            int.tryParse(
              '${b['resolution']}'.replaceAll(RegExp(r'[^0-9]'), ''),
            ) ??
            0;
        return rb.compareTo(ra);
      });
      for (final row in rows) {
        final link = (row['link'] ?? row['url']).toString();
        final res = row['resolution']?.toString() ?? 'auto';
        final lang = row['lang']?.toString() ?? '';
        final type = _typeFromUrl(link, row['type']?.toString());
        out.add(
          StreamSource(
            url: link,
            title: [
              server.displayName,
              if (lang.isNotEmpty) lang,
              res,
            ].join(' · '),
            type: type,
            headers: _headersForUrl(link, null),
          ),
        );
      }
    }

    // Beta: { url: string, headers?: {} }
    final singleUrl = json['url'];
    if (singleUrl is String && singleUrl.isNotEmpty) {
      final hdrs = _mapHeaders(json['headers']);
      out.add(
        StreamSource(
          url: singleUrl,
          title: server.displayName,
          type: _typeFromUrl(singleUrl, null),
          headers: _headersForUrl(singleUrl, hdrs),
        ),
      );
    }

    // Lamda / Delta / Alfa / Catflix-ish: { streams: [{ url, type, language, headers }] }
    final streams = json['streams'];
    if (streams is List) {
      for (final raw in streams.whereType<Map>()) {
        final row = Map<String, dynamic>.from(raw);
        final u = row['url']?.toString() ?? '';
        if (u.isEmpty) continue;
        final lang =
            row['language']?.toString() ?? row['lang']?.toString() ?? '';
        final quality =
            row['quality']?.toString() ?? row['type']?.toString() ?? 'auto';
        out.add(
          StreamSource(
            url: u,
            title: [
              server.displayName,
              if (lang.isNotEmpty) lang,
              quality,
            ].join(' · '),
            type: _typeFromUrl(u, row['type']?.toString()),
            headers: _headersForUrl(u, _mapHeaders(row['headers'])),
          ),
        );
      }
    }

    // Hexa / VidLink: { data: { stream: { playlist } }, headers? }
    final data = json['data'];
    if (data is Map) {
      final stream = data['stream'];
      if (stream is Map) {
        final playlist = stream['playlist']?.toString() ?? '';
        if (playlist.isNotEmpty) {
          final hdrs = _mapHeaders(json['headers']);
          out.add(
            StreamSource(
              url: playlist,
              title: '${server.displayName} · auto',
              type: _typeFromUrl(playlist, null),
              headers: _headersForUrl(playlist, hdrs),
            ),
          );
        }
      }
    }

    // Generic sources: [{ url, quality }]
    final sources = json['sources'];
    if (sources is List) {
      for (final raw in sources.whereType<Map>()) {
        final row = Map<String, dynamic>.from(raw);
        final u = row['url']?.toString() ?? '';
        if (u.isEmpty) continue;
        final q = row['quality']?.toString() ?? 'auto';
        out.add(
          StreamSource(
            url: u,
            title: '${server.displayName} · $q',
            type: _typeFromUrl(u, row['type']?.toString()),
            headers: _headersForUrl(u, _mapHeaders(row['headers'])),
          ),
        );
      }
    }

    return out;
  }

  static Map<String, String>? _mapHeaders(dynamic raw) {
    if (raw is! Map) return null;
    final out = <String, String>{};
    for (final e in raw.entries) {
      final k = e.key.toString().trim();
      final v = e.value?.toString().trim() ?? '';
      if (k.isEmpty || v.isEmpty) continue;
      out[k] = v;
    }
    return out.isEmpty ? null : out;
  }

  static Map<String, String> _uaOnlyHeaders() => {'User-Agent': userAgent};

  /// MovieBox CDN rejects Referer; other CDNs may need upstream headers.
  static Map<String, String> _headersForUrl(
    String url,
    Map<String, String>? upstream,
  ) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    if (host.contains('hakunaymatata.com')) {
      return _uaOnlyHeaders();
    }
    final out = <String, String>{..._uaOnlyHeaders(), ...?upstream};
    // Normalize common keys.
    final ref = out.remove('referer') ?? out['Referer'];
    if (ref != null && ref.isNotEmpty) out['Referer'] = ref;
    final origin = out.remove('origin') ?? out['Origin'];
    if (origin != null && origin.isNotEmpty) out['Origin'] = origin;
    return out;
  }

  static String _typeFromUrl(String url, String? hinted) {
    final h = (hinted ?? '').toLowerCase();
    if (h.contains('hls') || h == 'application/x-mpegurl') return 'hls';
    if (h.contains('dash') || h == 'mpd') return 'dash';
    final u = url.toLowerCase();
    if (u.contains('.m3u8')) return 'hls';
    if (u.contains('.mpd')) return 'dash';
    if (u.contains('.mkv')) return 'mkv';
    return 'mp4';
  }
}

class _VidnestServer {
  const _VidnestServer(this.id, this.displayName, this.moviePath, this.tvPath);

  final String id;
  final String displayName;
  final String moviePath;
  final String tvPath;

  String pathFor({
    required bool isMovie,
    required String tmdbId,
    int? season,
    int? episode,
  }) {
    if (isMovie) return '$moviePath/$tmdbId';
    final s = season ?? 1;
    final e = episode ?? 1;
    // Sigma uses /hollymoviehd/tv/{id}/{s}/{e} (base path has no /tv suffix).
    if (tvPath == 'hollymoviehd') {
      return '$tvPath/tv/$tmdbId/$s/$e';
    }
    return '$tvPath/$tmdbId/$s/$e';
  }
}
