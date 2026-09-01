import 'package:forja/features/my_list/providers/my_list_providers.dart';

int? myListAsInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

String myListItemKind(Map<String, dynamic> item) {
  final simkl = item['_simklType']?.toString();
  if (simkl == 'anime') return 'anime';
  if (simkl == 'shows') return 'tv';
  if (simkl == 'movies') return 'movie';
  final mt = item['mediaType']?.toString() ?? 'movie';
  if (mt == 'anime') return 'anime';
  if (mt == 'tv' || mt == 'series' || mt == 'asian_drama') return 'tv';
  return 'movie';
}

Map<String, dynamic>? simklCardItem(Map<String, dynamic> item) {
  final media = item['show'] ?? item['movie'] ?? item['anime'] ?? item;
  if (media is! Map) return null;
  final ids = media['ids'] is Map
      ? Map<String, dynamic>.from(media['ids'] as Map)
      : const <String, dynamic>{};
  final title = media['title']?.toString();
  if (title == null || title.isEmpty) return null;
  final kind = item['_simklType']?.toString() ?? 'movies';
  final poster = media['poster']?.toString();
  final posterUrl = (poster == null || poster.isEmpty)
      ? ''
      : (poster.startsWith('http')
            ? poster
            : 'https://simkl.in/posters/${poster}_c.jpg');
  final year = media['year']?.toString() ?? '';
  final anilist = myListAsInt(ids['anilist']);
  return {
    'title': title,
    'posterPath': posterUrl,
    'source': 'simkl',
    'mediaType': kind == 'anime'
        ? 'anime'
        : (kind == 'movies' ? 'movie' : 'tv'),
    '_simklType': kind,
    'tmdbId': myListAsInt(ids['tmdb']),
    'anilistId': anilist,
    'imdbId': ids['imdb']?.toString(),
    'voteAverage': 0,
    'releaseDate': year,
  };
}

List<Map<String, dynamic>> filterSimklByLocal(
  List<Map<String, dynamic>> simklItems,
  List<Map<String, dynamic>> allLocal,
  String status,
  Set<String> hiddenKeys,
) {
  final out = <Map<String, dynamic>>[];
  for (final s in simklItems) {
    if (_simklHidden(s, hiddenKeys)) continue;
    final local = _localMatch(allLocal, s);
    if (local != null) {
      final localStatus = local['listStatus']?.toString() ?? 'plantowatch';
      if (localStatus != status) continue;
    }
    out.add(s);
  }
  return out;
}

bool _simklHidden(Map<String, dynamic> item, Set<String> hiddenKeys) {
  if (hiddenKeys.isEmpty) return false;
  return myListItemHideKeys(item).any(hiddenKeys.contains);
}

Map<String, dynamic>? _localMatch(
  List<Map<String, dynamic>> allLocal,
  Map<String, dynamic> item,
) {
  final anilist = item['anilistId'] as int?;
  final kisskh = item['kisskhId'] as int?;
  final tmdb = item['tmdbId'] as int?;
  final mt = item['mediaType']?.toString();
  for (final local in allLocal) {
    if (anilist != null && local['anilistId'] == anilist) return local;
    if (kisskh != null && local['kisskhId'] == kisskh) return local;
    if (tmdb != null && local['tmdbId'] == tmdb) {
      final lmt = local['mediaType']?.toString();
      if (lmt == 'asian_drama') return local;
      if (mt == null || lmt == null || lmt == mt) return local;
      final localNorm = (lmt == 'tv' || lmt == 'series') ? 'tv' : lmt;
      final itemNorm = (mt == 'tv' || mt == 'series' || mt == 'shows')
          ? 'tv'
          : mt;
      if (localNorm == itemNorm) return local;
    }
  }
  return null;
}

List<Map<String, dynamic>> mergeLocalHubs(
  List<Map<String, dynamic>> simklItems,
  List<Map<String, dynamic>> localForStatus,
) {
  final out = [...simklItems];
  final seenAnilist = <int>{
    for (final e in simklItems)
      if (e['anilistId'] is int) e['anilistId'] as int,
  };
  final seenTmdb = <int>{
    for (final e in simklItems)
      if (e['tmdbId'] is int) e['tmdbId'] as int,
  };
  final seenKisskh = <int>{
    for (final e in simklItems)
      if (e['kisskhId'] is int) e['kisskhId'] as int,
  };
  for (final local in localForStatus) {
    final mt = local['mediaType']?.toString();
    if (mt == 'anime') {
      final id = local['anilistId'] as int?;
      if (id != null && seenAnilist.contains(id)) continue;
      out.add(local);
      if (id != null) seenAnilist.add(id);
    } else if (mt == 'asian_drama') {
      final kisskh = local['kisskhId'] as int?;
      final tmdb = local['tmdbId'] as int?;
      if (kisskh != null && seenKisskh.contains(kisskh)) continue;
      if (tmdb != null && seenTmdb.contains(tmdb)) continue;
      out.add(local);
      if (kisskh != null) seenKisskh.add(kisskh);
      if (tmdb != null) seenTmdb.add(tmdb);
    } else {
      final tmdb = local['tmdbId'] as int?;
      if (tmdb != null && seenTmdb.contains(tmdb)) continue;
      out.add(local);
      if (tmdb != null) seenTmdb.add(tmdb);
    }
  }
  return out;
}
