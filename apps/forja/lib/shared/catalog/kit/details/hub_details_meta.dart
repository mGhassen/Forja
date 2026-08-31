import 'package:forja/shared/catalog/hub_cover_urls.dart';
import 'package:forja/shared/catalog/plugin_nav.dart';
import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/shared/catalog/runtime.dart';

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
