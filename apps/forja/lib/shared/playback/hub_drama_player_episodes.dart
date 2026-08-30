import 'package:flutter/foundation.dart';

import 'package:forja/shared/catalog/catalog_details_fetch.dart';
import 'package:forja/shared/catalog/hub_cover_urls.dart';
import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/shared/player/controls/player_hub_episode.dart';
import 'package:rust/rust.dart';

typedef HubSeasonExtras = ({
  Map<int, String> stills,
  Map<int, Map<String, dynamic>> meta,
});

class HubDramaEpisodeCache {
  HubDramaEpisodeCache._();

  static const ttl = Duration(minutes: 30);
  static final _byMetaId = <String, ({DateTime at, List<PlayerHubEpisode> episodes})>{};

  static List<PlayerHubEpisode>? read(String metaId) {
    final hit = _byMetaId[metaId];
    if (hit == null) return null;
    if (DateTime.now().difference(hit.at) > ttl) {
      _byMetaId.remove(metaId);
      return null;
    }
    return List<PlayerHubEpisode>.from(hit.episodes);
  }

  static void write(String metaId, List<PlayerHubEpisode> episodes) {
    if (metaId.isEmpty || episodes.isEmpty) return;
    _byMetaId[metaId] = (
      at: DateTime.now(),
      episodes: List.from(episodes),
    );
  }

  static void invalidate(String metaId) => _byMetaId.remove(metaId);
}

Future<HubSeasonExtras> loadTmdbSeasonExtras(int tvId) async {
  try {
    final data = await TmdbApi().getTvSeasonDetails(tvId, 1);
    final eps = data['episodes'] as List? ?? const [];
    final stills = <int, String>{};
    final meta = <int, Map<String, dynamic>>{};
    for (final raw in eps) {
      if (raw is! Map) continue;
      final n = (raw['episode_number'] as num?)?.toInt();
      if (n == null || n <= 0) continue;
      final still = (raw['still_path'] as String?)?.trim() ?? '';
      if (still.isNotEmpty) stills[n] = still;
      final name = (raw['name'] as String?)?.trim() ?? '';
      final overview = (raw['overview'] as String?)?.trim() ?? '';
      final runtime = (raw['runtime'] as num?)?.toInt() ?? 0;
      final aired = (raw['air_date'] as String?)?.trim() ?? '';
      meta[n] = {
        if (name.isNotEmpty) 'name': name,
        if (overview.isNotEmpty) 'overview': overview,
        if (runtime > 0) 'runtime': runtime,
        if (aired.isNotEmpty) 'aired': aired,
      };
    }
    return (stills: stills, meta: meta);
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[HubDrama] TMDB season extras failed id=$tvId: $e');
    }
    return (stills: <int, String>{}, meta: <int, Map<String, dynamic>>{});
  }
}

List<PlayerHubEpisode> hubEpisodesFromCatalogMeta(
  CatalogMetaItem meta, {
  Map<int, String> stills = const {},
  Map<int, Map<String, dynamic>> tmdbMeta = const {},
}) {
  final cover = resolveHubCoverUrl(
    meta.background.isNotEmpty ? meta.background : meta.poster,
  );
  return [
    for (final v in meta.videos)
      _hubEpisodeRow(
        video: v,
        fallbackCover: cover,
        stills: stills,
        meta: tmdbMeta,
      ),
  ];
}

PlayerHubEpisode _hubEpisodeRow({
  required CatalogVideo video,
  required String fallbackCover,
  required Map<int, String> stills,
  required Map<int, Map<String, dynamic>> meta,
}) {
  final epNum = video.episode ?? 1;
  final tmdbMeta = meta[epNum] ?? const {};
  final tmdbName = (tmdbMeta['name'] as String?)?.trim() ?? '';
  final overview = (tmdbMeta['overview'] as String?)?.trim() ?? '';
  final runtime = (tmdbMeta['runtime'] as int?) ?? 0;
  final aired = (tmdbMeta['aired'] as String?)?.trim() ?? '';
  final still = stills[epNum];
  final thumbRaw = (video.thumbnail.trim().isNotEmpty
          ? video.thumbnail
          : still ?? '')
      .trim();
  final thumb = thumbRaw.isNotEmpty
      ? resolveHubEpisodeArtUrl(thumbRaw, still: true)
      : (fallbackCover.isNotEmpty ? fallbackCover : null);
  return PlayerHubEpisode(
    number: epNum,
    title: tmdbName.isNotEmpty
        ? tmdbName
        : (video.title.isNotEmpty ? video.title : 'Episode $epNum'),
    overview: overview.isNotEmpty ? overview : null,
    runtimeMinutes: runtime,
    airDateLabel: aired.isNotEmpty ? aired : null,
    thumbnailUrl: thumb,
  );
}

Future<List<PlayerHubEpisode>> _buildFromPackMeta(
  CatalogMetaItem meta, {
  int? tmdbTvId,
}) async {
  var stills = const <int, String>{};
  var tmdbMeta = const <int, Map<String, dynamic>>{};
  final tvId = tmdbTvId ?? meta.numericId('tmdb');
  if (tvId != null && tvId > 0) {
    final extras = await loadTmdbSeasonExtras(tvId);
    stills = extras.stills;
    tmdbMeta = extras.meta;
  }
  return hubEpisodesFromCatalogMeta(meta, stills: stills, tmdbMeta: tmdbMeta);
}

/// Keep enriched rows from details; fetch pack `details` when the list is missing.
Future<List<PlayerHubEpisode>?> ensureDramaHubEpisodes({
  required String? pluginId,
  required String? metaId,
  required List<PlayerHubEpisode>? hubEpisodes,
  int? tmdbTvId,
  int? liveEpisodeCount,
}) async {
  if (pluginId == null || metaId == null || metaId.isEmpty) return hubEpisodes;

  if (hubEpisodes != null && hubEpisodes.isNotEmpty) {
    HubDramaEpisodeCache.write(metaId, hubEpisodes);
    return hubEpisodes;
  }

  final cached = HubDramaEpisodeCache.read(metaId);
  if (cached != null && cached.isNotEmpty) {
    if (liveEpisodeCount == null || liveEpisodeCount == cached.length) {
      return cached;
    }
  }

  try {
    final meta = await fetchCatalogMetaDetails(
      pluginId: pluginId,
      metaId: metaId,
    );
    if (meta == null || meta.videos.isEmpty) return hubEpisodes ?? cached;

    final built = await _buildFromPackMeta(meta, tmdbTvId: tmdbTvId);
    if (built.isEmpty) return hubEpisodes ?? cached;
    HubDramaEpisodeCache.write(metaId, built);
    return built;
  } catch (_) {
    return hubEpisodes ?? cached;
  }
}
