import 'package:flutter/foundation.dart';
import 'package:forja/features/iptv/iptv_title_clean.dart';
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
  final match = await _matchIptvTitle(
    api: api,
    title: cleaned.title,
    year: cleaned.year?.toString(),
    preferMovie: preferMovie,
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

String _normalizeIptvMatchTitle(String raw) {
  var t = raw.trim();
  if (t.isEmpty) return t;
  t = t.replaceFirst(RegExp(r'[\(\[]\s*\d{4}\s*[\)\]]\s*$'), '').trim();
  t = t.replaceAll(
    RegExp(
      r'\b(HD|FHD|UHD|4K|1080p|720p|WEB-?DL|BluRay)\b',
      caseSensitive: false,
    ),
    ' ',
  );
  final pipe = t.indexOf('|');
  if (pipe > 0) t = t.substring(0, pipe);
  return t.replaceAll(RegExp(r'\s+'), ' ').trim();
}

Future<Movie?> _matchIptvTitle({
  required TmdbApi api,
  required String title,
  String? year,
  required bool preferMovie,
  int minScore = 2,
}) async {
  final q = _normalizeIptvMatchTitle(title);
  if (q.isEmpty) return null;
  try {
    final hits = await api.searchMulti(q);
    if (hits.isEmpty) return null;
    Movie? best;
    var bestScore = -1;
    final wantYear = int.tryParse((year ?? '').trim()) ??
        int.tryParse(
          RegExp(r'\b(19|20)\d{2}\b').firstMatch(title)?.group(0) ?? '',
        );
    for (final h in hits) {
      var s = 0;
      final ht = _normalizeIptvMatchTitle(h.title).toLowerCase();
      final qt = q.toLowerCase();
      if (ht == qt) {
        s += 5;
      } else if (ht.startsWith(qt) || qt.startsWith(ht)) {
        s += 2;
      } else if (ht.contains(qt) || qt.contains(ht)) {
        s += 1;
      } else {
        continue;
      }
      if (preferMovie) {
        if (h.mediaType == 'movie') {
          s += 3;
        } else if (h.mediaType == 'tv') {
          s += 1;
        }
      } else {
        if (h.mediaType == 'tv') {
          s += 3;
        } else if (h.mediaType == 'movie') {
          s += 1;
        }
      }
      if (wantYear != null && h.releaseDate.length >= 4) {
        final hy = int.tryParse(h.releaseDate.substring(0, 4));
        if (hy == wantYear) {
          s += 4;
        } else if (hy != null && (hy - wantYear).abs() <= 1) {
          s += 1;
        }
      }
      if (s > bestScore) {
        bestScore = s;
        best = h;
      }
    }
    if (best == null || bestScore < minScore) return null;
    return best;
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[IPTV] TMDB search failed for "$q": $e');
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
