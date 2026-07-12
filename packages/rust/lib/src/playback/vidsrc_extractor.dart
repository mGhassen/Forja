import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:rust/rust.dart';

import 'extracted_media.dart';

/// Vidsrc / vsembed.ru — resolved via Rust (3 HTTP fetches + HTML chain).
class VidsrcExtractor {
  static int _resolveGeneration = 0;

  /// Ignore in-flight resolves (e.g. user tapped Cancel during provider race).
  static void cancelPending() {
    _resolveGeneration++;
    Engine.cancelPendingResolve();
  }

  static String buildEmbedUrl({
    required String tmdbId,
    required bool isMovie,
    int? season,
    int? episode,
  }) {
    final id = int.tryParse(tmdbId);
    if (id == null) return '';
    if (isMovie) return 'https://vsembed.ru/embed/movie/$id';
    return 'https://vsembed.ru/embed/tv/$id/${season ?? 1}-${episode ?? 1}';
  }

  Future<ExtractedMedia?> extract({
    required String tmdbId,
    required bool isMovie,
    int? season,
    int? episode,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final tmdb = int.tryParse(tmdbId);
    if (tmdb == null) {
      debugPrint('[Vidsrc] Invalid tmdbId: $tmdbId');
      return null;
    }
    if (!Engine.isReady) {
      debugPrint('[Vidsrc] Rust engine not loaded');
      return null;
    }

    final gen = _resolveGeneration;

    try {
      final req = jsonEncode({
        'tmdb_id': tmdb,
        'is_movie': isMovie,
        if (!isMovie) 'season': season ?? 1,
        if (!isMovie) 'episode': episode ?? 1,
      });
      final raw = await runResolveVidsrcEmbedJson(req).timeout(timeout);
      if (gen != _resolveGeneration) return null;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      if (m.containsKey('error')) {
        debugPrint('[Vidsrc] ${m['error']}');
        return null;
      }
      final url = m['url'] as String?;
      if (url == null || url.isEmpty) return null;
      Map<String, String>? headers;
      final h = m['headers'];
      if (h is Map) {
        headers = {
          for (final e in h.entries)
            e.key.toString(): e.value?.toString() ?? '',
        };
      }
      debugPrint('[Vidsrc] ✅ $url');
      return ExtractedMedia(
        url: url,
        headers: headers ?? const {},
        provider: 'vidsrc',
      );
    } on TimeoutException {
      debugPrint('[Vidsrc] timed out after ${timeout.inSeconds}s');
      return null;
    } catch (e, st) {
      debugPrint('[Vidsrc] $e\n$st');
      return null;
    }
  }
}
