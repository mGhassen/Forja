import 'package:flutter/foundation.dart';
import 'package:forja/shared/extractors/core/stream_extractor.dart';

/// embed.st GOAT decrypt bridge for live-streamed.js (`ctx.live.goatUnlock`).
///
/// Runs programmatic embed extraction (not the Live Matches embed player).
class LiveGoatUnlock {
  LiveGoatUnlock._();

  static Future<String?> unlock({
    required Map<String, dynamic> slot,
    required String goat,
    required String bodyHex,
  }) async {
    if (goat.isEmpty) return null;
    final origin = (slot['origin'] ?? 'https://embed.st').toString();
    final path = (slot['path'] ?? '').toString();
    if (path.isEmpty) return null;
    final embedUrl = '$origin/embed/$path';
    final referer = origin.endsWith('/') ? origin : '$origin/';
    debugPrint('[LiveGoatUnlock] embed=$embedUrl goat=${goat.length} body=${bodyHex.length ~/ 2}B');
    try {
      final extracted = await StreamExtractor().extract(
        embedUrl,
        referer: referer,
        iframeWrapperBaseUrl: referer,
        timeout: const Duration(seconds: 35),
      );
      final url = extracted?.url.trim() ?? '';
      if (url.isEmpty) return null;
      return url;
    } catch (e) {
      debugPrint('[LiveGoatUnlock] failed: $e');
      return null;
    }
  }

  static Future<String?> sniffEmbed({
    required String embedUrl,
    String? referer,
  }) async {
    final url = embedUrl.trim();
    if (url.isEmpty) return null;
    final ref = (referer ?? url).trim();
    try {
      final extracted = await StreamExtractor().extract(
        url,
        referer: ref,
        iframeWrapperBaseUrl: ref.endsWith('/') ? ref : '$ref/',
        timeout: const Duration(seconds: 35),
      );
      final out = extracted?.url.trim() ?? '';
      return out.isEmpty ? null : out;
    } catch (e) {
      debugPrint('[LiveSniffEmbed] failed: $e');
      return null;
    }
  }
}
