import 'package:flutter/foundation.dart';

import 'package:forja/features/asian_drama/catalog/kisskh_service.dart';
import 'package:forja/shared/player/controls/player_hub_episode.dart';
import 'package:rust/rust.dart';

typedef HubSeasonExtras = ({
  Map<int, String> stills,
  Map<int, Map<String, dynamic>> meta,
});

/// TMDB season-1 stills + meta keyed by episode number (same shape as details enrich).
class HubDramaEpisodeCache {
  HubDramaEpisodeCache._();

  static const ttl = Duration(minutes: 30);
  static final _byKisskhId =
      <int, ({DateTime at, List<PlayerHubEpisode> episodes})>{};

  static List<PlayerHubEpisode>? read(int kisskhId) {
    final hit = _byKisskhId[kisskhId];
    if (hit == null) return null;
    if (DateTime.now().difference(hit.at) > ttl) {
      _byKisskhId.remove(kisskhId);
      return null;
    }
    return List<PlayerHubEpisode>.from(hit.episodes);
  }

  static void write(int kisskhId, List<PlayerHubEpisode> episodes) {
    if (kisskhId <= 0 || episodes.isEmpty) return;
    _byKisskhId[kisskhId] = (
      at: DateTime.now(),
      episodes: List.from(episodes),
    );
  }

  static void invalidate(int kisskhId) {
    _byKisskhId.remove(kisskhId);
  }
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

String? _hubEpisodeThumbnail(
  KdramaDetails det,
  KdramaEpisode ep,
  Map<int, String> stills,
) {
  final kissNum =
      ep.number == ep.number.truncateToDouble() ? ep.number.toInt() : null;
  final still = (kissNum != null ? stills[kissNum] : null) ??
      stills[ep.pickerKey];
  if (still != null && still.trim().isNotEmpty) {
    return resolveHubEpisodeArtUrl(still.trim(), still: true);
  }
  final cover = KissKhService.resolveCoverUrl(det.cover);
  return cover.isNotEmpty ? cover : null;
}

/// Build player hub rows from KissKH details + TMDB season extras (details / player).
List<PlayerHubEpisode> dramaHubEpisodesFromDetails(
  KdramaDetails det, {
  Map<int, String> stills = const {},
  Map<int, Map<String, dynamic>> meta = const {},
}) {
  return [
    for (var i = 0; i < det.episodes.length; i++)
      _hubEpisodeRow(
        det: det,
        ep: det.episodes[i],
        index: i,
        stills: stills,
        meta: meta,
      ),
  ];
}

PlayerHubEpisode _hubEpisodeRow({
  required KdramaDetails det,
  required KdramaEpisode ep,
  required int index,
  required Map<int, String> stills,
  required Map<int, Map<String, dynamic>> meta,
}) {
  final kissNum =
      ep.number == ep.number.truncateToDouble() ? ep.number.toInt() : null;
  final tmdbMeta = meta[kissNum ?? -1] ?? meta[ep.pickerKey] ?? const {};
  final tmdbName = (tmdbMeta['name'] as String?)?.trim() ?? '';
  final overview = (tmdbMeta['overview'] as String?)?.trim() ?? '';
  final runtime = (tmdbMeta['runtime'] as int?) ?? 0;
  final aired = (tmdbMeta['aired'] as String?)?.trim() ?? '';
  return PlayerHubEpisode(
    number: ep.number,
    title: tmdbName.isNotEmpty ? tmdbName : 'Episode ${ep.displayNumber}',
    overview: overview.isNotEmpty ? overview : null,
    runtimeMinutes: runtime,
    airDateLabel: aired.isNotEmpty ? aired : null,
    thumbnailUrl: _hubEpisodeThumbnail(det, ep, stills),
  );
}

/// Keep TMDB-enriched rows from details; only hit KissKH when the list is missing.
Future<List<PlayerHubEpisode>?> ensureDramaHubEpisodes({
  required int? kisskhId,
  required List<PlayerHubEpisode>? hubEpisodes,
  int? tmdbTvId,
  KdramaDetails? kissDetails,
  int? liveEpisodeCount,
}) async {
  if (kisskhId == null || kisskhId <= 0) return hubEpisodes;

  if (hubEpisodes != null && hubEpisodes.isNotEmpty) {
    HubDramaEpisodeCache.write(kisskhId, hubEpisodes);
    return hubEpisodes;
  }

  final cached = HubDramaEpisodeCache.read(kisskhId);
  if (cached != null && cached.isNotEmpty) {
    final hintedCount = kissDetails?.episodes.length ?? liveEpisodeCount;
    if (hintedCount != null && hintedCount == cached.length) return cached;

    try {
      final det = kissDetails ?? await KissKhService().getDetails(kisskhId);
      if (det.episodes.length == cached.length) return cached;
      if (det.episodes.isEmpty) return cached;

      final rebuilt = await _buildDramaHubEpisodes(det, tmdbTvId: tmdbTvId);
      HubDramaEpisodeCache.write(kisskhId, rebuilt);
      return rebuilt;
    } catch (_) {
      return cached;
    }
  }

  try {
    final det = kissDetails ?? await KissKhService().getDetails(kisskhId);
    if (det.episodes.isEmpty) return hubEpisodes;

    final built = await _buildDramaHubEpisodes(det, tmdbTvId: tmdbTvId);
    HubDramaEpisodeCache.write(kisskhId, built);
    return built;
  } catch (_) {
    return hubEpisodes;
  }
}

Future<List<PlayerHubEpisode>> _buildDramaHubEpisodes(
  KdramaDetails det, {
  int? tmdbTvId,
}) async {
  var stills = const <int, String>{};
  var meta = const <int, Map<String, dynamic>>{};
  final tvId = tmdbTvId ?? det.tmdbId;
  if (tvId != null && tvId > 0) {
    final extras = await loadTmdbSeasonExtras(tvId);
    stills = extras.stills;
    meta = extras.meta;
  }
  return dramaHubEpisodesFromDetails(det, stills: stills, meta: meta);
}
