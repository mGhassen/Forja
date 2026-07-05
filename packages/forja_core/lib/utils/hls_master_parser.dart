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

/// Optional Rust backend hook. Set by `forja_rust` at startup.
abstract final class HlsParserBackend {
  static List<HlsQuality>? Function(String masterUrl, String body)? parseMaster;
}

class HlsQuality {
  final String label;
  final String url;
  final int? bandwidth;
  final int? height;
  final bool isAuto;

  const HlsQuality({
    required this.label,
    required this.url,
    this.bandwidth,
    this.height,
    this.isAuto = false,
  });
}

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

List<HlsQuality>? parseHlsMaster(String masterUrl, String body) {
  final backend = HlsParserBackend.parseMaster;
  if (backend != null) return backend(masterUrl, body);
  throw StateError(
    'HlsParserBackend.parseMaster not wired — call ForjaEngine.init()',
  );
}
