import 'package:forja/shared/catalog/kit/play/sources_request_context.dart';
import 'package:forja/shared/playback/torrent_js_search.dart';

/// Known Stremio idPrefix → bag scheme name.
const _prefixToScheme = <String, String>{
  'tt': 'imdb',
  'tmdb': 'tmdb',
  'tmdb:': 'tmdb',
  'anilist': 'anilist',
  'anilist:': 'anilist',
  'mal': 'mal',
  'mal:': 'mal',
  'kitsu': 'kitsu',
  'kitsu:': 'kitsu',
  'anidb': 'anidb',
  'anidb:': 'anidb',
};

/// Extract `idPrefixes` for a Stremio resource from an addon manifest map.
List<String> stremioIdPrefixesForResource(
  Map<String, dynamic>? manifest,
  String resourceName,
) {
  if (manifest == null) return const [];
  final resources = manifest['resources'];
  if (resources is List) {
    for (final r in resources) {
      if (r is! Map) continue;
      final name = r['name']?.toString();
      if (name != resourceName) continue;
      final prefixes = r['idPrefixes'];
      if (prefixes is List && prefixes.isNotEmpty) {
        return [
          for (final p in prefixes)
            if (p.toString().trim().isNotEmpty) p.toString().trim(),
        ];
      }
    }
  }
  final top = manifest['idPrefixes'];
  if (top is List && top.isNotEmpty) {
    return [
      for (final p in top)
        if (p.toString().trim().isNotEmpty) p.toString().trim(),
    ];
  }
  return const [];
}

String _schemeForPrefix(String prefix) {
  final p = prefix.trim();
  if (p.isEmpty) return '';
  final mapped = _prefixToScheme[p] ?? _prefixToScheme[p.toLowerCase()];
  if (mapped != null) return mapped;
  if (p.endsWith(':')) {
    final bare = p.substring(0, p.length - 1);
    return _prefixToScheme[bare] ?? bare.toLowerCase();
  }
  return p.toLowerCase();
}

String? _formatStreamId({
  required String scheme,
  required String value,
  required String prefix,
  required bool series,
  int? season,
  int? episode,
}) {
  var id = value.trim();
  if (id.isEmpty) return null;

  if (scheme == 'imdb') {
    final imdb = normalizeTorrentImdbId(id);
    if (imdb == null) return null;
    if (series) {
      final s = (season == null || season < 1) ? 1 : season;
      final e = (episode == null || episode < 1) ? 1 : episode;
      return '$imdb:$s:$e';
    }
    return imdb;
  }

  // Prefer addon-expected prefix form when value is bare digits.
  if (prefix.endsWith(':') && !id.contains(':') && !id.startsWith(prefix)) {
    id = '$prefix$id';
  } else if (prefix == 'tmdb' &&
      !id.startsWith('tmdb:') &&
      RegExp(r'^\d+$').hasMatch(id)) {
    // Many addons use bare or tmdb: — leave bare unless prefix was tmdb:
  }

  if (series && scheme == 'tmdb') {
    final s = (season == null || season < 1) ? 1 : season;
    final e = (episode == null || episode < 1) ? 1 : episode;
    // Stremio TMDB-style series often still uses imdb:S:E; for tmdb keep bare.
    if (id.contains(':')) return id;
    return '$id:$s:$e';
  }

  return id;
}

/// Pick a Stremio `/stream/.../{id}` value from the bag using addon `idPrefixes`.
///
/// Returns null when the addon cannot be queried for this title (skip addon).
/// Empty [idPrefixes] → fall back to IMDb only (legacy addon behavior).
String? resolveStremioStreamId({
  required Map<String, String> ids,
  Map<String, dynamic>? addonManifest,
  required bool series,
  int? season,
  int? episode,
}) {
  var prefixes = stremioIdPrefixesForResource(addonManifest, 'stream');
  if (prefixes.isEmpty) {
    // Manifest omitted prefixes — historical default is IMDb.
    prefixes = const ['tt'];
  }

  for (final prefix in prefixes) {
    final scheme = _schemeForPrefix(prefix);
    if (scheme.isEmpty) continue;
    final raw = ids[scheme];
    if (raw == null || raw.trim().isEmpty) {
      // Also try exact prefix key (unknown schemes).
      final alt = ids[prefix] ?? ids[prefix.replaceAll(':', '')];
      if (alt == null || alt.trim().isEmpty) continue;
      return _formatStreamId(
        scheme: scheme,
        value: alt,
        prefix: prefix,
        series: series,
        season: season,
        episode: episode,
      );
    }
    return _formatStreamId(
      scheme: scheme,
      value: raw,
      prefix: prefix,
      series: series,
      season: season,
      episode: episode,
    );
  }
  return null;
}

/// Resolve stream id for a Sources Stremio fetch.
String? resolveStremioStreamIdFromBag({
  required StremioBagSlice bag,
  Map<String, dynamic>? addonManifest,
}) {
  if (bag.hasCustomAddon) return bag.customStremioId!.trim();
  final series = bag.mediaType == 'tv' || bag.mediaType == 'series';
  return resolveStremioStreamId(
    ids: bag.ids,
    addonManifest: addonManifest,
    series: series,
    season: bag.season,
    episode: bag.episode,
  );
}
