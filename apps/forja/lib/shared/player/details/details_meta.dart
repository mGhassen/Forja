import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja_foundation/utils/cover_urls.dart';
import 'package:forja_foundation/widgets/details/episode_air_date.dart';

/// Pack `details` action params from catalog meta (opaque `open` passthrough).
Map<String, dynamic> hubDetailsParams(MetaItem seed) {
  final open = seed.open;
  final openId = open?.id.trim() ?? '';
  final detailsId = openId.isNotEmpty ? openId : seed.id;
  final params = <String, dynamic>{'id': detailsId};
  if (open == null) return params;
  for (final e in open.toJson().entries) {
    if (e.key == 'surface') continue;
    params[e.key] = e.value;
  }
  params['id'] = detailsId;
  return params;
}

bool metaIsMovie(MetaItem item) {
  if (item.open?.extraBool('movie') == true) return true;
  if ((item.badge ?? '').toUpperCase() == 'MOVIE') return true;
  if (item.type == 'movie') return true;
  final fmt = (item.badge ?? '').toUpperCase();
  return fmt == 'MOVIE' || item.tmdbMediaType == 'movie';
}

String hubMetaTmdbMediaType(MetaItem item) {
  if (metaIsMovie(item)) return 'movie';
  final hint = (item.tmdbMediaType ?? '').trim().toLowerCase();
  if (hint == 'movie' || hint == 'tv') return hint;
  return 'tv';
}

/// Pack-emitted show-level “Coming soon”. No host heuristics.
bool hubMetaIsUpcoming(MetaItem item, {Iterable<MetaVideo> videos = const []}) {
  return item.upcoming == true;
}

/// Pack-emitted premiere display label.
String? hubMetaPremiereDateLabel(
  MetaItem item, {
  Iterable<MetaVideo> videos = const [],
}) {
  final label = item.premiereLabel.trim();
  return label.isEmpty ? null : label;
}

bool hubVideoNotAiredYet(MetaVideo video) =>
    episodeAirDateInfo(_hubVideoEpisodeMap(video)).notShippedYet;

EpisodeAirDateInfo hubVideoAirDateInfo(MetaVideo video) =>
    episodeAirDateInfo(_hubVideoEpisodeMap(video));

Map<String, dynamic> _hubVideoEpisodeMap(MetaVideo video) => {
      'air_date': video.airDate,
      if (video.aired != null) 'aired': video.aired,
    };

Map<int, List<Map<String, dynamic>>>? hubEpisodeMaps(
  List<MetaVideo> videos,
) {
  if (videos.isEmpty) return null;
  final bySeason = <int, List<Map<String, dynamic>>>{};
  for (final v in videos) {
    final season = v.season ?? 1;
    final epNum = v.episode ?? 1;
    final thumb = resolveAbsoluteCoverUrl(v.thumbnail.trim());
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

Set<int> hubSeasonNumbers(List<MetaVideo> videos) {
  return {for (final v in videos) v.season ?? 1};
}

List<MetaVideo> hubVideosForSeason(List<MetaVideo> videos, int season) {
  return [
    for (final v in videos)
      if ((v.season ?? 1) == season) v,
  ];
}

/// Keep list/seed artwork when `details` returns episodes but empty poster.
MetaItem hubMergeDetailsSeed(
  MetaItem details,
  MetaItem seed,
) {
  final poster = details.poster.trim().isNotEmpty
      ? details.poster
      : seed.poster;
  final background = details.background.trim().isNotEmpty
      ? details.background
      : (seed.background.trim().isNotEmpty
          ? seed.background
          : poster);
  final description = details.description.trim().isNotEmpty
      ? details.description
      : seed.description;
  if (poster == details.poster &&
      background == details.background &&
      description == details.description) {
    return details;
  }
  return details.copyWith(
    poster: poster,
    background: background,
    description: description,
  );
}

bool hubMetaIsIptv(MetaItem item) =>
    item.open?.effectiveExtract.resolveType == 'iptv';

bool hubMetaIsStremio(MetaItem item) {
  final open = item.open;
  if (open == null) return false;
  if (open.surface == 'stremio') return true;
  return open.extraString('stremioAddonBaseUrl') != null;
}

bool hubMetaUsesHomeWatchHistory(MetaItem item) {
  if (item.numericId('tmdb') == null) return false;
  final surface = item.open?.surface;
  return surface == 'tmdb' || surface == null;
}
