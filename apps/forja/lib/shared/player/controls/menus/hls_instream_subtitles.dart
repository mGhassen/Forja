import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/player/resolvers/track_auto_select.dart';
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
    final type = hlsMediaAttr(line, 'TYPE');
    if (type == null || type.toUpperCase() != 'SUBTITLES') continue;
    final rawUri = hlsMediaAttr(line, 'URI')?.trim() ?? '';
    if (rawUri.isEmpty) continue;
    final name = (hlsMediaAttr(line, 'NAME') ?? '').trim();
    final lang = (hlsMediaAttr(line, 'LANGUAGE') ?? '').trim();
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

/// `KEY="value"` or bare `KEY=value` on an HLS tag line, case-insensitive.
String? hlsMediaAttr(String line, String key) {
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

/// Progressive containers we never GET for a playlist probe (too large).
const _kProgressiveMediaSuffixes = <String>[
  '.mp4',
  '.mkv',
  '.webm',
  '.avi',
  '.mov',
  '.m4v',
  '.m4a',
  '.mp3',
  '.aac',
  '.flac',
  '.ogg',
  '.opus',
  '.ts',
  '.m4s',
  '.jpg',
  '.jpeg',
  '.png',
  '.gif',
  '.webp',
];

bool _hasProgressiveMediaSuffix(String path) {
  for (final ext in _kProgressiveMediaSuffixes) {
    if (path.endsWith(ext)) return true;
  }
  return false;
}

bool _isTorrentStreamPath(String path) =>
    path.contains('/torrents/') && path.contains('/stream/');

/// True when [url] is worth a bounded playlist probe for in-stream subs.
///
/// Any http(s) play URL that is not a clear progressive file / torrent piece.
/// The fetch itself decides via `#EXTM3U` — no more URL-shape allowlist gaps.
bool mayBeHlsPlaylistUrl(String url) {
  final raw = url.trim();
  if (raw.isEmpty) return false;
  final uri = Uri.tryParse(raw);
  if (uri == null) return false;
  if (_localPlaylist(uri)) return true;
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') return false;
  final path = uri.path.toLowerCase();
  if (_isTorrentStreamPath(path)) return false;
  if (_hasProgressiveMediaSuffix(path)) return false;
  return true;
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
    // Proxy URL itself still carries `#FORJA-SUB` when the query is opaque.
    return raw;
  }
  if (mayBeHlsPlaylistUrl(raw)) return raw;
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

Map<String, String>? _nonEmptyHeaders(Map<String, String>? headers) {
  if (headers == null || headers.isEmpty) return null;
  return headers;
}

/// Headers for reading an HLS master for subtitle renditions.
///
/// Playback (mpv) headers win over catalog [streamHeaders] so Referer/Cookie
/// from the open path are not replaced by weaker widget headers.
Map<String, String>? hlsInStreamRequestHeaders({
  Map<String, String>? streamHeaders,
  Map<String, String>? playbackHeaders,
}) {
  final stream = _nonEmptyHeaders(streamHeaders);
  final play = _nonEmptyHeaders(playbackHeaders);
  if (play == null) return stream;
  if (stream == null) return play;
  return {...stream, ...play};
}

String _cacheKey(String url, Map<String, String>? headers) {
  if (headers == null || headers.isEmpty) return url;
  final keys = headers.keys.toList()..sort();
  return '$url|${keys.map((k) => '$k=${headers[k]}').join('\n')}';
}

/// Matching subtitle already listed on the HLS master, or null.
///
/// Progressive / non-probeable play URLs return null without a fetch so
/// scraped auto-pick can run.
Future<HlsInStreamSubtitle?> preferredHlsInStreamSubtitle({
  required String? playUrl,
  Map<String, String>? headers,
  required String preferredLang,
}) async {
  final raw = playUrl?.trim() ?? '';
  if (raw.isEmpty || preferredLang.isEmpty || preferredLang == 'None') {
    return null;
  }
  if (hlsInStreamFetchTarget(raw) == null) return null;
  final subs = await loadHlsInStreamSubtitles(raw, headers: headers);
  return pickPlaylistSubtitleRendition(
    preferredLang: preferredLang,
    renditions: subs,
    languageOf: (s) => s.language,
    titleOf: (s) => s.name,
  );
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
    _hlsInStreamInflight.remove(key);
    return list;
  });
  _hlsInStreamInflight[key] = future;
  return future;
}

/// One fetched HLS master: the URI we read and its text.
class HlsPlaylistText {
  const HlsPlaylistText({required this.uri, required this.body});

  final Uri uri;
  final String body;
}

final Map<String, HlsPlaylistText?> _hlsPlaylistTextCache = {};
final Map<String, Future<HlsPlaylistText?>> _hlsPlaylistTextInflight = {};

/// Playlists to read for [playUrl]: the local proxy copy when the play URL is
/// local (it carries `#FORJA-SUB` lines), else the unwrapped upstream master.
List<Uri> hlsPlaylistReadTargets(String playUrl) {
  final play = Uri.tryParse(playUrl.trim());
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

  if (_localPlaylist(play)) {
    addTarget(play.toString());
    // Upstream master still has TYPE=SUBTITLES when the proxy strip is stale.
    final inner = play.queryParameters['url']?.trim();
    if (inner != null && inner.isNotEmpty) addTarget(inner);
  } else {
    addTarget(hlsInStreamFetchTarget(playUrl));
  }
  return targets;
}

/// Headers for a playlist read: the proxy query's own headers, then [headers].
Map<String, String> hlsPlaylistRequestHeaders(
  String playUrl,
  Map<String, String>? headers,
) {
  final play = Uri.tryParse(playUrl.trim());
  final merged = <String, String>{
    if (play != null) ..._headersFromProxyQuery(play),
    ...?headers,
  };
  return _requestHeaders(merged.isEmpty ? null : merged);
}

/// Read the HLS master behind [playUrl] once; later calls reuse the text.
/// Null when the URL is not a playlist we can read or the fetch failed.
///
/// Failed probes are cached for the process so MP4 / dead URLs are not
/// re-fetched every time the subtitle menu opens.
Future<HlsPlaylistText?> loadHlsPlaylistText(
  String? playUrl, {
  Map<String, String>? headers,
}) async {
  final raw = playUrl?.trim() ?? '';
  if (raw.isEmpty) return null;
  final key = _cacheKey(raw, headers);
  if (_hlsPlaylistTextCache.containsKey(key)) {
    return _hlsPlaylistTextCache[key];
  }
  final pending = _hlsPlaylistTextInflight[key];
  if (pending != null) return pending;

  final future = _fetchHlsPlaylistText(raw, headers).then((text) {
    _hlsPlaylistTextCache[key] = text;
    _hlsPlaylistTextInflight.remove(key);
    return text;
  });
  _hlsPlaylistTextInflight[key] = future;
  return future;
}

/// First 256 KiB is enough for any master; avoids downloading progressive files
/// when a CDN ignores URL heuristics.
const _kPlaylistProbeBytes = 256 * 1024;

Future<HlsPlaylistText?> _fetchHlsPlaylistText(
  String playUrl,
  Map<String, String>? headers,
) async {
  final targets = hlsPlaylistReadTargets(playUrl);
  if (targets.isEmpty) return null;
  final reqHeaders = {
    ...hlsPlaylistRequestHeaders(playUrl, headers),
    'Range': 'bytes=0-${_kPlaylistProbeBytes - 1}',
  };
  for (final uri in targets) {
    try {
      final res = await http
          .get(uri, headers: reqHeaders)
          .timeout(const Duration(seconds: 4));
      if (res.statusCode != 200 && res.statusCode != 206) continue;
      final body = res.body;
      if (!body.contains('#EXTM3U') && !body.contains('#FORJA-SUB:')) continue;
      return HlsPlaylistText(uri: uri, body: body);
    } catch (e) {
      debugPrint('[Player] HLS playlist read failed: $e');
    }
  }
  return null;
}

Future<List<HlsInStreamSubtitle>> _loadHlsInStreamSubtitles(
  String playUrl,
  Map<String, String>? headers,
) async {
  final text = await loadHlsPlaylistText(playUrl, headers: headers);
  if (text == null) return const [];

  final out = <HlsInStreamSubtitle>[];
  final seen = <String>{};
  for (final sub in parseHlsInStreamSubtitles(text.body, playlistUri: text.uri)) {
    if (!seen.add(sub.uri)) continue;
    out.add(sub);
  }

  // Cache after a real playlist read (including 0 renditions). Probe misses
  // stay uncached here so a later open can retry with better headers.
  _hlsInStreamCache[_cacheKey(playUrl, headers)] = out;

  debugPrint(
    '[Subtitles] in-stream renditions=${out.length} '
    'from ${text.uri}'
    '${out.isEmpty ? '' : ' ${out.map((s) => s.language).join(",")}'}',
  );
  return out;
}
