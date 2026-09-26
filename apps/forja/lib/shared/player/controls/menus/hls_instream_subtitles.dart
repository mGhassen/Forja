import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// One HLS subtitle rendition kept off the demuxed track list until a
/// subtitle command. Listed from the playlist so the menu does not wait
/// for that command.
class HlsInStreamSubtitle {
  const HlsInStreamSubtitle({
    required this.language,
    required this.name,
    required this.uri,
  });

  final String language;
  final String name;
  final String uri;
}

final Map<String, List<HlsInStreamSubtitle>> _hlsInStreamCache = {};
final Map<String, Future<List<HlsInStreamSubtitle>>> _hlsInStreamInflight = {};

/// `#FORJA-SUB:` lines the local HLS proxy appends after it drops
/// `TYPE=SUBTITLES` groups (lavf would otherwise open every rendition).
List<HlsInStreamSubtitle> parseForjaHlsSubtitles(
  String playlist, {
  required Uri playlistUri,
}) {
  final out = <HlsInStreamSubtitle>[];
  for (final raw in playlist.split('\n')) {
    final line = raw.trim();
    if (!line.startsWith('#FORJA-SUB:')) continue;
    final query = line.substring('#FORJA-SUB:'.length);
    final fields = Uri.splitQueryString(query);
    final rawUri = fields['uri']?.trim() ?? '';
    if (rawUri.isEmpty) continue;
    final resolved = playlistUri.resolve(rawUri);
    final name = (fields['name'] ?? '').trim();
    final lang = (fields['lang'] ?? '').trim();
    out.add(
      HlsInStreamSubtitle(
        language: lang.isNotEmpty ? lang : (name.isNotEmpty ? name : 'und'),
        name: name.isNotEmpty ? name : lang,
        uri: resolved.toString(),
      ),
    );
  }
  return out;
}

/// `TYPE=SUBTITLES` renditions on an HLS master, plus `#FORJA-SUB` comments.
List<HlsInStreamSubtitle> parseHlsInStreamSubtitles(
  String playlist, {
  required Uri playlistUri,
}) {
  final out = <HlsInStreamSubtitle>[];
  final seen = <String>{};
  void add(HlsInStreamSubtitle sub) {
    if (sub.uri.isEmpty || !seen.add(sub.uri)) return;
    out.add(sub);
  }

  for (final raw in playlist.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    if (!line.toUpperCase().startsWith('#EXT-X-MEDIA:')) continue;
    final type = _hlsAttr(line, 'TYPE');
    if (type == null || type.toUpperCase() != 'SUBTITLES') continue;
    final rawUri = _hlsAttr(line, 'URI')?.trim() ?? '';
    if (rawUri.isEmpty) continue;
    final name = (_hlsAttr(line, 'NAME') ?? '').trim();
    final lang = (_hlsAttr(line, 'LANGUAGE') ?? '').trim();
    add(
      HlsInStreamSubtitle(
        language: lang.isNotEmpty ? lang : (name.isNotEmpty ? name : 'und'),
        name: name.isNotEmpty ? name : lang,
        uri: playlistUri.resolve(rawUri).toString(),
      ),
    );
  }
  for (final sub in parseForjaHlsSubtitles(playlist, playlistUri: playlistUri)) {
    add(sub);
  }
  return out;
}

String? _hlsAttr(String line, String key) {
  final quoted = RegExp(
    '${RegExp.escape(key)}\\s*=\\s*"([^"]*)"',
    caseSensitive: false,
  ).firstMatch(line);
  if (quoted != null) return quoted.group(1);
  final bare = RegExp(
    '${RegExp.escape(key)}\\s*=\\s*([^,\\s]+)',
    caseSensitive: false,
  ).firstMatch(line);
  return bare?.group(1);
}

/// Rows the Exo subtitle menu can show beside online results.
List<Map<String, dynamic>> hlsInStreamSubtitleRows(
  List<HlsInStreamSubtitle> subs,
) {
  return [
    for (final s in subs)
      {
        'url': s.uri,
        'language': s.language,
        'lang': s.language,
        'display': s.name.isNotEmpty ? s.name : s.language,
        'sourceName': 'In-stream',
      },
  ];
}

bool isLocalHlsPlayUrl(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return false;
  return _localPlaylist(uri);
}

bool _localPlaylist(Uri uri) {
  final host = uri.host.toLowerCase();
  if (host != '127.0.0.1' && host != 'localhost' && host != '::1') {
    return false;
  }
  final path = uri.path;
  return path.contains('/hls-proxy') || path.contains('/ext/');
}

bool _isHlsPlaylistUri(Uri uri) {
  if (_localPlaylist(uri)) return true;
  final path = uri.path.toLowerCase();
  if (path.endsWith('.m3u8') || path.endsWith('.m3u')) return true;
  if (path.contains('/playlist/')) return true;
  final query = uri.query.toLowerCase();
  return query.contains('.m3u8') || query.contains('.m3u');
}

/// Playlist we can read for subtitle renditions. Unwraps `/hls-proxy?url=`.
String? hlsInStreamFetchTarget(String playUrl) {
  final raw = playUrl.trim();
  if (raw.isEmpty) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null) return null;
  if (uri.path.contains('/hls-proxy')) {
    final inner = uri.queryParameters['url']?.trim() ?? '';
    if (inner.isNotEmpty) return inner;
  }
  if (_isHlsPlaylistUri(uri)) return raw;
  return null;
}

Map<String, String> _headersFromProxyQuery(Uri uri) {
  if (!uri.path.contains('/hls-proxy')) return const {};
  final raw = uri.queryParameters['headers'];
  if (raw == null || raw.isEmpty) return const {};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return const {};
    return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
  } catch (_) {
    return const {};
  }
}

Map<String, String> _requestHeaders(Map<String, String>? headers) {
  final out = <String, String>{...?headers};
  final hasUa = out.keys.any((k) => k.toLowerCase() == 'user-agent');
  if (!hasUa) {
    out['User-Agent'] =
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';
  }
  out.putIfAbsent('Accept', () => '*/*');
  return out;
}

String _cacheKey(String url, Map<String, String>? headers) {
  if (headers == null || headers.isEmpty) return url;
  final keys = headers.keys.toList()..sort();
  return '$url|${keys.map((k) => '$k=${headers[k]}').join('\n')}';
}

/// Read in-stream subtitle renditions from the play URL's HLS master.
///
/// Direct `.m3u8` (Asian Drama and most VOD) never hits the local proxy, so
/// `#FORJA-SUB` comments are not there. mpv also omits `TYPE=SUBTITLES`
/// groups from `track-list` until a subtitle command — this fetch is what
/// puts them in the menu on first open.
Future<List<HlsInStreamSubtitle>> loadHlsInStreamSubtitles(
  String? playUrl, {
  Map<String, String>? headers,
}) async {
  final raw = playUrl?.trim() ?? '';
  if (raw.isEmpty) return const [];
  final key = _cacheKey(raw, headers);
  final cached = _hlsInStreamCache[key];
  if (cached != null) return cached;
  final pending = _hlsInStreamInflight[key];
  if (pending != null) return pending;

  final future = _loadHlsInStreamSubtitles(raw, headers).then((list) {
    if (list.isNotEmpty) _hlsInStreamCache[key] = list;
    _hlsInStreamInflight.remove(key);
    return list;
  });
  _hlsInStreamInflight[key] = future;
  return future;
}

Future<List<HlsInStreamSubtitle>> _loadHlsInStreamSubtitles(
  String playUrl,
  Map<String, String>? headers,
) async {
  final play = Uri.tryParse(playUrl);
  if (play == null) return const [];

  final targets = <Uri>[];
  void addTarget(String? url) {
    final value = url?.trim() ?? '';
    if (value.isEmpty) return;
    final uri = Uri.tryParse(value);
    if (uri == null) return;
    if (targets.any((t) => t.toString() == uri.toString())) return;
    targets.add(uri);
  }

  // Upstream master still has TYPE=SUBTITLES after the proxy drops them.
  addTarget(hlsInStreamFetchTarget(playUrl));
  if (_localPlaylist(play)) addTarget(play.toString());

  if (targets.isEmpty) return const [];

  final merged = <String, String>{
    ..._headersFromProxyQuery(play),
    ...?headers,
  };
  final reqHeaders = _requestHeaders(merged.isEmpty ? null : merged);
  final out = <HlsInStreamSubtitle>[];
  final seen = <String>{};

  for (final uri in targets) {
    try {
      final res = await http
          .get(uri, headers: reqHeaders)
          .timeout(const Duration(seconds: 4));
      if (res.statusCode != 200) continue;
      final body = res.body;
      if (!body.contains('#EXTM3U') && !body.contains('#FORJA-SUB:')) continue;
      for (final sub in parseHlsInStreamSubtitles(body, playlistUri: uri)) {
        if (!seen.add(sub.uri)) continue;
        out.add(sub);
      }
    } catch (e) {
      debugPrint('[Subtitles] in-stream playlist read failed: $e');
    }
  }

  if (out.isNotEmpty) {
    debugPrint(
      '[Subtitles] in-stream renditions=${out.length} '
      '${out.map((s) => s.language).join(",")}',
    );
  }
  return out;
}
