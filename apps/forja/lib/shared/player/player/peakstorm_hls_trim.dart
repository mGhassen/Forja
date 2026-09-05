import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/playback/playback_stream_guards.dart';
import 'package:forja/shared/player/player/player_peakstorm_resume_diag.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Trim a peakstorm fMP4 HLS playlist to start near [target] without mpv `start`.
///
/// Returns a `file://` playlist mpv can open — segment URIs stay absolute CDN URLs.
Future<String?> buildPeakstormTrimmedPlaylistFile({
  required String catalogUrl,
  required Duration target,
  required Map<String, String> headers,
  String? variantUrl,
}) async {
  if (!peakstormFmp4HlsAvoidHardSeek(catalogUrl) || target.inSeconds <= 0) {
    return null;
  }
  // dmcdn fMP4: local file:// trim opens fail demux ("Failed to recognize file
  // format") even with absolute MAP — use mpv `start` on the CDN URL instead.
  if (isDailymotionDmcdnHlsUrl(catalogUrl)) {
    return null;
  }
  try {
    final masterUrl = preferVideasyHlsMasterUrl(catalogUrl.trim());
    final masterBody = await _fetchPlaylistText(masterUrl, headers);
    if (masterBody == null || masterBody.isEmpty) return null;

    final mediaUrl = variantUrl ?? _pickVariantUrl(masterBody, masterUrl);
    if (mediaUrl == null) return null;

    final mediaBody = mediaUrl == masterUrl
        ? masterBody
        : await _fetchPlaylistText(mediaUrl, headers);
    if (mediaBody == null || mediaBody.isEmpty) return null;

    final trimmed = trimMediaPlaylistFromTarget(
      body: mediaBody,
      baseUrl: mediaUrl,
      target: target,
    );
    if (trimmed == null) return null;

    final dir = await getTemporaryDirectory();
    final file = File(
      p.join(
        dir.path,
        'peakstorm_trim_${target.inMilliseconds}_${mediaUrl.hashCode}.m3u8',
      ),
    );
    await file.writeAsString(trimmed, flush: true);
    logPeakstormResume(
      'trim playlist',
      target: target,
      detail: 'seg=${_segmentIndexFromTrimmed(trimmed)} file=${file.path}',
    );
    return file.uri.toString();
  } catch (e, st) {
    debugPrint('[PeakstormResume] trim failed: $e\n$st');
    return null;
  }
}

int? _segmentIndexFromTrimmed(String body) {
  final m = RegExp(r'#EXT-X-MEDIA-SEQUENCE:(\d+)').firstMatch(body);
  return m != null ? int.tryParse(m.group(1)!) : null;
}

Future<String?> _fetchPlaylistText(
  String url,
  Map<String, String> headers,
) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  final res = await http
      .get(uri, headers: headers)
      .timeout(const Duration(seconds: 20));
  if (res.statusCode < 200 || res.statusCode >= 300) {
    logPeakstormResume(
      'trim fetch fail',
      detail: 'status=${res.statusCode} url=$url',
    );
    return null;
  }
  return utf8.decode(res.bodyBytes);
}

String? _pickVariantUrl(String masterBody, String masterUrl) {
  if (!masterBody.contains('#EXT-X-STREAM-INF')) {
    return masterBody.contains('#EXTINF') ? masterUrl : null;
  }
  final base = _baseUrl(masterUrl);
  String? bestUrl;
  var bestBw = -1;
  final lines = masterBody.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (!line.startsWith('#EXT-X-STREAM-INF')) continue;
    final bwMatch = RegExp(r'BANDWIDTH=(\d+)').firstMatch(line);
    final bw = bwMatch != null ? int.tryParse(bwMatch.group(1)!) ?? 0 : 0;
    final next = i + 1 < lines.length ? lines[i + 1].trim() : '';
    if (next.isEmpty || next.startsWith('#')) continue;
    final resolved = _resolveUrl(next, base);
    if (bw >= bestBw) {
      bestBw = bw;
      bestUrl = resolved;
    }
  }
  return bestUrl;
}

/// Visible for tests.
String? trimMediaPlaylistFromTarget({
  required String body,
  required String baseUrl,
  required Duration target,
}) {
  if (!body.contains('#EXTINF')) return null;
  final base = _baseUrl(baseUrl);
  final targetSec = target.inMilliseconds / 1000.0;
  final headerLines = <String>[];
  final pairs = <({double duration, String uri})>[];
  var mediaSequence = 0;
  var pendingDuration = 0.0;
  var inSegments = false;

  for (final raw in body.split('\n')) {
    final line = raw.trimRight();
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    if (trimmed.startsWith('#EXT-X-MEDIA-SEQUENCE:')) {
      mediaSequence =
          int.tryParse(trimmed.split(':').last.trim()) ?? mediaSequence;
      continue;
    }
    if (trimmed.startsWith('#EXTINF:')) {
      inSegments = true;
      final numPart = trimmed.substring('#EXTINF:'.length).split(',').first;
      pendingDuration = double.tryParse(numPart) ?? 0.0;
      continue;
    }
    if (trimmed.startsWith('#')) {
      if (!inSegments &&
          !trimmed.startsWith('#EXT-X-ENDLIST') &&
          !trimmed.startsWith('#EXT-X-MEDIA-SEQUENCE')) {
        // file:// opens need absolute MAP — relative init.mp4 breaks dmcdn fMP4.
        headerLines.add(_absolutizeMapLine(line, base));
      }
      continue;
    }
    if (pendingDuration <= 0) continue;
    pairs.add((duration: pendingDuration, uri: _resolveUrl(trimmed, base)));
    pendingDuration = 0;
  }
  if (pairs.isEmpty) return null;

  var elapsed = 0.0;
  var startIndex = 0;
  for (var i = 0; i < pairs.length; i++) {
    if (elapsed + pairs[i].duration >= targetSec) {
      startIndex = i > 0 ? i - 1 : 0;
      break;
    }
    elapsed += pairs[i].duration;
    if (i == pairs.length - 1) startIndex = i;
  }

  final out = <String>[...headerLines];
  out.add('#EXT-X-MEDIA-SEQUENCE:${mediaSequence + startIndex}');
  for (var i = startIndex; i < pairs.length; i++) {
    final seg = pairs[i];
    out.add('#EXTINF:${seg.duration.toStringAsFixed(3)},');
    out.add(seg.uri);
  }
  if (body.contains('#EXT-X-ENDLIST')) out.add('#EXT-X-ENDLIST');
  return out.join('\n');
}

String _baseUrl(String url) {
  final noFrag = url.split('#').first;
  final slash = noFrag.lastIndexOf('/');
  if (slash <= 0) return noFrag;
  return noFrag.substring(0, slash + 1);
}

/// Rewrite relative `#EXT-X-MAP:URI="…"` to an absolute CDN URL.
String _absolutizeMapLine(String line, String base) {
  final trimmed = line.trim();
  if (!trimmed.toUpperCase().startsWith('#EXT-X-MAP:')) return line;
  final dq = RegExp(r'URI="([^"]+)"', caseSensitive: false).firstMatch(trimmed);
  final sq = dq == null
      ? RegExp(r"URI='([^']+)'", caseSensitive: false).firstMatch(trimmed)
      : null;
  final match = dq ?? sq;
  if (match == null) return line;
  final rel = match.group(1) ?? '';
  if (rel.isEmpty) return line;
  final abs = _resolveUrl(rel, base);
  if (abs == rel) return line;
  return trimmed.replaceFirst(match.group(0)!, 'URI="$abs"');
}

String _resolveUrl(String relative, String base) {
  final t = relative.trim();
  if (t.startsWith('http://') || t.startsWith('https://')) return t;
  if (t.startsWith('//')) {
    final scheme = base.startsWith('https://') ? 'https:' : 'http:';
    return '$scheme$t';
  }
  if (t.startsWith('/')) {
    final uri = Uri.tryParse(base);
    if (uri == null) return t;
    return '${uri.scheme}://${uri.host}$t';
  }
  return '$base$t';
}
