import 'dart:convert';
import 'dart:io';

/// Source label for subtitle tracks found inside the HLS stream itself.
const kInStreamSubtitleSourceName = 'In-stream';

/// One `#EXT-X-MEDIA:TYPE=SUBTITLES` rendition on a master playlist.
class HlsSubtitleRendition {
  const HlsSubtitleRendition({
    required this.name,
    required this.language,
    required this.uri,
  });

  final String name;
  final String language;
  final Uri uri;
}

/// One WebVTT segment from a subtitle media playlist.
class HlsSubtitleSegmentPart {
  const HlsSubtitleSegmentPart({
    required this.duration,
    required this.body,
  });

  final double duration;
  final String body;
}

class _HlsSubtitleUri {
  const _HlsSubtitleUri({required this.duration, required this.uri});

  final double duration;
  final Uri uri;
}

/// Subtitle renditions that belong to [variantUri]. When the variant names a
/// `SUBTITLES` group, only that group is kept. Otherwise every subtitle
/// rendition on the playlist is kept.
List<HlsSubtitleRendition> hlsSubtitleRenditions({
  required String playlist,
  required Uri playlistUri,
  Uri? variantUri,
}) {
  final lines = playlist.split('\n');
  String? groupId;
  if (variantUri != null) {
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (!line.startsWith('#EXT-X-STREAM-INF')) continue;
      String? next;
      for (var j = i + 1; j < lines.length; j++) {
        final sub = lines[j].trim();
        if (sub.isEmpty || sub.startsWith('#')) continue;
        next = sub;
        break;
      }
      if (next == null) continue;
      if (playlistUri.resolve(next).toString() != variantUri.toString()) {
        continue;
      }
      groupId = _attr(line, 'SUBTITLES');
      break;
    }
  }

  final out = <HlsSubtitleRendition>[];
  final seen = <String>{};
  for (final raw in lines) {
    final line = raw.trim();
    if (!line.toUpperCase().startsWith('#EXT-X-MEDIA:')) continue;
    final type = _attr(line, 'TYPE');
    if (type == null || type.toUpperCase() != 'SUBTITLES') continue;
    final group = _attr(line, 'GROUP-ID');
    if (groupId != null && group != groupId) continue;
    final rawUri = _attr(line, 'URI')?.trim() ?? '';
    if (rawUri.isEmpty) continue;
    final uri = playlistUri.resolve(rawUri);
    if (!seen.add(uri.toString())) continue;
    final name = (_attr(line, 'NAME') ?? '').trim();
    final lang = (_attr(line, 'LANGUAGE') ?? '').trim();
    out.add(
      HlsSubtitleRendition(
        name: name.isNotEmpty ? name : (lang.isNotEmpty ? lang : 'Subtitle'),
        language: lang.isNotEmpty ? lang : 'und',
        uri: uri,
      ),
    );
  }
  return out;
}

/// Segment URIs on a subtitle media playlist, in order.
List<_HlsSubtitleUri> _subtitleSegmentUris(String playlist, Uri playlistUri) {
  final lines = playlist.split('\n');
  final out = <_HlsSubtitleUri>[];
  var duration = 0.0;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.startsWith('#EXTINF:')) {
      final raw = line.substring('#EXTINF:'.length).split(',').first.trim();
      duration = double.tryParse(raw) ?? 0.0;
      continue;
    }
    if (line.isEmpty || line.startsWith('#')) continue;
    out.add(
      _HlsSubtitleUri(duration: duration, uri: playlistUri.resolve(line)),
    );
    duration = 0.0;
  }
  return out;
}

/// Join WebVTT segments into one file aligned to the start of the video.
///
/// Segments that reset their cue clock are shifted by the playlist duration
/// already written. `X-TIMESTAMP-MAP` cues are shifted onto that same clock.
/// [delaySeconds] moves every cue later (negative: earlier); cues that end
/// before zero are dropped.
String mergeWebVttParts(
  List<HlsSubtitleSegmentPart> parts, {
  double delaySeconds = 0,
}) {
  final cues = <({double start, double end, String text})>[];
  var cursor = 0.0;
  double? base;
  for (final part in parts) {
    final parsed = _parseCues(part.body);
    if (parsed.isEmpty) {
      cursor += part.duration;
      continue;
    }
    final map = _timestampMapOffset(part.body);
    final origin = base ??= map ?? 0;
    var shift = 0.0;
    if (map != null) {
      shift = -origin;
    } else if (parsed.first.$1 + 0.05 < cursor) {
      shift = cursor;
    }
    for (final cue in parsed) {
      cues.add((
        start: cue.$1 + shift,
        end: cue.$2 + shift,
        text: cue.$3,
      ));
    }
    final end = cues.isEmpty ? cursor : cues.last.end;
    final stepped = cursor + part.duration;
    cursor = end > stepped ? end : stepped;
  }
  final buf = StringBuffer('WEBVTT\n\n');
  for (final cue in cues) {
    final end = cue.end + delaySeconds;
    if (end <= 0) continue;
    buf
      ..write(_formatClock(cue.start + delaySeconds))
      ..write(' --> ')
      ..write(_formatClock(end))
      ..write('\n')
      ..write(cue.text)
      ..write('\n\n');
  }
  return buf.toString();
}

bool _looksLikeTextSub(String body) {
  final text = body.trimLeft();
  if (text.isEmpty) return false;
  final lower = text.toLowerCase();
  if (lower.startsWith('<!doctype') || lower.startsWith('<html')) return false;
  if (text.startsWith('WEBVTT')) return true;
  return text.contains('-->');
}

/// Download each in-stream subtitle rendition next to [videoPath].
///
/// A failed rendition is skipped. The video save still finishes.
Future<void> saveHlsInStreamSubtitles({
  required String videoPath,
  required String playlist,
  required Uri playlistUri,
  Uri? variantUri,
  required Future<String> Function(Uri uri) fetchText,
  bool Function()? isPausedOrCanceled,
}) async {
  final renditions = hlsSubtitleRenditions(
    playlist: playlist,
    playlistUri: playlistUri,
    variantUri: variantUri,
  );
  if (renditions.isEmpty) return;
  final dir = Directory('$videoPath.subs');
  if (!await dir.exists()) await dir.create(recursive: true);
  final tracks = <Map<String, String>>[];
  final used = <String>{};
  for (final rendition in renditions) {
    if (isPausedOrCanceled?.call() == true) return;
    try {
      final body = await fetchText(rendition.uri);
      final vtt = await _renditionToVtt(
        body: body,
        playlistUri: rendition.uri,
        fetchText: fetchText,
        isPausedOrCanceled: isPausedOrCanceled,
      );
      if (vtt == null || !vtt.contains('-->')) continue;
      final fileName = _uniqueFileName(used, rendition);
      await File('${dir.path}/$fileName').writeAsString(vtt);
      tracks.add({
        'name': rendition.name,
        'language': rendition.language,
        'file': fileName,
      });
    } catch (_) {}
  }
  if (tracks.isEmpty) return;
  await _appendSidecarTracks(videoPath, tracks);
}

/// Save the subtitle rows a stream row carried (provider sidecar links or
/// inline text) next to [videoPath], after the video itself is complete.
///
/// Rows come from `catalogStreamExternalSubtitles`: `url` or `content`,
/// `language`, `name`, optional `sourceName`. A row that fails to fetch or is
/// not a text subtitle is skipped. The video save still finishes.
Future<void> saveStreamSubtitleRows({
  required String videoPath,
  required List<Map<String, String>>? rows,
  Map<String, String>? headers,
  Future<String> Function(Uri uri)? fetchText,
  bool Function()? isPausedOrCanceled,
}) async {
  if (rows == null || rows.isEmpty) return;
  final fetch = fetchText ?? (uri) => fetchSubtitleText(uri, headers);
  final dir = Directory('$videoPath.subs');
  if (!await dir.exists()) await dir.create(recursive: true);
  final used = await _sidecarFileNames(videoPath);
  final tracks = <Map<String, String>>[];
  for (final row in rows) {
    if (isPausedOrCanceled?.call() == true) return;
    final url = row['url']?.trim() ?? '';
    final inline = (row['content'] ?? row['text'])?.trim() ?? '';
    final language = row['language']?.trim().isNotEmpty == true
        ? row['language']!.trim()
        : (row['lang']?.trim().isNotEmpty == true ? row['lang']!.trim() : 'und');
    final name = row['name']?.trim().isNotEmpty == true
        ? row['name']!.trim()
        : language;
    final sourceName = row['sourceName']?.trim() ?? '';
    try {
      String body;
      if (inline.isNotEmpty) {
        body = inline;
      } else if (url.isNotEmpty) {
        body = await fetch(Uri.parse(url));
      } else {
        continue;
      }
      if (!_looksLikeTextSub(body)) continue;
      final ext = body.trimLeft().startsWith('WEBVTT') ? 'vtt' : 'srt';
      final fileName = _uniqueFileName(
        used,
        HlsSubtitleRendition(name: name, language: language, uri: Uri()),
        extension: ext,
      );
      await File('${dir.path}/$fileName').writeAsString(body);
      tracks.add({
        'name': name,
        'language': language,
        'file': fileName,
        if (sourceName.isNotEmpty) 'sourceName': sourceName,
      });
    } catch (_) {}
  }
  if (tracks.isEmpty) return;
  await _appendSidecarTracks(videoPath, tracks);
}

/// GET [uri] as text with the stream's playback [headers].
Future<String> fetchSubtitleText(Uri uri, Map<String, String>? headers) async {
  final client = HttpClient();
  client.connectionTimeout = const Duration(seconds: 15);
  try {
    final req = await client.getUrl(uri);
    headers?.forEach((k, v) => req.headers.set(k, v));
    final res = await req.close();
    if (res.statusCode != 200) {
      throw Exception('Failed to fetch subtitle: HTTP ${res.statusCode}');
    }
    final bytes = await res.fold<List<int>>([], (p, e) => p..addAll(e));
    return utf8.decode(bytes, allowMalformed: true);
  } finally {
    client.close();
  }
}

/// Track entries already in the sidecar index. Empty when there is none.
Future<List<Map<String, String>>> _existingSidecarTracks(
  String videoPath,
) async {
  final index = File('$videoPath.subs.json');
  if (!await index.exists()) return [];
  try {
    final decoded = jsonDecode(await index.readAsString());
    if (decoded is! Map) return [];
    final raw = decoded['tracks'];
    if (raw is! List) return [];
    final out = <Map<String, String>>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final row = <String, String>{};
      item.forEach((k, v) {
        if (v == null) return;
        row[k.toString()] = v.toString();
      });
      if (row['file']?.isNotEmpty == true) out.add(row);
    }
    return out;
  } catch (_) {
    return [];
  }
}

Future<Set<String>> _sidecarFileNames(String videoPath) async {
  final existing = await _existingSidecarTracks(videoPath);
  return {for (final t in existing) t['file']!};
}

/// Append [tracks] to the sidecar index, keeping entries already there.
Future<void> _appendSidecarTracks(
  String videoPath,
  List<Map<String, String>> tracks,
) async {
  final existing = await _existingSidecarTracks(videoPath);
  final files = {for (final t in existing) t['file']};
  final merged = [
    ...existing,
    for (final t in tracks)
      if (!files.contains(t['file'])) t,
  ];
  await File('$videoPath.subs.json').writeAsString(
    jsonEncode({'tracks': merged}),
  );
}

/// Rows for the subtitle menu. Empty when this save has no sidecar.
Future<List<Map<String, dynamic>>> offlineSavedSubtitleRows(
  String videoPath,
) async {
  final index = File('$videoPath.subs.json');
  if (!await index.exists()) return const [];
  try {
    final decoded = jsonDecode(await index.readAsString());
    if (decoded is! Map) return const [];
    final raw = decoded['tracks'];
    if (raw is! List) return const [];
    final dir = Directory('$videoPath.subs');
    final out = <Map<String, dynamic>>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final file = item['file']?.toString().trim() ?? '';
      if (file.isEmpty) continue;
      final path = '${dir.path}/$file';
      if (!await File(path).exists()) continue;
      final name = item['name']?.toString().trim() ?? '';
      final language = item['language']?.toString().trim() ?? '';
      final sourceName = item['sourceName']?.toString().trim() ?? '';
      out.add({
        'url': Uri.file(path).toString(),
        'language': language.isNotEmpty ? language : 'und',
        'name': name.isNotEmpty ? name : language,
        'display': name.isNotEmpty ? name : language,
        'sourceName': sourceName.isNotEmpty
            ? sourceName
            : kInStreamSubtitleSourceName,
      });
    }
    return out;
  } catch (_) {
    return const [];
  }
}

Future<void> deleteHlsSubtitleSidecar(String videoPath) async {
  final index = File('$videoPath.subs.json');
  if (await index.exists()) {
    try {
      await index.delete();
    } catch (_) {}
  }
  final dir = Directory('$videoPath.subs');
  if (await dir.exists()) {
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  }
}

Future<String?> _renditionToVtt({
  required String body,
  required Uri playlistUri,
  required Future<String> Function(Uri uri) fetchText,
  bool Function()? isPausedOrCanceled,
}) async {
  final trimmed = body.trimLeft();
  if (trimmed.startsWith('#EXTM3U')) {
    final segments = _subtitleSegmentUris(body, playlistUri);
    if (segments.isEmpty) return null;
    final parts = <HlsSubtitleSegmentPart>[];
    for (final segment in segments) {
      if (isPausedOrCanceled?.call() == true) return null;
      final seg = await fetchText(segment.uri);
      if (!_looksLikeTextSub(seg)) return null;
      parts.add(
        HlsSubtitleSegmentPart(duration: segment.duration, body: seg),
      );
    }
    return mergeWebVttParts(parts);
  }
  if (!_looksLikeTextSub(body)) return null;
  if (trimmed.startsWith('WEBVTT')) return body;
  return mergeWebVttParts([
    HlsSubtitleSegmentPart(duration: 0, body: body),
  ]);
}

String _uniqueFileName(
  Set<String> used,
  HlsSubtitleRendition rendition, {
  String extension = 'vtt',
}) {
  final raw = rendition.language.trim().isNotEmpty
      ? rendition.language.trim()
      : rendition.name.trim();
  var slug = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  slug = slug.replaceAll(RegExp(r'^-+|-+$'), '');
  if (slug.isEmpty) slug = 'sub';
  var name = '$slug.$extension';
  var n = 2;
  while (!used.add(name)) {
    name = '$slug-$n.$extension';
    n++;
  }
  return name;
}

String? _attr(String line, String key) {
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

/// Cue triples: start seconds, end seconds, text.
List<(double, double, String)> _parseCues(String body) {
  final out = <(double, double, String)>[];
  final blocks = body.replaceAll('\r\n', '\n').split(RegExp(r'\n{2,}'));
  final timing = RegExp(
    r'((?:\d{1,2}:)?\d{2}:\d{2}[.,]\d{3})\s+-->\s+((?:\d{1,2}:)?\d{2}:\d{2}[.,]\d{3})',
  );
  for (final block in blocks) {
    final lines = block.split('\n');
    var timeLine = -1;
    RegExpMatch? match;
    for (var i = 0; i < lines.length; i++) {
      match = timing.firstMatch(lines[i].trim());
      if (match != null) {
        timeLine = i;
        break;
      }
    }
    if (match == null || timeLine < 0) continue;
    final text = lines.skip(timeLine + 1).join('\n').trim();
    if (text.isEmpty) continue;
    final start = _parseClock(match.group(1)!);
    final end = _parseClock(match.group(2)!);
    if (start == null || end == null) continue;
    final map = _timestampMapOffset(body);
    out.add((start + (map ?? 0), end + (map ?? 0), text));
  }
  return out;
}

/// Seconds to add to cue LOCAL times so they sit on the MPEG-TS clock.
double? _timestampMapOffset(String body) {
  final match = RegExp(
    r'X-TIMESTAMP-MAP=[^\n]*MPEGTS:(\d+)',
    caseSensitive: false,
  ).firstMatch(body);
  if (match == null) return null;
  final mpeg = int.tryParse(match.group(1) ?? '');
  if (mpeg == null) return null;
  final localMatch = RegExp(
    r'LOCAL:((?:\d{1,2}:)?\d{2}:\d{2}[.,]\d{3})',
    caseSensitive: false,
  ).firstMatch(match.group(0)!);
  final local = localMatch == null ? 0.0 : (_parseClock(localMatch.group(1)!) ?? 0);
  return mpeg / 90000.0 - local;
}

double? _parseClock(String raw) {
  final text = raw.trim().replaceAll(',', '.');
  final parts = text.split(':');
  if (parts.length == 3) {
    final h = double.tryParse(parts[0]);
    final m = double.tryParse(parts[1]);
    final s = double.tryParse(parts[2]);
    if (h == null || m == null || s == null) return null;
    return h * 3600 + m * 60 + s;
  }
  if (parts.length == 2) {
    final m = double.tryParse(parts[0]);
    final s = double.tryParse(parts[1]);
    if (m == null || s == null) return null;
    return m * 60 + s;
  }
  return double.tryParse(text);
}

String _formatClock(double seconds) {
  if (seconds.isNaN || seconds < 0) seconds = 0;
  final ms = (seconds * 1000).round();
  final h = ms ~/ 3600000;
  final m = (ms % 3600000) ~/ 60000;
  final s = (ms % 60000) ~/ 1000;
  final milli = ms % 1000;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(h)}:${two(m)}:${two(s)}.${milli.toString().padLeft(3, '0')}';
}
