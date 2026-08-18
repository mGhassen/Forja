import 'dart:convert';

import 'package:forja/shared/engine/models.dart';
import 'package:forja/shared/playback/host_provider_adapter.dart';
import 'package:forja/shared/playback/playback_stream_guards.dart';
import 'package:rust/rust.dart';

/// Resolves Forja `kind: host` plugins via built-in sniff / API extractors.
abstract final class EngineHostResolver {
  static Future<List<Map<String, dynamic>>> resolve({
    required EnginePlugin plugin,
    required Movie movie,
    required int season,
    required int episode,
    required bool Function() isCancelled,
  }) async {
    if (isCancelled()) return const [];
    final hostId = plugin.hostProviderId;
    final year = movie.releaseDate.length >= 4
        ? movie.releaseDate.substring(0, 4)
        : null;

    if (hostId == 'webstreamr') {
      final isMovie = movie.mediaType != 'tv';
      final sources = await WebStreamrService().getStreams(
        imdbId: movie.imdbId ?? '',
        isMovie: isMovie,
        season: isMovie ? null : season,
        episode: isMovie ? null : episode,
        tmdbId: movie.id,
        title: movie.title,
        year: year != null ? int.tryParse(year) : null,
      );
      if (isCancelled()) return const [];
      return _fromStreamSources(
        plugin: plugin,
        hostId: hostId,
        sources: sources,
        movie: movie,
        year: year,
        season: season,
        episode: episode,
      );
    }

    final raw = await HostProviderAdapter.resolveToSourcesJson(
      providerId: hostId,
      payloadJson: '{}',
      movie: movie,
      providers: StreamProviders.providers,
      season: season,
      episode: episode,
      isCancelled: isCancelled,
    );
    if (isCancelled() || raw == null || raw.trim().isEmpty) return const [];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];

    final out = <Map<String, dynamic>>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final url = (map['url'] ?? '').toString().trim();
      if (url.isEmpty || isTorrentStreamUrl(url)) continue;
      final mapped = mapEngineStream(
        raw: map,
        plugin: plugin,
        mediaTitle: movie.title,
        year: year,
        type: movie.mediaType,
        season: season,
        episode: episode,
        requiresProxy: hostId == 'service111477',
      );
      if (mapped != null) out.add(mapped);
    }
    return out;
  }

  static List<Map<String, dynamic>> _fromStreamSources({
    required EnginePlugin plugin,
    required String hostId,
    required List<StreamSource> sources,
    required Movie movie,
    required String? year,
    required int season,
    required int episode,
  }) {
    final out = <Map<String, dynamic>>[];
    for (final s in sources) {
      final url = s.url.trim();
      if (url.isEmpty || isUnplayableCachedStreamUrl(url)) continue;
      final mapped = mapEngineStream(
        raw: {
          'url': url,
          'title': s.title.isNotEmpty ? s.title : plugin.name,
          'name': s.title.isNotEmpty ? s.title : plugin.name,
          if (s.headers != null && s.headers!.isNotEmpty) 'headers': s.headers,
        },
        plugin: plugin,
        mediaTitle: movie.title,
        year: year,
        type: movie.mediaType,
        season: season,
        episode: episode,
        requiresProxy: hostId == 'service111477',
      );
      if (mapped != null) out.add(mapped);
    }
    return out;
  }
}
