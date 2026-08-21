import 'dart:convert';

import 'package:forja/shared/engine/models.dart';
import 'package:http/http.dart' as http;
import 'package:rust/rust.dart';

/// Resolved cross-catalog ids injected into engine `extract(ctx)` for anime plugins.
class EngineAnimeIdBundle {
  const EngineAnimeIdBundle({
    this.imdbId,
    this.malId,
    this.anilistId,
    this.mappedEpisode,
  });

  final String? imdbId;
  final int? malId;
  final int? anilistId;
  final int? mappedEpisode;

  bool get isEmpty =>
      (malId == null || malId! <= 0) &&
      (anilistId == null || anilistId! <= 0) &&
      (imdbId == null || imdbId!.trim().isEmpty);
}

/// Host resolver: TMDB context → IMDB / MAL / AniList once per plugin run.
abstract final class EngineAnimeIds {
  static const mapApi = 'https://id-mapping-api-malid.hf.space/api/resolve';
  static const armBase = 'https://arm.haglund.dev/api/v2';
  static const jikanBase = 'https://api.jikan.moe/v4/anime';
  static const tmdbKey = '1865f43a0549ca50d341dd9ab8b29f49';

  static const legacyMalPlugins = {
    'hianime',
    'animepahe',
    'anikoto',
    'anizone',
    'senshi',
    'animedunya',
    'animegg',
    'animenosub',
    'anineko',
    'anidbapp',
    '2dhive',
    'animex',
  };

  static const legacyAnilistPlugins = {
    'anibd',
    'reanime',
    'animex',
  };

  static bool pluginNeedsResolve(EnginePlugin plugin) {
    if (plugin.ids.contains('mal') || plugin.ids.contains('anilist')) {
      return true;
    }
    return legacyMalPlugins.contains(plugin.id) ||
        legacyAnilistPlugins.contains(plugin.id);
  }

  static Set<String> requiredKinds(EnginePlugin plugin) {
    if (plugin.ids.isNotEmpty) return plugin.ids.toSet();
    final out = <String>{'title', 'tmdb'};
    if (legacyMalPlugins.contains(plugin.id)) out.add('mal');
    if (legacyAnilistPlugins.contains(plugin.id)) out.add('anilist');
    return out;
  }

  static Future<EngineAnimeIdBundle> resolve({
    required String tmdbId,
    required String mediaType,
    required int season,
    required int episode,
    String? title,
    String? imdbId,
    int? knownMalId,
    int? knownAnilistId,
    required Set<String> kinds,
  }) async {
    final isTv = mediaType == 'tv' || mediaType == 'series';
    var imdb = (imdbId ?? '').trim();
    int? mal = (knownMalId != null && knownMalId > 0) ? knownMalId : null;
    int? anilist =
        (knownAnilistId != null && knownAnilistId > 0) ? knownAnilistId : null;
    int? mappedEp;

    final needMal = kinds.contains('mal');
    final needAnilist = kinds.contains('anilist');
    final needImdb = (needMal && mal == null) || (needAnilist && anilist == null);

    if (needImdb && imdb.isEmpty && tmdbId.isNotEmpty) {
      imdb = await _imdbFromTmdb(tmdbId: tmdbId, isTv: isTv);
    }

    if (needMal && mal == null) {
      if (isTv && imdb.isNotEmpty) {
        final mapped = await _malFromImdb(
          imdbId: imdb,
          season: season,
          episode: episode,
        );
        mal = mapped?.malId;
        mappedEp = mapped?.mappedEpisode;
      }
      if ((mal == null || mal <= 0) && (title ?? '').trim().isNotEmpty) {
        mal = await _malFromJikanTitle(
          title: title!.trim(),
          isMovie: !isTv,
        );
        mappedEp ??= episode;
      }
    }

    if (needAnilist && anilist == null) {
      if (mal != null && mal > 0) {
        anilist = await _anilistFromMal(mal);
      }
      if ((anilist == null || anilist <= 0) && (title ?? '').trim().isNotEmpty) {
        anilist = await _anilistFromTitle(title!.trim());
      }
    }

    return EngineAnimeIdBundle(
      imdbId: imdb.isEmpty ? null : imdb,
      malId: mal,
      anilistId: anilist,
      mappedEpisode: mappedEp ?? episode,
    );
  }

  static Future<String> _imdbFromTmdb({
    required String tmdbId,
    required bool isTv,
  }) async {
    try {
      final path = isTv ? 'tv' : 'movie';
      final uri = Uri.https(
        'api.themoviedb.org',
        '/3/$path/$tmdbId/external_ids',
        {'api_key': tmdbKey},
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return '';
      final data = jsonDecode(res.body);
      if (data is! Map) return '';
      return (data['imdb_id'] ?? '').toString().trim();
    } catch (_) {
      return '';
    }
  }

  static Future<({int malId, int mappedEpisode})?> _malFromImdb({
    required String imdbId,
    required int season,
    required int episode,
  }) async {
    try {
      final uri = Uri.parse(mapApi).replace(
        queryParameters: {
          'id': imdbId,
          's': '$season',
          'e': '$episode',
        },
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body);
      if (data is! Map) return null;
      final rawMal = data['mal_id'];
      final mal = rawMal is int
          ? rawMal
          : rawMal is num
              ? rawMal.toInt()
              : int.tryParse('$rawMal');
      if (mal == null || mal <= 0) return null;
      final rawEp = data['mal_episode'] ?? episode;
      final mapped = rawEp is int
          ? rawEp
          : rawEp is num
              ? rawEp.toInt()
              : int.tryParse('$rawEp') ?? episode;
      return (malId: mal, mappedEpisode: mapped);
    } catch (_) {
      return null;
    }
  }

  static Future<int?> _malFromJikanTitle({
    required String title,
    required bool isMovie,
  }) async {
    try {
      final uri = Uri.parse(jikanBase).replace(
        queryParameters: {
          'q': title,
          'type': isMovie ? 'movie' : 'tv',
          'limit': '1',
        },
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body);
      if (data is! Map) return null;
      final list = data['data'];
      if (list is! List || list.isEmpty) return null;
      final first = list.first;
      if (first is! Map) return null;
      final raw = first['mal_id'];
      final mal = raw is int
          ? raw
          : raw is num
              ? raw.toInt()
              : int.tryParse('$raw');
      if (mal == null || mal <= 0) return null;
      return mal;
    } catch (_) {
      return null;
    }
  }

  static Future<int?> _anilistFromMal(int malId) async {
    try {
      final uri = Uri.parse('$armBase/ids').replace(
        queryParameters: {
          'source': 'myanimelist',
          'id': '$malId',
        },
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body);
      if (data is! Map) return null;
      final raw = data['anilist'];
      final id = raw is int
          ? raw
          : raw is num
              ? raw.toInt()
              : int.tryParse('$raw');
      if (id == null || id <= 0) return null;
      return id;
    } catch (_) {
      return null;
    }
  }

  static Future<int?> _anilistFromTitle(String title) async {
    const query = r'''
query($search: String) {
  Page(page: 1, perPage: 5) {
    media(search: $search, type: ANIME) {
      id
      title { romaji english }
    }
  }
}
''';
    try {
      final raw = await runAnilistQueryJson(
        query,
        variablesJson: jsonEncode({'search': title}),
      );
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final page = decoded['data']?['Page'];
      if (page is! Map) return null;
      final media = page['media'];
      if (media is! List || media.isEmpty) return null;
      final first = media.first;
      if (first is! Map) return null;
      final id = first['id'];
      return id is int
          ? id
          : id is num
              ? id.toInt()
              : int.tryParse('$id');
    } catch (_) {
      return null;
    }
  }
}
