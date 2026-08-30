import 'package:forja/shared/catalog/plugin_nav.dart';
import 'package:forja/shared/catalog/protocol.dart';
import 'package:rust/rust.dart';

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

Map<int, List<Map<String, dynamic>>>? hubEpisodeMaps(
  List<CatalogVideo> videos,
) {
  if (videos.isEmpty) return null;
  final bySeason = <int, List<Map<String, dynamic>>>{};
  for (final v in videos) {
    final season = v.season ?? 1;
    final epNum = v.episode ?? 1;
    bySeason.putIfAbsent(season, () => []);
    bySeason[season]!.add({
      'episode_number': epNum,
      'name': v.title.isNotEmpty ? v.title : 'Episode $epNum',
      'still_path': v.thumbnail,
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

String hubImageUrl(String path) {
  final p = path.trim();
  if (p.isEmpty) return '';
  return p.startsWith('http') ? p : TmdbApi.getImageUrl(p);
}

String? hubShellTabIdForPlugin(String pluginId) =>
    PluginNavRegistry.tabIdForPluginSync(pluginId);
