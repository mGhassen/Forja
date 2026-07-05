// Lightweight parser for HLS master playlists.
//
// Used by the player to populate a quality-selector menu when the playing
// stream is a master playlist with multiple `#EXT-X-STREAM-INF` variants.
// If the playlist is a media playlist (segments only, no variants) or the
// fetch fails, the parser returns `null` — the caller should hide the
// quality button in that case.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class HlsQuality {
  /// Display label, e.g. "1080p", "720p", "Auto".
  final String label;

  /// Absolute URL to play. For "Auto" this is the master playlist itself;
  /// for individual variants this is the rendition URL.
  final String url;

  /// Bandwidth in bps (variant only). Null for "Auto".
  final int? bandwidth;

  /// Vertical resolution (e.g. 1080). Null for "Auto" or unknown.
  final int? height;

  /// True for the "Auto" entry that re-selects the master playlist and
  /// lets mpv pick the best variant.
  final bool isAuto;

  const HlsQuality({
    required this.label,
    required this.url,
    this.bandwidth,
    this.height,
    this.isAuto = false,
  });
}

/// Fetches the URL and, if it's a master HLS playlist with 2+ variants,
/// returns the parsed quality list (with an "Auto" entry first).
/// Returns null if the URL isn't HLS, the fetch fails, the playlist is
/// a media playlist, or only one variant is present.
Future<List<HlsQuality>?> fetchHlsQualities(
  String url, {
  Map<String, String>? headers,
  Duration timeout = const Duration(seconds: 8),
}) async {
  if (!url.contains('.m3u8')) return null;

  try {
    final res = await http
        .get(Uri.parse(url), headers: headers)
        .timeout(timeout);
    if (res.statusCode != 200 || res.body.isEmpty) return null;
    return parseHlsMaster(url, res.body);
  } catch (e) {
    debugPrint('[HLS] Quality fetch failed: $e');
    return null;
  }
}

/// Parse a master playlist body. Returns null if not a master or no
/// usable variants. Adds an "Auto" entry pointing back at [masterUrl].
List<HlsQuality>? parseHlsMaster(String masterUrl, String body) {
  if (!body.contains('#EXT-X-STREAM-INF')) return null;

  final base = Uri.tryParse(masterUrl);
  if (base == null) return null;

  // Some servers (e.g. cloudnestra) emit a master playlist on a single
  // line with no real `\n` between entries — they use literal `\n`
  // sequences or just rely on the `#` marker. Normalize first.
  final normalized = body
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      // If the entire body is one line, split on every `#EXT-X-STREAM-INF`
      // to recover the variant boundaries.
      .replaceAll('#EXT-X-STREAM-INF', '\n#EXT-X-STREAM-INF');

  final lines = normalized.split('\n');
  final variants = <HlsQuality>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (!line.startsWith('#EXT-X-STREAM-INF')) continue;

    // Find the next non-empty, non-comment line — that's the URI.
    String? uriLine;
    for (var j = i + 1; j < lines.length; j++) {
      final candidate = lines[j].trim();
      if (candidate.isEmpty) continue;
      if (candidate.startsWith('#')) continue;
      uriLine = candidate;
      break;
    }
    if (uriLine == null) continue;

    final attrs = _parseAttrs(line.substring(line.indexOf(':') + 1));
    final bw = int.tryParse(attrs['BANDWIDTH'] ?? attrs['AVERAGE-BANDWIDTH'] ?? '');
    int? height;
    final res = attrs['RESOLUTION'];
    if (res != null) {
      final m = RegExp(r'(\d+)x(\d+)').firstMatch(res);
      if (m != null) height = int.tryParse(m.group(2)!);
    }

    final resolved = base.resolve(uriLine).toString();
    variants.add(HlsQuality(
      label: _formatLabel(height: height, bandwidth: bw),
      url: resolved,
      bandwidth: bw,
      height: height,
    ));
  }

  if (variants.length < 2) return null;

  // Sort highest quality first (by height, then bandwidth).
  variants.sort((a, b) {
    final ah = a.height ?? 0;
    final bh = b.height ?? 0;
    if (ah != bh) return bh.compareTo(ah);
    return (b.bandwidth ?? 0).compareTo(a.bandwidth ?? 0);
  });

  return [
    HlsQuality(label: 'Auto', url: masterUrl, isAuto: true),
    ...variants,
  ];
}

Map<String, String> _parseAttrs(String s) {
  // Parses `KEY=VALUE,KEY="QUOTED VALUE",...` honoring quoted commas.
  final out = <String, String>{};
  final buf = StringBuffer();
  String? key;
  var inQuotes = false;
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (c == '"') {
      inQuotes = !inQuotes;
      continue;
    }
    if (c == '=' && key == null && !inQuotes) {
      key = buf.toString().trim();
      buf.clear();
      continue;
    }
    if (c == ',' && !inQuotes) {
      if (key != null) out[key] = buf.toString().trim();
      key = null;
      buf.clear();
      continue;
    }
    buf.write(c);
  }
  if (key != null) out[key] = buf.toString().trim();
  return out;
}

String _formatLabel({int? height, int? bandwidth}) {
  if (height != null) return '${height}p';
  if (bandwidth != null) {
    final kbps = (bandwidth / 1000).round();
    return '$kbps kbps';
  }
  return 'Variant';
}
