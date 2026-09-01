import 'package:forja/shared/catalog/hub_cover_urls.dart';
import 'package:forja/shared/catalog/plugin_nav.dart';
import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/shared/catalog/runtime.dart';
import 'package:forja/shared/widgets/episode_air_date.dart';

Map<String, dynamic> hubDetailsParams(CatalogMetaItem seed) {
  final params = <String, dynamic>{'id': seed.id};
  final open = seed.open;
  if (open == null) return params;
  for (final e in open.toJson().entries) {
    if (e.key == 'surface') continue;
    params[e.key] = e.value;
  }
  params['id'] = seed.id;
  return params;
}

bool hubMetaIsMovie(CatalogMetaItem item) {
  if (item.open?.extraBool('movie') == true) return true;
  if ((item.badge ?? '').toUpperCase() == 'MOVIE') return true;
  if (item.type == 'movie') return true;
  final fmt = (item.badge ?? '').toUpperCase();
  return fmt == 'MOVIE' || item.tmdbMediaType == 'movie';
}

String hubMetaTmdbMediaType(CatalogMetaItem item) {
  if (hubMetaIsMovie(item)) return 'movie';
  final hint = (item.tmdbMediaType ?? '').trim().toLowerCase();
  if (hint == 'movie' || hint == 'tv') return hint;
  return 'tv';
}

String? hubMetaPremiereIso(CatalogMetaItem item) {
  final premiere = item.premiereDate.trim();
  if (premiere.length >= 10) return premiere.substring(0, 10);
  final bit = item.releaseInfo.split(' • ').first.trim();
  if (bit.length >= 10 && _looksLikeIsoDate(bit)) {
    return bit.substring(0, 10);
  }
  return null;
}

String? hubMetaPremiereDateLabel(CatalogMetaItem item) {
  final iso = hubMetaPremiereIso(item);
  if (iso == null) return null;
  return formatEpisodeDisplayDate(iso);
}

bool hubMetaIsUpcoming(
  CatalogMetaItem item, {
  Iterable<CatalogVideo> videos = const [],
}) {
  final status = (item.status ?? '').trim().toUpperCase();
  if (status == 'NOT_YET_RELEASED') return true;
  final iso = hubMetaPremiereIso(item);
  if (iso == null || !isFutureIsoDate(iso)) return false;
  if (hubMetaIsMovie(item)) return true;
  return videos.isEmpty;
}

bool hubVideoNotAiredYet(CatalogVideo video) =>
    episodeAirDateInfo(_hubVideoEpisodeMap(video)).notShippedYet;

EpisodeAirDateInfo hubVideoAirDateInfo(CatalogVideo video) =>
    episodeAirDateInfo(_hubVideoEpisodeMap(video));

Map<String, dynamic> _hubVideoEpisodeMap(CatalogVideo video) => {
      'air_date': video.airDate,
      if (video.aired != null) 'aired': video.aired,
    };

bool _looksLikeIsoDate(String raw) {
  if (raw.length < 10) return false;
  final parts = raw.substring(0, 10).split('-');
  if (parts.length != 3) return false;
  return int.tryParse(parts[0]) != null &&
      int.tryParse(parts[1]) != null &&
      int.tryParse(parts[2]) != null;
}

Map<int, List<Map<String, dynamic>>>? hubEpisodeMaps(
  List<CatalogVideo> videos,
) {
  if (videos.isEmpty) return null;
  final bySeason = <int, List<Map<String, dynamic>>>{};
  for (final v in videos) {
    final season = v.season ?? 1;
    final epNum = v.episode ?? 1;
    final thumb = resolveHubCoverUrl(v.thumbnail.trim());
    bySeason.putIfAbsent(season, () => []);
    bySeason[season]!.add({
      'episode_number': epNum,
      'name': v.title.isNotEmpty ? v.title : 'Episode $epNum',
      if (thumb.isNotEmpty) 'still_path': thumb,
      if (v.airDate.trim().isNotEmpty) 'air_date': v.airDate.trim(),
      if (v.aired != null) 'aired': v.aired,
    });
  }
  return bySeason;
}

Set<int> hubSeasonNumbers(List<CatalogVideo> videos) {
  return {for (final v in videos) v.season ?? 1};
}

List<CatalogVideo> hubVideosForSeason(List<CatalogVideo> videos, int season) {
  return [
    for (final v in videos)
      if ((v.season ?? 1) == season) v,
  ];
}

String hubImageUrl(String path) => resolveHubCoverUrl(path.trim());

String? hubShellTabIdForPlugin(String pluginId) =>
    PluginNavRegistry.tabIdForPluginSync(pluginId);

/// Same contract as [CatalogRuntime.metaTmdbEnriched] for a parsed meta.
bool hubMetaTmdbEnriched(CatalogMetaItem meta) => CatalogRuntime.metaTmdbEnriched(
      {
        ...meta.ids.isEmpty ? const <String, dynamic>{} : {'ids': meta.ids},
        'background': meta.background,
      },
    );

bool hubMetaIsIptv(CatalogMetaItem item) =>
    item.open?.effectiveExtract.resolveType == 'iptv';
