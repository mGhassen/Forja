import 'dart:async';
import 'dart:convert';
import 'dart:io' show gzip, zlib;

import 'package:flutter/foundation.dart';
import 'package:rust/rust.dart';

import 'miruro_pipe_session.dart';
import 'anime_stream_nicknames.dart';

/// Direct extractor for Miruro's secure pipe API (official domain mirrors).
class MiruroExtractor {
  static const String _pipeObfKeyHex = '71951034f8fbcf53d89db52ceb3dc22c';
  static const List<String> _protocolVersions = ['0.2.0', '0.1.0'];

  String? _activeBase;
  String get _baseUrl => _activeBase ?? MiruroDomains.primary;

  /// Pipe key → upstream (debug logs only).
  static const Map<String, String> upstreamSources = {
    'kiwi': 'AnimePahe',
    'ally': 'AllManga',
    'bonk': 'AnimeDao',
    'bee': 'AniKoto',
    'moo': 'AnimeGG',
    'hop': 'Miruro',
    'arc': 'Miruro internal',
    'zoro': 'HiAnime',
    'jet': 'Miruro internal',
    'animedunya': 'AnimeDunya',
    'bun': 'Miruro',
    'kuz': 'Miruro',
    'telli': 'Miruro',
  };

  static const List<String> knownProviders = [
    'zoro',
    'kiwi',
    'bee',
    'hop',
    'bonk',
    'ally',
    'moo',
    'animedunya',
    'arc',
    'jet',
    'bun',
    'kuz',
    'telli',
  ];

  static String upstreamLabel(String pipeKey) =>
      upstreamSources[pipeKey.toLowerCase()] ?? pipeKey;

  static final Uint8List _obfKey = Uint8List.fromList(
    RegExp(r'.{2}')
        .allMatches(_pipeObfKeyHex)
        .map((m) => int.parse(m.group(0)!, radix: 16))
        .toList(),
  );

  final Map<int, Future<Map<String, dynamic>?>> _epsCache = {};

  Future<Map<String, dynamic>?> fetchEpisodes(int anilistId) {
    return _epsCache.putIfAbsent(
      anilistId,
      () => _apiGet('episodes', query: {'anilistId': '$anilistId'})
          .then((v) => (v as Map?)?.cast<String, dynamic>()),
    );
  }

  Future<MiruroResult?> extractWithProvider({
    required int anilistId,
    required int episodeNumber,
    required String category,
    required String provider,
  }) async {
    try {
      final epData = await fetchEpisodes(anilistId);
      final providersMap =
          (epData?['providers'] as Map?)?.cast<String, dynamic>() ?? {};
      final prov = (providersMap[provider] as Map?)?.cast<String, dynamic>();
      if (prov == null) return null;

      final eps = (prov['episodes'] as Map?)?.cast<String, dynamic>() ?? {};
      final list = eps[category] as List?;
      if (list == null || list.isEmpty) return null;

      Map<String, dynamic>? hit;
      for (final raw in list) {
        if (raw is! Map) continue;
        final n = raw['number'];
        if (n is num && n.toInt() == episodeNumber) {
          hit = raw.cast<String, dynamic>();
          break;
        }
      }
      if (hit == null) return null;

      final epId = hit['id']?.toString();
      if (epId == null || epId.isEmpty) return null;

      final src = await _apiGet('sources', query: {
        'episodeId': epId,
        'provider': provider,
        'category': category,
        'anilistId': '$anilistId',
      });
      if (src == null) return null;

      final streams = (src['streams'] as List?) ?? const [];
      Map<String, dynamic>? hls;
      for (final s in streams) {
        if (s is! Map) continue;
        final type = (s['type'] ?? '').toString();
        if (type == 'hls' || type.isEmpty) {
          hls = s.cast<String, dynamic>();
          break;
        }
      }
      if (hls == null) return null;

      final url = (hls['url'] ?? '').toString();
      if (url.isEmpty) return null;

      final referer = (hls['referer'] as String?)?.trim().isNotEmpty == true
          ? hls['referer'] as String
          : '$_baseUrl/';
      final origin = Uri.tryParse(referer)?.origin ?? _baseUrl;

      final tracks = <MiruroTrack>[];
      final subs = (src['subtitles'] as List?) ?? const [];
      for (final t in subs) {
        if (t is! Map) continue;
        final fileUrl = (t['file'] ?? t['url'] ?? '').toString();
        if (fileUrl.isEmpty) continue;
        tracks.add(MiruroTrack(
          url: fileUrl,
          label: (t['label'] as String?) ?? 'Unknown',
          language: (t['language'] as String?) ?? '',
          isDefault: t['default'] == true,
        ));
      }

      if (kDebugMode) {
        debugPrint(
            '[Miruro] OK ${AnimeStreamNicknames.forMiruroPipe(provider)} '
            '($provider) ep=$episodeNumber cat=$category url=$url '
            'tracks=${tracks.length}');
      }
      return MiruroResult(
        url: url,
        referer: referer,
        origin: origin,
        tracks: tracks,
        provider: provider,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Miruro] $provider failed: $e');
      }
      return null;
    }
  }

  Map<String, String> _pipeHeadersFor(String base) => {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
        'Referer': '$base/',
        'Origin': base,
        'Accept': 'application/json, text/plain, */*',
        'Accept-Language': 'en-US,en;q=0.9',
        'Sec-Fetch-Dest': 'empty',
        'Sec-Fetch-Mode': 'cors',
        'Sec-Fetch-Site': 'same-origin',
      };

  Iterable<String> get _domainOrder sync* {
    if (_activeBase != null) yield _activeBase!;
    for (final d in MiruroDomains.official) {
      if (d != _activeBase) yield d;
    }
  }

  Future<dynamic> _apiGet(String path, {Map<String, String>? query}) async {
    for (final version in _protocolVersions) {
      final result = await _apiGetVersion(path, query: query, version: version);
      if (result != null) return result;
    }
    return null;
  }

  Future<dynamic> _apiGetVersion(
    String path, {
    Map<String, String>? query,
    required String version,
  }) async {
    final payload = {
      'path': path,
      'method': 'GET',
      'query': query ?? const <String, String>{},
      'body': null,
      'version': version,
    };
    final encoded = miruroEncodePipeRequest(payload);

    for (final base in _domainOrder) {
      final uri = '$base/api/secure/pipe?e=$encoded';

      final direct = await animeHttp(
        'GET',
        uri,
        headers: _pipeHeadersFor(base),
        maxRetries: 0,
      );
      if (direct.status == 200) {
        final decoded =
            _decodePipeBody(direct.body, direct.headers['x-obfuscated']);
        if (decoded != null) {
          _activeBase = base;
          return decoded;
        }
      }

      if (direct.status != 403 && kDebugMode) {
        debugPrint('[Miruro] $path HTTP ${direct.status} on $base (v$version)');
      }

      if (direct.status == 403 || direct.body.contains('cloudflare')) {
        final viaBrowser = await MiruroPipeSession.instance.get(uri);
        if (viaBrowser != null && viaBrowser.status == 200) {
          final decoded = _decodePipeBody(viaBrowser.body, viaBrowser.xObf);
          if (decoded != null) {
            _activeBase = base;
            if (kDebugMode) {
              debugPrint('[Miruro] $path OK via WebView on $base (v$version)');
            }
            return decoded;
          }
        }
        if (kDebugMode && viaBrowser != null) {
          debugPrint(
              '[Miruro] $path WebView HTTP ${viaBrowser.status} on $base');
        }
        continue;
      }
    }

    return null;
  }

  dynamic _decodePipeBody(String body, String? xObfHeader) {
    if (body.isEmpty) return null;
    final xObf = xObfHeader?.trim();
    if (xObf == null || xObf.isEmpty) {
      return jsonDecode(body);
    }
    return jsonDecode(_deobfuscate(body, xObf));
  }

  String _deobfuscate(String body, String level) {
    var b64 = body.replaceAll('-', '+').replaceAll('_', '/');
    final pad = b64.length % 4;
    if (pad != 0) b64 += '=' * (4 - pad);
    var data = base64Decode(b64);

    if (level == '2') {
      final out = Uint8List(data.length);
      for (var i = 0; i < data.length; i++) {
        out[i] = data[i] ^ _obfKey[i % _obfKey.length];
      }
      data = out;
    }
    return utf8.decode(_decompress(data));
  }

  Uint8List _decompress(Uint8List data) {
    try {
      if (data.length >= 2 && data[0] == 0x1f && data[1] == 0x8b) {
        return Uint8List.fromList(gzip.decode(data));
      }
    } catch (_) {}
    try {
      return Uint8List.fromList(zlib.decode(data));
    } catch (_) {}
    try {
      return Uint8List.fromList(zlib.decode([0x78, 0x01, ...data]));
    } catch (_) {}
    return data;
  }
}

class MiruroResult {
  final String url;
  final String referer;
  final String origin;
  final List<MiruroTrack> tracks;
  final String provider;

  const MiruroResult({
    required this.url,
    required this.referer,
    required this.origin,
    required this.tracks,
    required this.provider,
  });
}

class MiruroTrack {
  final String url;
  final String label;
  final String language;
  final bool isDefault;
  const MiruroTrack({
    required this.url,
    required this.label,
    this.language = '',
    this.isDefault = false,
  });
}
