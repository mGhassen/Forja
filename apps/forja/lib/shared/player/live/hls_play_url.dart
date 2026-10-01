import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Strip SSAI / XUMO template query values (`[IFA]`, `[PLATFORM]`, …).
///
/// Placeholders are for ad SDKs; leaving them on the URL confuses some CDNs and
/// mpv. Lume/AVPlayer tolerate them; MediaKit does better without.
@visibleForTesting
String iptvStripHlsAdPlaceholders(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasQuery) return url;
  final kept = <String, String>{};
  for (final e in uri.queryParameters.entries) {
    final v = e.value.trim();
    if (v.isEmpty) continue;
    if (RegExp(r'^\[.*\]$').hasMatch(v)) continue;
    if (v.contains('[') && v.contains(']')) continue;
    kept[e.key] = e.value;
  }
  return uri.replace(queryParameters: kept.isEmpty ? null : kept).toString();
}

/// Pick a media-playlist URI from an HLS master body.
///
/// Prefers the highest `BANDWIDTH` ≤ [maxBandwidth] (mpv ABR probe of every
/// DAI/XUMO variant stalls with cache=0). Falls back to the lowest variant.
@visibleForTesting
String? iptvPickHlsMediaPlaylistUrl({
  required String masterBody,
  required String masterUrl,
  int maxBandwidth = 3_500_000,
}) {
  if (!masterBody.contains('#EXT-X-STREAM-INF')) {
    return masterBody.contains('#EXTINF') ? masterUrl : null;
  }
  final base = _hlsBaseUrl(masterUrl);
  final variants = <({int bw, String url})>[];
  final lines = masterBody.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (!line.startsWith('#EXT-X-STREAM-INF')) continue;
    final bwMatch = RegExp(r'BANDWIDTH=(\d+)').firstMatch(line);
    final bw = bwMatch != null ? int.tryParse(bwMatch.group(1)!) ?? 0 : 0;
    final next = i + 1 < lines.length ? lines[i + 1].trim() : '';
    if (next.isEmpty || next.startsWith('#')) continue;
    final resolved = _hlsResolveUrl(next, base);
    if (resolved == null) continue;
    variants.add((bw: bw, url: resolved));
  }
  if (variants.isEmpty) return null;
  final underCap = variants.where((v) => v.bw > 0 && v.bw <= maxBandwidth);
  if (underCap.isNotEmpty) {
    return underCap.reduce((a, b) => a.bw >= b.bw ? a : b).url;
  }
  return variants.reduce((a, b) => a.bw <= b.bw ? a : b).url;
}

/// Resolve HLS master → one media playlist for MediaKit/mpv.
///
/// Lume plays the same XUMO/DAI feeds via AVPlayer (native ABR). mpv's HLS
/// demuxer hangs probing every `#EXT-X-STREAM-INF` + AUDIO group — open a
/// concrete media playlist instead (issue 273).
Future<String> iptvResolveHlsPlayUrl({
  required String url,
  Map<String, String> headers = const {},
  int maxBandwidth = 3_500_000,
  Future<String?> Function(String url, Map<String, String> headers)? fetchBody,
}) async {
  final cleaned = iptvStripHlsAdPlaceholders(url.trim());
  if (!cleaned.toLowerCase().contains('.m3u8')) return cleaned;

  final fetch = fetchBody ?? _fetchPlaylistText;
  try {
    final body = await fetch(cleaned, headers);
    if (body == null || body.isEmpty) return cleaned;
    final media = iptvPickHlsMediaPlaylistUrl(
      masterBody: body,
      masterUrl: cleaned,
      maxBandwidth: maxBandwidth,
    );
    if (media == null || media == cleaned) return cleaned;
    debugPrint(
      '[IPTV] hls master → media playlist '
      '(maxBw=${(maxBandwidth / 1e6).toStringAsFixed(1)}M)',
    );
    return media;
  } catch (e) {
    debugPrint('[IPTV] hls resolve failed: $e — using catalog URL');
    return cleaned;
  }
}

Future<String?> _fetchPlaylistText(
  String url,
  Map<String, String> headers,
) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  final res = await http
      .get(uri, headers: headers)
      .timeout(const Duration(seconds: 15));
  if (res.statusCode < 200 || res.statusCode >= 300) return null;
  return utf8.decode(res.bodyBytes);
}

String _hlsBaseUrl(String url) {
  final uri = Uri.parse(url);
  final path = uri.path;
  final slash = path.lastIndexOf('/');
  final dir = slash >= 0 ? path.substring(0, slash + 1) : '/';
  return uri.replace(path: dir, query: '', fragment: '').toString();
}

String? _hlsResolveUrl(String ref, String base) {
  final t = ref.trim();
  if (t.isEmpty) return null;
  if (t.startsWith('http://') || t.startsWith('https://')) return t;
  return Uri.parse(base).resolve(t).toString();
}
