import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../webstreamr_settings.dart';
import 'package:rust/rust.dart';

import 'local_server_service.dart';

/// Resolves WebStreamr streams via the Rust engine (no Dart webstreamr package).
class WebStreamrService {
  static final WebStreamrService _instance = WebStreamrService._internal();
  factory WebStreamrService() => _instance;
  WebStreamrService._internal();

  int _resolveGeneration = 0;

  /// Ignore results from in-flight resolves (e.g. user tapped Cancel).
  void cancelPending() {
    _resolveGeneration++;
    Engine.cancelPendingResolve();
  }

  static Future<void> init() async {
    if (!Engine.isReady) await Engine.init();
  }

  Future<List<StreamSource>> getStreams({
    required String imdbId,
    bool isMovie = true,
    int? season,
    int? episode,
    int? tmdbId,
    String? title,
    int? year,
  }) async {
    final generation = _resolveGeneration;
    try {
      await init();
      if (!Engine.isReady) {
        debugPrint('[WebStreamrService] Rust engine not loaded');
        return [];
      }

      final request = await _buildRequest(
        imdbId: imdbId,
        isMovie: isMovie,
        season: season,
        episode: episode,
        tmdbId: tmdbId,
        title: title,
        year: year,
      );
      if (request == null || generation != _resolveGeneration) return [];

      final raw = await runWebstreamrGetStreamsJson(jsonEncode(request));
      if (generation != _resolveGeneration) return [];
      final streams = jsonDecode(raw);
      if (streams is! List) {
        debugPrint('[WebStreamrService] Unexpected response: $raw');
        return [];
      }

      final idLabel = imdbId.isNotEmpty ? imdbId : 'tmdb:$tmdbId';
      final out = <StreamSource>[];
      var skipped = 0;
      for (final item in streams) {
        if (item is! Map) {
          skipped++;
          debugPrint('[WebStreamrService] skip: non-map entry');
          continue;
        }
        final s = Map<String, dynamic>.from(item);
        final url = resolveStreamUrl(s);
        if (url == null || url.isEmpty) {
          skipped++;
          final ytId = s['ytId'];
          debugPrint(
            '[WebStreamrService] skip: no playable url'
            '${ytId != null ? ' (ytId=$ytId)' : ''}',
          );
          continue;
        }

        final name = (s['name'] ?? '') as String;
        final title = (s['title'] ?? '') as String;
        final display = name.isNotEmpty ? '$name\n$title' : title;

        Map<String, String>? headers;
        final bh = s['behaviorHints'];
        if (bh is Map &&
            bh['proxyHeaders'] is Map &&
            (bh['proxyHeaders'] as Map)['request'] is Map) {
          headers = Map<String, String>.from(
            (bh['proxyHeaders'] as Map)['request'] as Map,
          );
        }

        var finalUrl = url;
        if (Uri.tryParse(url)?.host.contains('1shows.app') ?? false) {
          final ls = LocalServerService();
          if (ls.port != 0) {
            finalUrl = ls.getHlsProxyUrl(url, headers ?? {}, stripMode: 'png');
            headers = null;
          }
        }

        out.add(StreamSource(
          url: finalUrl,
          title: display,
          type: 'video',
          headers: headers,
        ));
      }
      final deduped = dedupeStreamSources(out);
      debugPrint(
        '[WebStreamrService] resolved ${deduped.length} streams for $idLabel'
        ' (${streams.length} raw, $skipped skipped, ${out.length - deduped.length} dupes)',
      );
      return deduped;
    } catch (e, st) {
      debugPrint('[WebStreamrService] Exception: $e\n$st');
      return [];
    }
  }

  Future<Map<String, dynamic>?> _buildRequest({
    required String imdbId,
    required bool isMovie,
    int? season,
    int? episode,
    int? tmdbId,
    String? title,
    int? year,
  }) async {
    final config = await WebStreamrSettings.buildResolveConfig();

    final base = imdbId.split(':').first;
    String? imdb;
    int? tmdb;
    if (RegExp(r'^tt\d+$').hasMatch(base)) {
      imdb = base;
    } else if (tmdbId != null) {
      tmdb = tmdbId;
    } else if (RegExp(r'^\d+$').hasMatch(base)) {
      tmdb = int.tryParse(base);
    }

    if (imdb == null && tmdb == null) {
      debugPrint('[WebStreamrService] No valid IMDb/TMDB id for "$imdbId"');
      return null;
    }

    final trimmedTitle = title?.trim();
    final req = <String, dynamic>{
      'imdb_id': ?imdb,
      'tmdb_id': ?tmdb,
      'media_type': isMovie ? 'movie' : 'series',
      if (!isMovie) 'season': season ?? 1,
      if (!isMovie) 'episode': episode ?? 1,
      if (trimmedTitle != null && trimmedTitle.isNotEmpty) 'title': trimmedTitle,
      if (year != null && year > 0) 'year': year,
      'config': config,
      'enabled_sources': <String>[],
    };

    final token = await WebStreamrSettings.getTmdbAccessToken();
    if (token != null && token.isNotEmpty) {
      req['tmdb_access_token'] = token;
    }

    return req;
  }

  /// Maps Rust stream JSON to a playable URL (direct, external, or YouTube).
  @visibleForTesting
  static String? resolveStreamUrl(Map<String, dynamic> s) {
    final url = s['url'] as String?;
    if (url != null && url.isNotEmpty) return url;
    final external = s['externalUrl'] as String?;
    if (external != null && external.isNotEmpty) return external;
    final ytId = s['ytId'] as String?;
    if (ytId != null && ytId.isNotEmpty) {
      return 'https://www.youtube.com/watch?v=$ytId';
    }
    return null;
  }
}
