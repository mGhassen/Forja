import 'package:forja/features/iptv/data/models.dart';
import 'package:forja/features/iptv/iptv_title_clean.dart';
import 'package:rust/rust.dart';

/// TMDB recommendation that maps to a playable portal VOD/series row.
class IptvCatalogRecHit {
  const IptvCatalogRecHit({
    required this.tmdb,
    required this.stream,
  });

  final Movie tmdb;
  final IptvStream stream;
}

/// Intersect TMDB "More like this" with active-portal Movies/Series catalog.
///
/// Strict title match after [cleanIptvMediaTitle]. Years must agree when both
/// sides have one. Prefers `vod`↔movie / `series`↔tv. Hides unmatched TMDB
/// rows — never falls back to Home details.
List<IptvCatalogRecHit> filterIptvCatalogRecommendations({
  required List<Movie> recommendations,
  required List<IptvStream> catalog,
  String? excludeStreamId,
}) {
  if (recommendations.isEmpty || catalog.isEmpty) return const [];

  final indexed = <_CatalogEntry>[];
  for (final s in catalog) {
    if (s.kind != 'vod' && s.kind != 'series') continue;
    if (excludeStreamId != null && s.streamId == excludeStreamId) continue;
    final cleaned = cleanIptvMediaTitle(s.name);
    final key = _normKey(cleaned.title);
    if (key.isEmpty) continue;
    indexed.add(_CatalogEntry(stream: s, key: key, year: cleaned.year));
  }
  if (indexed.isEmpty) return const [];

  final out = <IptvCatalogRecHit>[];
  final usedStreamIds = <String>{};

  for (final rec in recommendations) {
    final recKey = _normKey(rec.title);
    if (recKey.isEmpty) continue;
    final recYear = _yearFromRelease(rec.releaseDate);
    final preferSeries = rec.mediaType == 'tv';

    _CatalogEntry? best;
    var bestScore = 0;
    for (final e in indexed) {
      if (usedStreamIds.contains(e.stream.streamId)) continue;
      if (e.key != recKey) continue;
      if (recYear != null && e.year != null && recYear != e.year) continue;

      var score = 10;
      if (recYear != null && e.year != null && recYear == e.year) score += 3;
      final kindSeries = e.stream.kind == 'series';
      if (preferSeries == kindSeries) {
        score += 2;
      } else {
        score -= 1;
      }
      if (score > bestScore) {
        bestScore = score;
        best = e;
      }
    }
    if (best == null || bestScore < 10) continue;
    usedStreamIds.add(best.stream.streamId);
    out.add(IptvCatalogRecHit(tmdb: rec, stream: best.stream));
  }
  return out;
}

String _normKey(String raw) {
  var t = raw.trim();
  if (t.isEmpty) return '';
  // Trailing "(2024)" / "[2024]" on TMDB titles.
  t = t.replaceFirst(RegExp(r'[\(\[]\s*\d{4}\s*[\)\]]\s*$'), '').trim();
  return t.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

int? _yearFromRelease(String releaseDate) {
  final m = RegExp(r'\b((?:19|20)\d{2})\b').firstMatch(releaseDate);
  if (m == null) return null;
  return int.tryParse(m.group(1)!);
}

class _CatalogEntry {
  const _CatalogEntry({
    required this.stream,
    required this.key,
    required this.year,
  });

  final IptvStream stream;
  final String key;
  final int? year;
}
