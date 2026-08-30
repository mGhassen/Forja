import 'package:flutter/foundation.dart';
import 'package:forja/shared/catalog/enrich/kisskh_tmdb_match.dart';
import 'package:forja/features/iptv/iptv/iptv_title_clean.dart';
import 'package:rust/rust.dart';

/// TMDB match + rich details for IPTV movie/series details pages.
class IptvTmdbEnrichment {
  const IptvTmdbEnrichment({
    required this.rich,
    this.episodeStills = const {},
    this.episodeMeta = const {},
  });

  final RichMediaDetails rich;
  final Map<int, String> episodeStills;
  final Map<int, Map<String, dynamic>> episodeMeta;
}

Future<IptvTmdbEnrichment?> loadIptvTmdbEnrichment({
  required String rawTitle,
  required bool preferMovie,
  TmdbApi? tmdb,
}) async {
  final cleaned = cleanIptvMediaTitle(rawTitle);
  if (cleaned.isEmpty) return null;
  final api = tmdb ?? TmdbApi();
  final match = await KissKhTmdbMatch.resolve(
    title: cleaned.title,
    year: cleaned.year?.toString(),
    kissKhType: preferMovie ? 'movie' : 'tv',
    tmdb: api,
  );
  if (match == null) return null;
  final mediaType = match.mediaType == 'movie' || match.mediaType == 'tv'
      ? match.mediaType
      : (preferMovie ? 'movie' : 'tv');
  try {
    final rich = await api.getRichDetails(match.id, mediaType);
    if (mediaType != 'tv') {
      return IptvTmdbEnrichment(rich: rich);
    }
    final season = await _loadSeasonExtras(api, match.id);
    return IptvTmdbEnrichment(
      rich: rich,
      episodeStills: season.stills,
      episodeMeta: season.meta,
    );
  } catch (e) {
    if (kDebugMode) {
      debugPrint(
        '[IPTV] TMDB rich details failed id=${match.id} $mediaType: $e',
      );
    }
    return null;
  }
}

typedef _SeasonExtras = ({
  Map<int, String> stills,
  Map<int, Map<String, dynamic>> meta,
});

Future<_SeasonExtras> _loadSeasonExtras(TmdbApi tmdb, int tvId) async {
  try {
    final data = await tmdb.getTvSeasonDetails(tvId, 1);
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
      debugPrint('[IPTV] TMDB season extras failed id=$tvId: $e');
    }
    return (
      stills: <int, String>{},
      meta: <int, Map<String, dynamic>>{},
    );
  }
}
