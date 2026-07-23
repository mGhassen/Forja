// Anime backend — AniList GraphQL for metadata, Megaplay for streams.
// Parallel race: Anikoto HD-1/HD-2 + Forja stream servers + AllAnime fallbacks.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:rust/rust.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:forja/features/anime/catalog/anime_stream_providers.dart';
import 'package:forja/features/anime/catalog/miruro_pipe_session.dart';
import 'package:forja/shared/playback/provider_runtime_config.dart';
import 'package:forja/shared/player/player/utils.dart';

class AnimeService {
  static final Map<int, String> _tmdbBackdropByAnilistId = {};
  /// AniList Media id → MAL id from relations + Jikan (not AniList `idMal`).
  static final Map<int, int?> _malIdByAnilistId = {};
  static final TmdbApi _tmdb = TmdbApi();
  // ─── GraphQL helper ─────────────────────────────────────────────
  Future<dynamic> _query(String query, [Map<String, dynamic>? vars]) async {
    const maxAttempts = 3;
    Object? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final raw = await runAnilistQueryJson(
          query,
          variablesJson: jsonEncode(vars ?? {}),
        );
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic> && decoded['error'] != null) {
          throw Exception(decoded['error']);
        }
        final data = decoded as Map<String, dynamic>;
        if (data['errors'] != null) {
          throw Exception('AniList: ${data['errors']}');
        }
        return data['data'];
      } catch (e) {
        lastError = e;
        if (attempt < maxAttempts) {
          await Future<void>.delayed(Duration(milliseconds: 250 * attempt));
        }
      }
    }
    throw lastError ?? Exception('AniList query failed');
  }

  /// Catalog / list cards — keep lean (no trailer / streamingEpisodes / cast).
  static const String _mediaFields = '''
    id
    idMal
    title { romaji english native }
    synonyms
    coverImage { large extraLarge color }
    bannerImage
    format
    status
    episodes
    duration
    averageScore
    popularity
    description(asHtml: false)
    genres
    seasonYear
    season
    startDate { year month day }
    endDate { year month day }
    isAdult
    studios(isMain: true) { nodes { name } }
    nextAiringEpisode { episode airingAt timeUntilAiring }
  ''';

  /// Details-only extras (trailer + episode thumbs). Not on list queries.
  static const String _detailsExtraFields = '''
    trailer { id site thumbnail }
    streamingEpisodes { title thumbnail url site }
  ''';

  // ─── Public lists ───────────────────────────────────────────────
  Future<List<AnimeCard>> getSpotlight() => _list(
        sort: 'TRENDING_DESC',
        perPage: 10,
        extraFilter: 'status_in: [RELEASING, FINISHED]',
      );

  /// Prefer TMDB cinematic backdrops for heroes; AniList banner/cover stays fallback.
  Future<List<AnimeCard>> attachTmdbBackdrops(List<AnimeCard> cards) async {
    if (cards.isEmpty) return cards;
    return Future.wait(cards.map(attachTmdbBackdrop));
  }

  Future<AnimeCard> attachTmdbBackdrop(AnimeCard card) async {
    final cached = card.tmdbBackdropUrl ?? _tmdbBackdropByAnilistId[card.id];
    if (cached != null && cached.isNotEmpty) {
      return card.tmdbBackdropUrl == cached
          ? card
          : card.copyWith(tmdbBackdropUrl: cached);
    }
    final url = await resolveTmdbBackdrop(card);
    if (url == null || url.isEmpty) return card;
    _tmdbBackdropByAnilistId[card.id] = url;
    return card.copyWith(tmdbBackdropUrl: url);
  }

  Future<String?> resolveTmdbBackdrop(AnimeCard card) async {
    final query = card.titleEnglish.trim().isNotEmpty
        ? card.titleEnglish.trim()
        : card.titleRomaji.trim();
    if (query.isEmpty) return null;
    try {
      final isMovie = (card.format ?? '').toUpperCase() == 'MOVIE';
      var results = isMovie
          ? await _tmdb.searchMovies(query)
          : await _tmdb.searchTvShows(query);
      if (results.isEmpty) {
        results = isMovie
            ? await _tmdb.searchTvShows(query)
            : await _tmdb.searchMovies(query);
      }
      final best = _pickTmdbMatch(results, card.seasonYear);
      if (best == null || best.backdropPath.isEmpty) return null;
      return TmdbApi.getBackdropUrl(best.backdropPath);
    } catch (e) {
      debugPrint('[AnimeService] TMDB backdrop failed for ${card.id}: $e');
      return null;
    }
  }

  static Movie? _pickTmdbMatch(List<Movie> results, int? seasonYear) {
    Movie? withBackdrop(Iterable<Movie> list) {
      for (final m in list) {
        if (m.backdropPath.isNotEmpty) return m;
      }
      return null;
    }

    int? yearOf(Movie m) {
      if (m.releaseDate.length < 4) return null;
      return int.tryParse(m.releaseDate.substring(0, 4));
    }

    if (seasonYear != null) {
      final exact = withBackdrop(
        results.where((m) => yearOf(m) == seasonYear),
      );
      if (exact != null) return exact;
      final near = withBackdrop(
        results.where((m) {
          final y = yearOf(m);
          return y != null && (y - seasonYear).abs() <= 1;
        }),
      );
      if (near != null) return near;
    }
    return withBackdrop(results);
  }

  Future<List<AnimeCard>> getTrending({int perPage = 20}) =>
      _list(sort: 'TRENDING_DESC', perPage: perPage);

  Future<List<AnimeCard>> getTopAiring({int perPage = 20}) =>
      _list(sort: 'POPULARITY_DESC', perPage: perPage, extraFilter: 'status: RELEASING');

  Future<List<AnimeCard>> getMostPopular({int perPage = 20}) =>
      _list(sort: 'POPULARITY_DESC', perPage: perPage);

  Future<List<AnimeCard>> getMostFavorite({int perPage = 20}) =>
      _list(sort: 'FAVOURITES_DESC', perPage: perPage);

  Future<List<AnimeCard>> getLatestCompleted({int perPage = 20}) =>
      _list(sort: 'END_DATE_DESC', perPage: perPage, extraFilter: 'status: FINISHED');

  Future<List<AnimeCard>> getTopRated({int perPage = 20}) =>
      _list(sort: 'SCORE_DESC', perPage: perPage);

  Future<List<AnimeCard>> getTop10Today({int perPage = 10}) =>
      _list(sort: 'TRENDING_DESC', perPage: perPage);

  Future<List<AnimeCard>> getRecentEpisodes({int perPage = 20}) =>
      _list(sort: 'UPDATED_AT_DESC', perPage: perPage, extraFilter: 'status: RELEASING');

  Future<List<AnimeCard>> _list({
    required String sort,
    int page = 1,
    int perPage = 20,
    String extraFilter = '',
  }) async {
    final filter = extraFilter.isNotEmpty ? ', $extraFilter' : '';
    final q = '''
      query (\$page: Int, \$perPage: Int) {
        Page(page: \$page, perPage: \$perPage) {
          media(type: ANIME, sort: [$sort], isAdult: false$filter) {
            $_mediaFields
          }
        }
      }
    ''';
    final data = await _query(q, {'page': page, 'perPage': perPage});
    final list = (data['Page']['media'] as List).cast<Map<String, dynamic>>();
    return list.map(AnimeCard.fromJson).toList();
  }

  Future<List<AnimeCard>> search(String term, {int page = 1, int perPage = 30}) async {
    if (term.trim().isEmpty) return [];
    final q = '''
      query (\$q: String, \$page: Int, \$perPage: Int) {
        Page(page: \$page, perPage: \$perPage) {
          media(type: ANIME, search: \$q, sort: [SEARCH_MATCH, POPULARITY_DESC]) {
            $_mediaFields
          }
        }
      }
    ''';
    final data = await _query(q, {'q': term, 'page': page, 'perPage': perPage});
    return (data['Page']['media'] as List)
        .cast<Map<String, dynamic>>()
        .map(AnimeCard.fromJson)
        .toList();
  }

  Future<AnimeCard> getDetails(int anilistId) async {
    final q = '''
      query (\$id: Int) {
        Media(id: \$id, type: ANIME) {
          $_mediaFields
          $_detailsExtraFields
        }
      }
    ''';
    final data = await _query(q, {'id': anilistId});
    return AnimeCard.fromJson(data['Media'] as Map<String, dynamic>);
  }

  /// MAIN + SUPPORTING characters (capped). Separate AniList call.
  Future<List<Map<String, String>>> getCharacters(
    int anilistId, {
    int perPage = 12,
  }) async {
    final q = '''
      query (\$id: Int) {
        Media(id: \$id, type: ANIME) {
          characters(sort: [ROLE, RELEVANCE, ID], perPage: $perPage) {
            edges {
              role
              node {
                name { full }
                image { large }
              }
              voiceActors(language: JAPANESE, sort: [RELEVANCE, ID]) {
                name { full }
              }
            }
          }
        }
      }
    ''';
    final data = await _query(q, {'id': anilistId});
    final edges =
        (data['Media']?['characters']?['edges'] as List?) ?? const [];
    final out = <Map<String, String>>[];
    for (final e in edges) {
      if (e is! Map) continue;
      final node = e['node'];
      if (node is! Map) continue;
      final name = (node['name']?['full'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      final image = (node['image']?['large'] ?? '').toString().trim();
      final role = (e['role'] ?? '').toString();
      final vas = (e['voiceActors'] as List?) ?? const [];
      String character = role == 'MAIN' ? 'Main' : 'Supporting';
      if (vas.isNotEmpty && vas.first is Map) {
        final va = (vas.first['name']?['full'] ?? '').toString().trim();
        if (va.isNotEmpty) character = va;
      }
      out.add({
        'name': name,
        'character': character,
        'profilePath': image,
      });
    }
    return out;
  }

  /// Production staff (capped). Separate AniList call.
  Future<List<Map<String, String>>> getStaff(
    int anilistId, {
    int perPage = 12,
  }) async {
    final q = '''
      query (\$id: Int) {
        Media(id: \$id, type: ANIME) {
          staff(sort: [RELEVANCE, ID], perPage: $perPage) {
            edges {
              role
              node {
                name { full }
                image { large }
              }
            }
          }
        }
      }
    ''';
    final data = await _query(q, {'id': anilistId});
    final edges = (data['Media']?['staff']?['edges'] as List?) ?? const [];
    final out = <Map<String, String>>[];
    for (final e in edges) {
      if (e is! Map) continue;
      final node = e['node'];
      if (node is! Map) continue;
      final name = (node['name']?['full'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      final image = (node['image']?['large'] ?? '').toString().trim();
      final role = (e['role'] ?? '').toString().trim();
      out.add({
        'name': name,
        'character': role,
        'profilePath': image,
      });
    }
    return out;
  }

  /// AniList user recommendations (capped). Separate call — not franchise Related.
  Future<List<AnimeCard>> getRecommendations(
    int anilistId, {
    int perPage = 12,
  }) async {
    final q = '''
      query (\$id: Int) {
        Media(id: \$id, type: ANIME) {
          recommendations(sort: [RATING_DESC], perPage: $perPage) {
            nodes {
              mediaRecommendation {
                $_mediaFields
              }
            }
          }
        }
      }
    ''';
    final data = await _query(q, {'id': anilistId});
    final nodes =
        (data['Media']?['recommendations']?['nodes'] as List?) ?? const [];
    final out = <AnimeCard>[];
    final seen = <int>{anilistId};
    for (final n in nodes) {
      if (n is! Map) continue;
      final rec = n['mediaRecommendation'];
      if (rec is! Map) continue;
      final card = AnimeCard.fromJson(Map<String, dynamic>.from(rec));
      if (!seen.add(card.id)) continue;
      out.add(card);
    }
    return out;
  }

  /// AniList relation edges with [relationType] preserved.
  ///
  /// Skips manga SOURCE / CHARACTER crossovers (noisy: Toriko, DBZ on One Piece).
  /// Keeps films, specials, OVAs, spin-offs, alt versions, and leftover
  /// PREQUEL/SEQUEL entries that are not on the TV season spine.
  Future<List<AnimeRelation>> getRelations(int anilistId) async {
    final q = '''
      query (\$id: Int) {
        Media(id: \$id, type: ANIME) {
          relations {
            edges {
              relationType(version: 2)
              node { $_mediaFields type }
            }
          }
        }
      }
    ''';
    const animeFormats = {
      'TV', 'TV_SHORT', 'MOVIE', 'OVA', 'ONA', 'SPECIAL',
    };
    // Franchise material users open from details — not list noise.
    const keepTypes = {
      'SIDE_STORY',
      'SUMMARY',
      'ALTERNATIVE',
      'SPIN_OFF',
      'SEQUEL',
      'PREQUEL',
      'PARENT',
      'OTHER',
      'COMPILATION',
      'CONTAINS',
    };
    const typeRank = {
      'SIDE_STORY': 0,
      'SUMMARY': 1,
      'ALTERNATIVE': 2,
      'SPIN_OFF': 3,
      'SEQUEL': 4,
      'PREQUEL': 5,
      'PARENT': 6,
      'COMPILATION': 7,
      'CONTAINS': 8,
      'OTHER': 9,
    };
    final data = await _query(q, {'id': anilistId});
    final edges = (data['Media']?['relations']?['edges'] as List?) ?? [];
    final out = <AnimeRelation>[];
    final seen = <int>{};
    for (final e in edges) {
      if (e is! Map) continue;
      final type = (e['relationType'] ?? '').toString();
      if (!keepTypes.contains(type)) continue;
      final node = e['node'];
      if (node is! Map) continue;
      if ((node['type'] ?? 'ANIME').toString() != 'ANIME') continue;
      final fmt = node['format'] as String?;
      if (fmt == null || !animeFormats.contains(fmt)) continue;
      final id = node['id'];
      if (id is! int || !seen.add(id)) continue;
      out.add(AnimeRelation(
        relationType: type,
        anime: AnimeCard.fromJson(Map<String, dynamic>.from(node)),
      ));
    }
    out.sort((a, b) {
      final ra = typeRank[a.relationType] ?? 99;
      final rb = typeRank[b.relationType] ?? 99;
      if (ra != rb) return ra.compareTo(rb);
      final ya = a.anime.seasonYear ?? 0;
      final yb = b.anime.seasonYear ?? 0;
      if (ya != yb) return ya.compareTo(yb);
      return a.anime.displayTitle.compareTo(b.anime.displayTitle);
    });
    return out;
  }

  /// Walk PREQUEL/SEQUEL/PARENT continuity from this anime and return the
  /// ordered TV season spine (AniList stores each cour as a separate Media).
  ///
  /// Movies (and multi-ep ONA cours) are **walked as bridges** when they sit
  /// between TV seasons (Youjo Senki S1 → Movie → S2) but are **not** emitted
  /// into the season rail — films/specials stay under Related.
  ///
  /// 1-ep ONA prequels (One Piece → MONSTERS) are skipped entirely so they
  /// never pollute the spine. SIDE_STORY is not walked.
  ///
  /// Result is ordered by start date (fallback: walk order) and always
  /// includes the input when it is itself a season entry. Returns just the
  /// input if no TV neighbors exist.
  Future<List<AnimeCard>> getSeasons(int anilistId) async {
    const q = r'''
      query ($id: Int) {
        Media(id: $id, type: ANIME) {
          id title { romaji english } format episodes status
          coverImage { large extraLarge color }
          startDate { year month day }
          relations {
            edges {
              relationType(version: 2)
              node {
                id type format
                title { romaji english }
                episodes status
                coverImage { large extraLarge color }
                startDate { year month day }
              }
            }
          }
        }
      }
    ''';

    final fetched = <int, Map<String, dynamic>>{};

    Future<Map<String, dynamic>?> fetch(int id) async {
      if (fetched.containsKey(id)) return fetched[id];
      try {
        final data = await _query(q, {'id': id});
        final media = data['Media'];
        if (media is Map<String, dynamic>) {
          fetched[id] = media;
          return media;
        }
      } catch (e) {
        debugPrint('[Seasons] fetch $id failed: $e');
      }
      return null;
    }

    bool canWalk(Map node) {
      if ((node['type'] ?? '') != 'ANIME') return false;
      final fmt = (node['format'] ?? '').toString();
      if (fmt == 'TV' || fmt == 'TV_SHORT') return true;
      // Bridge: film between TV cours (Youjo Senki).
      if (fmt == 'MOVIE') return true;
      // Multi-ep ONA cour (Dungeon Meshi S2) — not 1-ep specials.
      if (fmt == 'ONA') {
        final eps = node['episodes'];
        return eps is! int || eps > 1;
      }
      return false;
    }

    bool isSeasonEntry(Map node) {
      final fmt = (node['format'] ?? '').toString();
      if (fmt == 'TV' || fmt == 'TV_SHORT') return true;
      if (fmt == 'ONA') {
        final eps = node['episodes'];
        return eps is! int || eps > 1;
      }
      return false;
    }

    int startKey(Map node) {
      final d = node['startDate'];
      if (d is! Map) return 0;
      final y = (d['year'] as num?)?.toInt() ?? 0;
      final m = (d['month'] as num?)?.toInt() ?? 0;
      final day = (d['day'] as num?)?.toInt() ?? 0;
      return y * 10000 + m * 100 + day;
    }

    // Prefer TV neighbors over movie bridges when several PREQUEL/SEQUEL
    // edges exist (Movie → S1 TV + Pasta ONA both PREQUEL).
    int walkRank(Map node) {
      final fmt = (node['format'] ?? '').toString();
      if (fmt == 'TV' || fmt == 'TV_SHORT') return 0;
      if (fmt == 'ONA') return 1;
      if (fmt == 'MOVIE') return 2;
      return 9;
    }

    List<int> walkNeighbors(Map<String, dynamic> media) {
      const wanted = {'PREQUEL', 'SEQUEL', 'PARENT'};
      final edges = (media['relations']?['edges'] as List?) ?? const [];
      final scored = <({int id, int rank})>[];
      for (final e in edges) {
        if (e is! Map) continue;
        final type = (e['relationType'] ?? '').toString();
        if (!wanted.contains(type)) continue;
        final node = e['node'];
        if (node is! Map) continue;
        if (!canWalk(node)) continue;
        final id = node['id'];
        if (id is! int) continue;
        scored.add((id: id, rank: walkRank(node)));
      }
      scored.sort((a, b) => a.rank.compareTo(b.rank));
      return scored.map((s) => s.id).toList();
    }

    final seed = await fetch(anilistId);
    if (seed == null) {
      try {
        return [await getDetails(anilistId)];
      } catch (_) {
        return const [];
      }
    }

    // BFS the continuity component (TV + movie bridges), not a single path —
    // visiting bridges while walking back must not block walking forward.
    final queue = <int>[anilistId];
    final seen = <int>{anilistId};
    while (queue.isNotEmpty) {
      final id = queue.removeAt(0);
      final media = await fetch(id);
      if (media == null) continue;
      for (final n in walkNeighbors(media)) {
        if (!seen.add(n)) continue;
        queue.add(n);
      }
    }

    final seasons = seen
        .map((id) => fetched[id])
        .whereType<Map<String, dynamic>>()
        .where(isSeasonEntry)
        .toList()
      ..sort((a, b) {
        final ka = startKey(a);
        final kb = startKey(b);
        if (ka != kb) return ka.compareTo(kb);
        return ((a['id'] as int?) ?? 0).compareTo((b['id'] as int?) ?? 0);
      });

    if (seasons.isEmpty) {
      return [AnimeCard.fromJson(seed)];
    }
    // Opening a film that bridges TV seasons: still show the TV rail.
    return seasons.map(AnimeCard.fromJson).toList();
  }

  Future<List<AnimeCard>> browse({
    String? genre,
    int? year,
    String? season,
    String? format,
    String? status,
    String sort = 'POPULARITY_DESC',
    int page = 1,
    int perPage = 30,
  }) async {
    final filters = <String>[];
    if (genre != null && genre.isNotEmpty) filters.add('genre_in: ["$genre"]');
    if (year != null) filters.add('seasonYear: $year');
    if (season != null && season.isNotEmpty) filters.add('season: $season');
    if (format != null && format.isNotEmpty) filters.add('format: $format');
    if (status != null && status.isNotEmpty) filters.add('status: $status');
    final extra = filters.isNotEmpty ? ', ${filters.join(', ')}' : '';

    // AniList gates the "Hentai" genre behind isAdult: true.
    final isAdult = genre != null && genre.toLowerCase() == 'hentai';

    final q = '''
      query (\$page: Int, \$perPage: Int) {
        Page(page: \$page, perPage: \$perPage) {
          media(type: ANIME, sort: [$sort], isAdult: $isAdult$extra) {
            $_mediaFields
          }
        }
      }
    ''';
    final data = await _query(q, {'page': page, 'perPage': perPage});
    return (data['Page']['media'] as List)
        .cast<Map<String, dynamic>>()
        .map(AnimeCard.fromJson)
        .toList();
  }

  // ─── Episodes (real IDs from Anikoto API) ───────────────────────
  // Cache: AniList ID -> resolved AnikotoSeries (with episode embed IDs)
  final Map<int, AnikotoSeries?> _anikotoCache = {};

  /// Reject movie/OVA stubs when AniList expects a long series.
  bool _anikotoEpisodeCountPlausible(int got, int expected) {
    if (got <= 0) return false;
    if (expected <= 0) return true;
    return got >= (expected / 2).ceil();
  }

  Future<AnikotoSeries?> resolveAnikoto(AnimeCard anime) async {
    final expected = anime.episodes ?? 0;
    final cached = _anikotoCache[anime.id];
    if (cached != null) {
      if (_anikotoEpisodeCountPlausible(cached.episodes.length, expected) &&
          cached.slug.trim().isNotEmpty) {
        return cached;
      }
      // Drop movie/OVA stub or pre-slug cache entries.
      _anikotoCache.remove(anime.id);
    }
    AnikotoSeries? s;
    try {
      final data = await anikotoResolveSeries(
        anilistId: anime.id,
        titleCandidates: anime.resolveTitleCandidates(),
        mediaFormat: anime.format ?? '',
        expectedEpisodes: expected,
      );
      if (data != null &&
          data.episodes.isNotEmpty &&
          _anikotoEpisodeCountPlausible(data.episodes.length, expected)) {
        s = AnikotoSeries(
          id: data.id,
          slug: data.slug,
          aniId: data.aniId,
          episodes: data.episodes
              .map(
                (e) => AnikotoEpisode(
                  id: e.id,
                  number: e.number,
                  title: e.title,
                  embedId: e.embedId,
                ),
              )
              .toList(),
        );
      } else if (data != null && kDebugMode) {
        debugPrint(
          '[Anikoto] rejected stub id=${data.id} '
          'eps=${data.episodes.length} expected=$expected',
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Anikoto] resolve failed: $e');
    }
    // Only cache hits — misses retry after getDetails fills episodes.
    if (s != null) _anikotoCache[anime.id] = s;
    return s;
  }

  Future<List<AnimeEpisode>> getEpisodes(AnimeCard anime) async {
    // AniList only — never crawl Anikoto here (HTML probe spam / block risk).
    // Playable Anikoto ids resolve lazily in the player on Play.
    // streamingEpisodes live on details payloads only — pass getDetails result
    // when thumbs matter; list cards synthesize without them.
    AnimeCard fresh = anime;
    final hasCount = (anime.episodes ?? 0) > 0 ||
        anime.nextAiringEpisode?['episode'] != null;
    if (!hasCount) {
      try {
        fresh = await getDetails(anime.id);
      } catch (_) {}
    }
    final thumbMap = _buildEpisodeThumbnailMap(fresh.streamingEpisodes);

    final cached = _anikotoCache[anime.id];
    final expected = fresh.episodes ?? anime.episodes ?? 0;
    if (cached != null &&
        cached.episodes.isNotEmpty &&
        _anikotoEpisodeCountPlausible(cached.episodes.length, expected)) {
      return cached.episodes
          .map((e) => AnimeEpisode(
                number: e.number,
                title: e.title.isEmpty ? 'Episode ${e.number}' : e.title,
                aired: true,
                thumbnail: thumbMap[e.number],
              ))
          .toList();
    }

    return _synthesizeEpisodes(fresh, anime, thumbMap);
  }

  List<AnimeEpisode> _synthesizeEpisodes(
    AnimeCard fresh,
    AnimeCard fallback,
    Map<int, String> thumbMap,
  ) {
    final count = fresh.episodes ??
        fallback.episodes ??
        fresh.nextAiringEpisode?['episode'] ??
        fallback.nextAiringEpisode?['episode'];
    final n = (count is int && count > 0) ? count : 1;
    final airedNow = fresh.nextAiringEpisode?['episode'];
    final maxAvailable =
        (airedNow is int && airedNow > 1) ? (airedNow - 1) : n;
    return List.generate(
      n,
      (i) => AnimeEpisode(
        number: i + 1,
        title: 'Episode ${i + 1}',
        aired: (i + 1) <= maxAvailable,
        thumbnail: thumbMap[i + 1],
      ),
    );
  }

  /// Tries to parse "Episode N" / "EN" from the title; falls back to
  /// sequential ordering (1-indexed) when no number is found.
  Map<int, String> _buildEpisodeThumbnailMap(
      List<Map<String, String>> streamEps) {
    final out = <int, String>{};
    if (streamEps.isEmpty) return out;
    final reEp = RegExp(r'(?:episode|ep|e)\s*(\d+)', caseSensitive: false);
    var seq = 1;
    for (final m in streamEps) {
      final thumb = (m['thumbnail'] ?? '').trim();
      if (thumb.isEmpty) {
        seq++;
        continue;
      }
      final title = m['title'] ?? '';
      final match = reEp.firstMatch(title);
      final num = match != null
          ? int.tryParse(match.group(1)!) ?? seq
          : seq;
      out[num] = thumb;
      seq++;
    }
    return out;
  }

  // ─── Stream embed URLs ─────────────────────────────────────────
  // Megaplay: AniList + MAL id paths only (megaplay.buzz/api). Never
  // Anikoto title→embedId — wrong show with no recovery signal.

  /// VidLink anime embed — MAL id required (`vidlink.pro` docs).
  String _vidlinkAnimeEmbed({
    required int malId,
    required int episode,
    required String lang,
  }) {
    return 'https://vidlink.pro/anime/$malId/$episode/$lang?fallback=true';
  }

  /// MAL id for [anilistId] via ID relations + Jikan confirm.
  ///
  /// Does **not** use AniList GraphQL `idMal` (stale duplicates). Relations
  /// DB maps AniList→MAL; Jikan confirms the id exists on MAL.
  Future<int?> resolveMalId(int anilistId) async {
    if (anilistId <= 0) return null;
    if (_malIdByAnilistId.containsKey(anilistId)) {
      return _malIdByAnilistId[anilistId];
    }
    try {
      final mal = await _malIdFromRelations(anilistId);
      if (mal == null || mal <= 0) {
        _malIdByAnilistId[anilistId] = null;
        return null;
      }
      final confirmed = await _confirmMalIdOnJikan(mal);
      _malIdByAnilistId[anilistId] = confirmed;
      return confirmed;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AnimeService] resolveMalId($anilistId) failed: $e');
      }
      _malIdByAnilistId[anilistId] = null;
      return null;
    }
  }

  Future<int?> _malIdFromRelations(int anilistId) async {
    const urls = [
      'https://relations.yuna.moe/api/v2/ids?source=anilist&id=',
      'https://arm.haglund.dev/api/v2/ids?source=anilist&id=',
    ];
    for (final base in urls) {
      try {
        final res = await animeHttp(
          'GET',
          '$base$anilistId',
          maxRetries: 0,
          timeoutSecs: 10,
        );
        if (res.status != 200) continue;
        final body = res.body.trim();
        if (body.isEmpty || body == 'null') continue;
        final j = jsonDecode(body);
        if (j is! Map) continue;
        final raw = j['myanimelist'];
        final id = raw is int
            ? raw
            : raw is num
                ? raw.toInt()
                : int.tryParse('$raw');
        if (id != null && id > 0) return id;
      } catch (_) {}
    }
    return null;
  }

  Future<int?> _confirmMalIdOnJikan(int malId) async {
    final res = await animeHttp(
      'GET',
      'https://api.jikan.moe/v4/anime/$malId',
      maxRetries: 0,
      timeoutSecs: 10,
    );
    if (res.status != 200) return null;
    final j = jsonDecode(res.body);
    if (j is! Map) return null;
    final data = j['data'];
    if (data is! Map) return null;
    final raw = data['mal_id'];
    final id = raw is int
        ? raw
        : raw is num
            ? raw.toInt()
            : int.tryParse('$raw');
    if (id == null || id <= 0) return null;
    return id;
  }

  /// Build Megaplay + Miruro/AllAnime/VidNest/VidLink embeds for an episode.
  ///
  /// Megaplay: card AniList id → `/stream/ani/…`, plus MAL → `/stream/mal/…`
  /// when [malId] is set (from [resolveMalId], not AniList `idMal`).
  /// VidNest / Miruro: card AniList id only (no Anikoto remap).
  /// VidLink: MAL id only.
  /// AniKoto site: only when [series] has a slug (pinned Anikoto resolve).
  List<AnimeEmbed> buildAllEmbeds({
    required int anilistId,
    required int episode,
    AnikotoSeries? series,
    String? category, // null = all 4; else filtered pair
    List<String> animeTitles = const [],
    bool isAdult = false,
    int? malId,
  }) {
    final mega = ProviderRuntimeConfig.instance.megaplay;
    final all = <AnimeEmbed>[
      for (final cat in const ['sub', 'dub'])
        AnimeEmbed(
          label: AnimeStreamProviders.displayName('megaplay'),
          server: 'megaplay',
          category: cat,
          url: mega.buildAniUrl(
            anilistId: anilistId,
            episode: episode,
            lang: cat,
          ),
        ),
    ];
    final mal = malId ?? 0;
    if (mal > 0) {
      for (final cat in const ['sub', 'dub']) {
        all.add(AnimeEmbed(
          label: AnimeStreamProviders.displayName('megaplay'),
          server: 'megaplay',
          category: cat,
          url: mega.buildMalUrl(
            malId: mal,
            episode: episode,
            lang: cat,
          ),
        ));
      }
    }
    // AniKoto site Ajax — only when slug already resolved (pinned Anikoto).
    final slug = series?.slug.trim() ?? '';
    if (slug.isNotEmpty) {
      for (final cat in const ['sub', 'dub']) {
        all.add(AnimeEmbed(
          label: AnimeStreamProviders.displayName('anikoto'),
          server: 'anikoto',
          category: cat,
          url: 'anikoto://watch/$slug/$episode/$cat',
        ));
      }
    }
    // VidLink — MAL embed (same host sniff as movie/TV VidLink).
    if (mal > 0) {
      for (final cat in const ['sub', 'dub']) {
        all.add(AnimeEmbed(
          label: AnimeStreamProviders.displayName('vidlink'),
          server: 'vidlink',
          category: cat,
          url: _vidlinkAnimeEmbed(malId: mal, episode: episode, lang: cat),
        ));
      }
    }
    // Miruro — AniList id from the card only.
    for (final cat in const ['sub', 'dub']) {
      for (final prov in AnimeStreamProviders.miruroRaceProviders) {
        all.add(AnimeEmbed(
          label: AnimeStreamProviders.displayName('miruro:$prov'),
          server: 'miruro',
          category: cat,
          url: 'miruro://anilist/$anilistId/$episode/$cat/$prov',
        ));
      }
    }
    // AllAnime (allmanga.to) — title search (no AniList/MAL key upstream).
    final titles = animeTitles
        .where((t) => t.trim().isNotEmpty)
        .map((t) => Uri.encodeComponent(t.trim()))
        .join(',');
    if (titles.isNotEmpty) {
      for (final cat in const ['sub', 'dub']) {
        for (final prov in allAnimeKnownProviders) {
          all.add(AnimeEmbed(
            label: AnimeStreamProviders.displayName('allanime:$prov'),
            server: 'allanime',
            category: cat,
            url: 'allanime://search/$episode/$cat/$prov?t=$titles',
          ));
        }
      }
    }
    // VidNest — card AniList id only (never Anikoto ani_id remap).
    for (final cat in const ['sub', 'dub']) {
      for (final prov in vidnestKnownProviders) {
        all.add(AnimeEmbed(
          label: AnimeStreamProviders.displayName('vidnest:$prov'),
          server: 'vidnest',
          category: cat,
          url: 'vidnest://anilist/$anilistId/$episode/$cat/$prov',
        ));
      }
    }
    // WatchHentai — only for adult titles. Single embed; the extractor
    // searches watchhentai.net's catalog for any of the provided titles.
    if (isAdult && titles.isNotEmpty) {
      all.add(AnimeEmbed(
        label: AnimeStreamProviders.displayName('watchhentai'),
        server: 'watchhentai',
        category: 'sub',
        url: 'watchhentai://discover/$episode?t=$titles',
      ));
      all.add(AnimeEmbed(
        label: AnimeStreamProviders.displayName('hentaini'),
        server: 'hentaini',
        category: 'sub',
        url: 'hentaini://discover/$episode?t=$titles',
      ));
    }
    if (category == null) return all;
    return all.where((e) => e.category == category).toList();
  }

  /// Referer to spoof when extracting Megaplay embeds. They block
  /// direct page loads — extraction only works when this header is present.
  static String get embedReferer =>
      ProviderRuntimeConfig.instance.megaplay.scrapeReferer;

  /// Direct HTTP extractor for megaplay.buzz embeds.
  ///
  ///   1. Prefer catalog id from `/stream/s-2/{id}/{lang}` → getSources
  ///   2. Else scrape HTML `data-id` (often missing — pages return 410)
  ///   3. GET /stream/getSources?id={id} → JSON { sources:{file}, tracks:[] }
  /// Resolve one or more playable URLs for [embed]. Miruro may return several
  /// CDN mirrors per provider; other servers return at most one.
  Future<List<AnimeStreamResult>> extractDirectCandidates(AnimeEmbed embed) async {
    if (embed.server == 'miruro') {
      return _extractMiruroAll(embed);
    }
    if (embed.server == 'anikoto') {
      return _extractAnikotoSite(embed);
    }
    final one = await extractDirect(embed);
    return one != null ? [one] : const [];
  }

  Future<AnimeStreamResult?> extractDirect(AnimeEmbed embed) async {
    if (embed.server == 'miruro') {
      return _extractMiruro(embed);
    }
    if (embed.server == 'anikoto') {
      final hits = await _extractAnikotoSite(embed);
      return hits.isEmpty ? null : hits.first;
    }
    if (embed.server == 'allanime') {
      return _extractAllAnime(embed);
    }
    if (embed.server == 'animerealms') {
      return _extractAnimeRealms(embed);
    }
    if (embed.server == 'watchhentai') {
      return _extractWatchHentai(embed);
    }
    if (embed.server == 'hentaini') {
      return _extractHentaini(embed);
    }
    if (embed.server == 'vidnest') {
      return _extractVidnest(embed);
    }
    try {
      final rust = await directEmbedExtract(
        embedUrl: embed.url,
        referer: embedReferer,
      );
      if (rust == null) return null;
      return AnimeStreamResult(
        url: rust.url,
        referer: rust.referer,
        origin: rust.origin,
        tracks: rust.tracks
            .map(
              (t) => AnimeTrack(
                url: t.url,
                label: t.label,
                isDefault: t.isDefault,
              ),
            )
            .toList(),
      );
    } catch (e, st) {
      if (kDebugMode) debugPrint('[extractDirect] error: $e\n$st');
      return null;
    }
  }

  Future<List<AnimeStreamResult>> _extractAnikotoSite(AnimeEmbed embed) async {
    final m = RegExp(r'^anikoto://watch/([^/]+)/(\d+)/(sub|dub)$')
        .firstMatch(embed.url.trim());
    if (m == null) return const [];
    try {
      final rust = await anikotoSiteStreams(
        slug: Uri.decodeComponent(m.group(1)!),
        episode: int.parse(m.group(2)!),
        category: m.group(3)!,
      );
      return rust.map(_extractorToAnimeResult).toList();
    } catch (e, st) {
      if (kDebugMode) debugPrint('[extractAnikotoSite] error: $e\n$st');
      return const [];
    }
  }

  Future<List<AnimeStreamResult>> _extractMiruroAll(AnimeEmbed embed) async {
    final m = RegExp(r'^miruro://anilist/(\d+)/(\d+)/(sub|dub)/([a-z0-9]+)$')
        .firstMatch(embed.url);
    if (m == null) return const [];

    final resolved = await miruroResolveWithCfFallback(
      anilistId: int.parse(m.group(1)!),
      episodeNumber: int.parse(m.group(2)!),
      category: m.group(3)!,
      provider: m.group(4)!,
      fetchPipeViaWebView: MiruroPipeSession.instance.get,
    );
    return resolved.streams.map(_extractorToAnimeResult).toList();
  }

  AnimeStreamResult _extractorToAnimeResult(AnimeExtractorStreamResult res) {
    return AnimeStreamResult(
      url: res.url,
      referer: res.referer,
      origin: res.origin,
      streamLabel: res.streamLabel,
      tracks: res.tracks
          .map((t) => AnimeTrack(
                url: t.url,
                label: t.label.isNotEmpty
                    ? t.label
                    : (t.language.isNotEmpty ? t.language : 'Unknown'),
                isDefault: t.isDefault,
              ))
          .toList(),
    );
  }

  Future<AnimeStreamResult?> _extractMiruro(AnimeEmbed embed) async {
    final all = await _extractMiruroAll(embed);
    return all.isEmpty ? null : all.first;
  }

  Future<AnimeStreamResult?> _extractAllAnime(AnimeEmbed embed) async {
    final m = RegExp(r'^allanime://search/(\d+)/(sub|dub)/([^?]+)\?t=(.+)$')
        .firstMatch(embed.url);
    if (m == null) return null;
    final ep = int.parse(m.group(1)!);
    final cat = m.group(2)!;
    final provider = m.group(3)!;
    final titles = m
        .group(4)!
        .split(',')
        .map(Uri.decodeComponent)
        .where((t) => t.isNotEmpty)
        .toList();
    if (titles.isEmpty) return null;

    final res = await allAnimeExtractWithProvider(
      titleCandidates: titles,
      episodeNumber: ep,
      category: cat,
      provider: provider,
    );
    if (res == null) return null;
    return _extractorToAnimeResult(res);
  }

  // AnimeRealms — sentinel URL:
  //   animerealms://anilist/{anilistId}/{episode}/{provider}
  Future<AnimeStreamResult?> _extractAnimeRealms(AnimeEmbed embed) async {
    final m = RegExp(r'^animerealms://anilist/(\d+)/(\d+)/([a-z0-9-]+)$')
        .firstMatch(embed.url);
    if (m == null) return null;
    final res = await animeRealmsExtractWithProvider(
      anilistId: int.parse(m.group(1)!),
      episodeNumber: int.parse(m.group(2)!),
      provider: m.group(3)!,
    );
    if (res == null) return null;
    return _extractorToAnimeResult(res);
  }

  Future<AnimeStreamResult?> _extractVidnest(AnimeEmbed embed) async {
    final m = RegExp(r'^vidnest://anilist/(\d+)/(\d+)/(sub|dub)/([a-z0-9]+)$')
        .firstMatch(embed.url);
    if (m == null) return null;
    final res = await vidnestExtractWithProvider(
      anilistId: int.parse(m.group(1)!),
      episodeNumber: int.parse(m.group(2)!),
      category: m.group(3)!,
      provider: m.group(4)!,
    );
    if (res == null) return null;
    return _extractorToAnimeResult(res);
  }

  Future<AnimeStreamResult?> _extractWatchHentai(AnimeEmbed embed) async {
    final m = RegExp(r'^watchhentai://discover/(\d+)\?t=(.+)$')
        .firstMatch(embed.url);
    if (m == null) return null;
    final ep = int.parse(m.group(1)!);
    final titles = m
        .group(2)!
        .split(',')
        .map(Uri.decodeComponent)
        .where((t) => t.isNotEmpty)
        .toList();
    if (titles.isEmpty) return null;
    final res = await watchHentaiExtract(
      titleCandidates: titles,
      episode: ep,
    );
    if (res == null) return null;
    return _extractorToAnimeResult(res);
  }

  Future<AnimeStreamResult?> _extractHentaini(AnimeEmbed embed) async {
    final m = RegExp(r'^hentaini://discover/(\d+)\?t=(.+)$')
        .firstMatch(embed.url);
    if (m == null) return null;
    final ep = int.parse(m.group(1)!);
    final titles = m
        .group(2)!
        .split(',')
        .map(Uri.decodeComponent)
        .where((t) => t.isNotEmpty)
        .toList();
    if (titles.isEmpty) return null;
    final res = await hentainiExtract(
      titleCandidates: titles,
      episode: ep,
    );
    if (res == null) return null;
    return _extractorToAnimeResult(res);
  }


  // ─── Stream source preference (per anime + category) ────────────
  static const _sourcePrefKey = 'enma_anime_source_v1';
  static const _sourcePrefMaxEntries = 40;
  static const _sourcePrefMaxAge = Duration(days: 60);

  Future<AnimeStreamPref?> preferredSource({
    required int animeId,
    required String category,
  }) async {
    final list = await _loadSourcePrefs();
    for (final e in list) {
      if (_prefAnimeId(e) == animeId && e['cat'] == category) {
        final key = e['key'] as String?;
        if (key == null || key.isEmpty) return null;
        // vidwish.live redirects to megaplay.buzz — alias retired.
        final normalized = key == 'vidwish' ? 'megaplay' : key;
        return AnimeStreamPref(
          sourceKey: normalized,
          sourceTitle: e['title'] as String?,
        );
      }
    }
    return null;
  }

  Future<void> recordPreferredSource({
    required int animeId,
    required String category,
    required String sourceKey,
    String? sourceTitle,
  }) async {
    var list = await _loadSourcePrefs();
    list.removeWhere(
      (e) => _prefAnimeId(e) == animeId && e['cat'] == category,
    );
    list.insert(
      0,
      {
        'id': animeId,
        'cat': category,
        'key': sourceKey,
        if (sourceTitle != null && sourceTitle.isNotEmpty) 'title': sourceTitle,
        't': DateTime.now().millisecondsSinceEpoch,
      },
    );
    if (list.length > _sourcePrefMaxEntries) {
      list = list.sublist(0, _sourcePrefMaxEntries);
    }
    await _persistSourcePrefs(list);
    await dropCachedStreamsForShow(animeId: animeId, category: category);
    if (kDebugMode) {
      debugPrint(
        '[AnimeService] saved source pref id=$animeId cat=$category '
        'key=$sourceKey title=$sourceTitle',
      );
    }
  }

  /// AniKoto site scrape needs a resolved slug — only when the user pinned
  /// Anikoto. Auto / Megaplay / VidNest / Miruro use card AniList (or MAL)
  /// ids and must not title-match Anikoto.
  static bool savedSourceNeedsAnikoto(String? sourceKey) {
    if (sourceKey == null || sourceKey.isEmpty || sourceKey == 'auto') {
      return false;
    }
    return sourceKey.toLowerCase() == 'anikoto';
  }

  /// Lightweight reachability check before replaying cached stream URLs.
  ///
  /// Probe mode comes from [ProviderRuntimeConfig.animePlaybackProfile]
  /// for [sourceKey] (DB / builtins).
  Future<bool> probeStreamUrl(
    String url,
    Map<String, String> headers, {
    String? sourceKey,
  }) async {
    if (url.isEmpty) return false;
    try {
      return await probeStreamSourceUrl(
        url,
        headers,
        sourceKey: sourceKey,
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> anyResolvedHitPlayable(
    List<Map<String, dynamic>> hitsJson,
  ) async {
    for (final entry in hitsJson) {
      final media = (entry['media'] as Map?)?.cast<String, dynamic>();
      if (media == null) continue;
      final url = media['url'] as String? ?? '';
      if (url.isEmpty) continue;
      final headers =
          (media['headers'] as Map?)?.cast<String, String>() ?? const {};
      final embed = entry['embed'] as Map?;
      final sourceKey = embed?['sourceKey'] as String? ??
          embed?['source_key'] as String? ??
          media['provider'] as String?;
      if (await probeStreamUrl(url, headers, sourceKey: sourceKey)) {
        return true;
      }
    }
    return false;
  }

  // ─── Resolved stream URL cache (replay same episode without re-extract) ─
  static const _streamCacheKey = 'enma_anime_stream_cache_v1';
  static const _streamCacheMaxEntries = 24;
  static const _streamCacheMaxAge = Duration(minutes: 25);

  Future<List<Map<String, dynamic>>?> cachedResolvedStreamsJson({
    required int animeId,
    required int episode,
    required String category,
  }) async {
    final list = await _loadStreamCache();
    final key = _streamCacheEntryKey(animeId, episode, category);
    for (final e in list) {
      if (e['k'] == key) {
        if (kDebugMode) {
          debugPrint('[AnimeService] disk stream cache hit $key');
        }
        return (e['hits'] as List?)
            ?.map((h) => (h as Map).cast<String, dynamic>())
            .toList();
      }
    }
    return null;
  }

  Future<void> cacheResolvedStreamsJson({
    required int animeId,
    required int episode,
    required String category,
    required List<Map<String, dynamic>> hits,
  }) async {
    if (hits.isEmpty) return;
    var list = await _loadStreamCache();
    final key = _streamCacheEntryKey(animeId, episode, category);
    list.removeWhere((e) => e['k'] == key);
    list.insert(
      0,
      {
        'k': key,
        't': DateTime.now().millisecondsSinceEpoch,
        'hits': hits,
      },
    );
    if (list.length > _streamCacheMaxEntries) {
      list = list.sublist(0, _streamCacheMaxEntries);
    }
    await _persistStreamCache(list);
  }

  Future<void> dropCachedStream({
    required int animeId,
    required int episode,
    required String category,
  }) async {
    final list = await _loadStreamCache();
    final key = _streamCacheEntryKey(animeId, episode, category);
    if (!list.any((e) => e['k'] == key)) return;
    list.removeWhere((e) => e['k'] == key);
    await _persistStreamCache(list);
  }

  Future<void> dropCachedStreamsForShow({
    required int animeId,
    required String category,
  }) async {
    final prefix = '$animeId:';
    final suffix = ':$category';
    final list = await _loadStreamCache();
    final before = list.length;
    list.removeWhere((e) {
      final k = e['k'] as String? ?? '';
      return k.startsWith(prefix) && k.endsWith(suffix);
    });
    if (list.length != before) {
      await _persistStreamCache(list);
    }
  }

  String _streamCacheEntryKey(int animeId, int episode, String category) =>
      '$animeId:$episode:$category';

  Future<List<Map<String, dynamic>>> _loadStreamCache() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_streamCacheKey) ?? [];
    final cutoff =
        DateTime.now().millisecondsSinceEpoch - _streamCacheMaxAge.inMilliseconds;
    final list = raw
        .map((e) => jsonDecode(e) as Map<String, dynamic>)
        .where((e) => (e['t'] as int? ?? 0) >= cutoff)
        .toList();
    if (list.length != raw.length) {
      await _persistStreamCache(list);
    }
    return list;
  }

  Future<void> _persistStreamCache(List<Map<String, dynamic>> list) async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(
      _streamCacheKey,
      list.map(jsonEncode).toList(growable: false),
    );
  }

  int? _prefAnimeId(Map<String, dynamic> e) {
    final id = e['id'];
    if (id is int) return id;
    if (id is num) return id.toInt();
    return int.tryParse(id?.toString() ?? '');
  }

  Future<List<Map<String, dynamic>>> _loadSourcePrefs() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_sourcePrefKey) ?? [];
    final cutoff =
        DateTime.now().millisecondsSinceEpoch - _sourcePrefMaxAge.inMilliseconds;
    final list = raw
        .map((e) => jsonDecode(e) as Map<String, dynamic>)
        .where((e) => (e['t'] as int? ?? 0) >= cutoff)
        .toList();
    if (list.length != raw.length) {
      await _persistSourcePrefs(list);
    }
    return list;
  }

  Future<void> _persistSourcePrefs(List<Map<String, dynamic>> list) async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(
      _sourcePrefKey,
      list.map(jsonEncode).toList(growable: false),
    );
  }

  // ─── Liked anime ────────────────────────────────────────────────
  static const _likedKey = 'enma_liked_v1';

  Future<bool> isLiked(int id) async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(_likedKey) ?? [];
    return list.any((e) => jsonDecode(e)['id'] == id);
  }

  Future<void> toggleLike(AnimeCard anime) async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(_likedKey) ?? [];
    final exists = list.any((e) => jsonDecode(e)['id'] == anime.id);
    if (exists) {
      list.removeWhere((e) => jsonDecode(e)['id'] == anime.id);
    } else {
      list.add(jsonEncode(anime.toJson()));
    }
    await p.setStringList(_likedKey, list);
  }

  Future<List<AnimeCard>> getLiked() async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(_likedKey) ?? [];
    return list.map((e) => AnimeCard.fromJson(jsonDecode(e))).toList().reversed.toList();
  }

  // ─── Watch history (continue watching) ──────────────────────────
  static const _historyKey = 'enma_history_v1';

  /// Bumped whenever the watch history changes (record / remove).
  /// UI surfaces (AnimeScreen) listen to this to refresh without
  /// needing to be in the foreground or pop a route.
  static final ValueNotifier<int> watchHistoryRevision =
      ValueNotifier<int>(0);

  Future<void> recordWatch({
    required AnimeCard anime,
    required int episodeNumber,
    String category = 'sub',
    Duration? position,
    Duration? duration,
  }) async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(_historyKey) ?? [];
    list.removeWhere((e) => jsonDecode(e)['animeId'] == anime.id);
    list.insert(
      0,
      jsonEncode({
        'animeId': anime.id,
        'episodeNumber': episodeNumber,
        'category': category,
        'positionMs': position?.inMilliseconds ?? 0,
        'durationMs': duration?.inMilliseconds ?? 0,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        'anime': anime.toJson(),
      }),
    );
    if (list.length > 50) list.removeRange(50, list.length);
    await p.setStringList(_historyKey, list);
    watchHistoryRevision.value++;
  }

  Future<List<Map<String, dynamic>>> getWatchHistory() async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(_historyKey) ?? [];
    return list
        .map((e) => jsonDecode(e) as Map<String, dynamic>)
        .toList(growable: false);
  }

  Future<Map<String, dynamic>?> getProgress(int animeId) async {
    final all = await getWatchHistory();
    final hit = all.where((e) => e['animeId'] == animeId).toList();
    return hit.isEmpty ? null : hit.first;
  }

  Future<void> removeFromHistory(int animeId) async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(_historyKey) ?? [];
    list.removeWhere((e) => jsonDecode(e)['animeId'] == animeId);
    await p.setStringList(_historyKey, list);
    watchHistoryRevision.value++;
  }

  /// Clear anime continue watching.
  Future<void> clearWatchHistory() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_historyKey);
    await p.remove('anime_watch_history');
    watchHistoryRevision.value++;
  }

  /// Clear resolved-stream disk cache and sticky source pins.
  Future<void> clearStreamCaches() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_streamCacheKey);
    await p.remove(_sourcePrefKey);
  }
}

// ════════════════════════════════════════════════════════════════════
//  Models
// ════════════════════════════════════════════════════════════════════

/// One AniList [Media.relations] edge — typed link to another anime.
class AnimeRelation {
  final String relationType;
  final AnimeCard anime;

  const AnimeRelation({
    required this.relationType,
    required this.anime,
  });

  /// Short label for poster badge (Side Story, Summary, Sequel…).
  String get label {
    switch (relationType) {
      case 'SIDE_STORY':
        return 'Side Story';
      case 'SUMMARY':
        return 'Summary';
      case 'ALTERNATIVE':
        return 'Alternative';
      case 'SPIN_OFF':
        return 'Spin-off';
      case 'SEQUEL':
        return 'Sequel';
      case 'PREQUEL':
        return 'Prequel';
      case 'PARENT':
        return 'Parent';
      case 'COMPILATION':
        return 'Compilation';
      case 'CONTAINS':
        return 'Contains';
      case 'OTHER':
        return 'Other';
      default:
        return relationType.replaceAll('_', ' ');
    }
  }

  String? get formatLabel {
    final f = anime.format;
    if (f == null || f.isEmpty) return null;
    switch (f) {
      case 'TV':
      case 'TV_SHORT':
        return 'TV';
      case 'MOVIE':
        return 'Movie';
      case 'OVA':
        return 'OVA';
      case 'ONA':
        return 'ONA';
      case 'SPECIAL':
        return 'Special';
      default:
        return f;
    }
  }
}

class AnimeCard {
  final int id;
  /// Optional MAL id from AniList GraphQL — display/legacy only.
  /// Playback MAL ids come from [AnimeService.resolveMalId].
  final int? idMal;
  final String titleEnglish;
  final String titleRomaji;
  final String titleNative;
  /// AniList synonyms (extra search / scrape match strings).
  final List<String> synonyms;
  final String? coverLarge;
  final String? coverExtraLarge;
  final String? coverColor;
  final String? bannerImage;
  /// TMDB w1280 backdrop when resolved; heroes prefer this over AniList art.
  final String? tmdbBackdropUrl;
  final String? format;
  final String? status;
  final int? episodes;
  final int? duration;
  final int? averageScore;
  final int? popularity;
  final String? description;
  final List<String> genres;
  final Map<String, int?>? nextAiringEpisode;
  final int? seasonYear;
  final String? season;
  final String? mainStudio;
  final bool isAdult;
  final List<Map<String, String>> streamingEpisodes;
  /// YouTube id from AniList `trailer` (details payload only).
  final String? trailerYoutubeId;

  /// UI title — Settings → Playback → Anime title language (default romaji).
  String get displayTitle {
    final lang = SettingsService.animeTitleLanguageNotifier.value;
    return switch (lang) {
      'english' => _firstTitle([titleEnglish, titleRomaji, titleNative]),
      'native' => _firstTitle([titleNative, titleRomaji, titleEnglish]),
      _ => _firstTitle([titleRomaji, titleEnglish, titleNative]),
    };
  }

  /// Scrape / AllAnime / Anikoto query order: romaji → english → native → synonyms.
  List<String> resolveTitleCandidates() {
    final out = <String>[];
    void add(String raw) {
      final t = raw.trim();
      if (t.isEmpty) return;
      if (out.any((x) => x.toLowerCase() == t.toLowerCase())) return;
      out.add(t);
    }

    add(titleRomaji);
    add(titleEnglish);
    add(titleNative);
    for (final s in synonyms) {
      add(s);
    }
    return out;
  }

  static String _firstTitle(List<String> ordered) {
    for (final t in ordered) {
      if (t.trim().isNotEmpty) return t.trim();
    }
    return '';
  }

  String get coverUrl => coverExtraLarge ?? coverLarge ?? '';
  String get bannerOrCover => bannerImage ?? coverUrl;
  String get heroBackdrop => tmdbBackdropUrl ?? bannerOrCover;
  String get cleanDescription => (description ?? '')
      .replaceAll(RegExp(r'<br\s*/?>'), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .trim();

  MediaTrailer? get mediaTrailer {
    final id = trailerYoutubeId?.trim();
    if (id == null || id.isEmpty) return null;
    return MediaTrailer(
      key: id,
      name: displayTitle.isEmpty ? 'Trailer' : displayTitle,
      type: 'Trailer',
      official: true,
      site: 'YouTube',
    );
  }

  const AnimeCard({
    required this.id,
    this.idMal,
    required this.titleEnglish,
    required this.titleRomaji,
    required this.titleNative,
    this.synonyms = const [],
    this.coverLarge,
    this.coverExtraLarge,
    this.coverColor,
    this.bannerImage,
    this.tmdbBackdropUrl,
    this.format,
    this.status,
    this.episodes,
    this.duration,
    this.averageScore,
    this.popularity,
    this.description,
    this.genres = const [],
    this.nextAiringEpisode,
    this.seasonYear,
    this.season,
    this.mainStudio,
    this.isAdult = false,
    this.streamingEpisodes = const [],
    this.trailerYoutubeId,
  });

  AnimeCard copyWith({
    int? id,
    int? idMal,
    String? titleEnglish,
    String? titleRomaji,
    String? titleNative,
    List<String>? synonyms,
    String? coverLarge,
    String? coverExtraLarge,
    String? coverColor,
    String? bannerImage,
    String? tmdbBackdropUrl,
    String? format,
    String? status,
    int? episodes,
    int? duration,
    int? averageScore,
    int? popularity,
    String? description,
    List<String>? genres,
    Map<String, int?>? nextAiringEpisode,
    int? seasonYear,
    String? season,
    String? mainStudio,
    bool? isAdult,
    List<Map<String, String>>? streamingEpisodes,
    String? trailerYoutubeId,
  }) {
    return AnimeCard(
      id: id ?? this.id,
      idMal: idMal ?? this.idMal,
      titleEnglish: titleEnglish ?? this.titleEnglish,
      titleRomaji: titleRomaji ?? this.titleRomaji,
      titleNative: titleNative ?? this.titleNative,
      synonyms: synonyms ?? this.synonyms,
      coverLarge: coverLarge ?? this.coverLarge,
      coverExtraLarge: coverExtraLarge ?? this.coverExtraLarge,
      coverColor: coverColor ?? this.coverColor,
      bannerImage: bannerImage ?? this.bannerImage,
      tmdbBackdropUrl: tmdbBackdropUrl ?? this.tmdbBackdropUrl,
      format: format ?? this.format,
      status: status ?? this.status,
      episodes: episodes ?? this.episodes,
      duration: duration ?? this.duration,
      averageScore: averageScore ?? this.averageScore,
      popularity: popularity ?? this.popularity,
      description: description ?? this.description,
      genres: genres ?? this.genres,
      nextAiringEpisode: nextAiringEpisode ?? this.nextAiringEpisode,
      seasonYear: seasonYear ?? this.seasonYear,
      season: season ?? this.season,
      mainStudio: mainStudio ?? this.mainStudio,
      isAdult: isAdult ?? this.isAdult,
      streamingEpisodes: streamingEpisodes ?? this.streamingEpisodes,
      trailerYoutubeId: trailerYoutubeId ?? this.trailerYoutubeId,
    );
  }

  factory AnimeCard.fromJson(Map<String, dynamic> json) {
    final title = (json['title'] as Map?)?.cast<String, dynamic>() ?? {};
    final cover = (json['coverImage'] as Map?)?.cast<String, dynamic>() ?? {};
    final nae = (json['nextAiringEpisode'] as Map?)?.cast<String, dynamic>();
    String? studio;
    final studios = (json['studios']?['nodes'] as List?) ?? [];
    if (studios.isNotEmpty) studio = studios.first['name'] as String?;
    final streamEps = ((json['streamingEpisodes'] as List?) ?? const [])
        .whereType<Map>()
        .map((m) => {
              'title': (m['title'] ?? '').toString(),
              'thumbnail': (m['thumbnail'] ?? '').toString(),
              'url': (m['url'] ?? '').toString(),
              'site': (m['site'] ?? '').toString(),
            })
        .toList();
    final synonyms = ((json['synonyms'] as List?) ?? const [])
        .map((e) => e.toString().trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final rawMal = json['idMal'];
    final idMal = rawMal is int
        ? rawMal
        : (rawMal is num ? rawMal.toInt() : int.tryParse('$rawMal'));
    String? trailerYoutubeId;
    final trailer = json['trailer'];
    if (trailer is Map) {
      final site = (trailer['site'] ?? '').toString().toLowerCase();
      final tid = (trailer['id'] ?? '').toString().trim();
      if (site == 'youtube' && tid.isNotEmpty) trailerYoutubeId = tid;
    }
    return AnimeCard(
      id: (json['id'] ?? 0) as int,
      idMal: (idMal != null && idMal > 0) ? idMal : null,
      titleEnglish: (title['english'] ?? '') as String? ?? '',
      titleRomaji: (title['romaji'] ?? '') as String? ?? '',
      titleNative: (title['native'] ?? '') as String? ?? '',
      synonyms: synonyms,
      coverLarge: cover['large'] as String?,
      coverExtraLarge: cover['extraLarge'] as String?,
      coverColor: cover['color'] as String?,
      bannerImage: json['bannerImage'] as String?,
      tmdbBackdropUrl: json['tmdbBackdropUrl'] as String?,
      format: json['format'] as String?,
      status: json['status'] as String?,
      episodes: json['episodes'] as int?,
      duration: json['duration'] as int?,
      averageScore: json['averageScore'] as int?,
      popularity: json['popularity'] as int?,
      description: json['description'] as String?,
      genres: ((json['genres'] as List?) ?? const []).cast<String>(),
      nextAiringEpisode: nae == null
          ? null
          : {
              'episode': nae['episode'] as int?,
              'airingAt': nae['airingAt'] as int?,
              'timeUntilAiring': nae['timeUntilAiring'] as int?,
            },
      seasonYear: json['seasonYear'] as int?,
      season: json['season'] as String?,
      mainStudio: studio,
      isAdult: (json['isAdult'] ?? false) as bool,
      streamingEpisodes: streamEps,
      trailerYoutubeId: trailerYoutubeId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (idMal != null) 'idMal': idMal,
        'title': {'english': titleEnglish, 'romaji': titleRomaji, 'native': titleNative},
        'synonyms': synonyms,
        'coverImage': {'large': coverLarge, 'extraLarge': coverExtraLarge, 'color': coverColor},
        'bannerImage': bannerImage,
        if (tmdbBackdropUrl != null) 'tmdbBackdropUrl': tmdbBackdropUrl,
        'format': format,
        'status': status,
        'episodes': episodes,
        'duration': duration,
        'averageScore': averageScore,
        'popularity': popularity,
        'description': description,
        'genres': genres,
        'seasonYear': seasonYear,
        'season': season,
        'studios': mainStudio == null
            ? null
            : {
                'nodes': [
                  {'name': mainStudio}
                ]
              },
        'isAdult': isAdult,
      };
}

class AnimeEpisode {
  final int number;
  final String title;
  final bool aired;
  final String? thumbnail;

  const AnimeEpisode({
    required this.number,
    required this.title,
    this.aired = true,
    this.thumbnail,
  });
}

class AnimeStreamPref {
  final String sourceKey;
  final String? sourceTitle;

  const AnimeStreamPref({required this.sourceKey, this.sourceTitle});
}

class AnimeEmbed {
  final String label;     // real upstream name, e.g. Megaplay, HiAnime
  final String server;    // 'megaplay' | 'anikoto' | 'miruro' | …
  final String category;  // 'sub' | 'dub'
  final String url;

  const AnimeEmbed({
    required this.label,
    required this.server,
    required this.category,
    required this.url,
  });

  String get displayName => '$label · ${category.toUpperCase()}';

  /// Unique player-panel id — [sourceKey] alone collides across sub/dub pairs.
  String get panelKey => '$sourceKey:$category';

  /// Stable id for saved stream preference (e.g. `megaplay`, `miruro:zoro`).
  String get sourceKey {
    switch (server) {
      case 'anikoto':
        return 'anikoto';
      case 'miruro':
        final uri = Uri.parse(url.replaceFirst('miruro://', 'https://'));
        final prov = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
        return 'miruro:$prov';
      case 'allanime':
        final uri = Uri.parse(url.replaceFirst('allanime://', 'https://'));
        final segs = uri.pathSegments;
        if (segs.length >= 4) return 'allanime:${segs[3]}';
        return 'allanime:default';
      case 'animerealms':
        final uri = Uri.parse(url.replaceFirst('animerealms://', 'https://'));
        final prov = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
        return 'animerealms:$prov';
      case 'vidnest':
        final uri = Uri.parse(url.replaceFirst('vidnest://', 'https://'));
        final prov = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
        return 'vidnest:$prov';
      default:
        return server;
    }
  }

  String get refererOrigin {
    switch (server) {
      case 'miruro':
        final o = MiruroDomains.primary;
        return o.endsWith('/') ? o.substring(0, o.length - 1) : o;
      case 'allanime':
        return 'https://allmanga.to';
      case 'vidnest':
        return 'https://vidnest.fun';
      case 'vidlink':
        return 'https://vidlink.pro';
      case 'animerealms':
        return 'https://www.animerealms.org';
      case 'watchhentai':
        return 'https://watchhentai.net';
      case 'hentaini':
        return 'https://hentaini.com';
      default:
        return 'https://${ProviderRuntimeConfig.instance.megaplay.host}';
    }
  }
}

/// Result of a successful stream extraction.
class AnimeStreamResult {
  final String url;       // m3u8 / mp4
  final String referer;   // header to send to CDN
  final String origin;    // header to send to CDN
  final List<AnimeTrack> tracks;
  final String? streamLabel;

  const AnimeStreamResult({
    required this.url,
    required this.referer,
    required this.origin,
    this.tracks = const [],
    this.streamLabel,
  });
}

class AnimeTrack {
  final String url;
  final String label;
  final bool isDefault;
  const AnimeTrack({
    required this.url,
    required this.label,
    this.isDefault = false,
  });
}

class AnikotoSeries {
  final int id;
  final String slug;
  /// AniList id from Anikoto (may differ from Forja catalog).
  final int? aniId;
  final List<AnikotoEpisode> episodes;
  const AnikotoSeries({
    required this.id,
    this.slug = '',
    this.aniId,
    required this.episodes,
  });
}

class AnikotoEpisode {
  final int id;
  final int number;
  final String title;
  final String embedId; // episode_embed_id used by /stream/s-2/{id}/{lang}

  const AnikotoEpisode({
    required this.id,
    required this.number,
    required this.title,
    required this.embedId,
  });

  factory AnikotoEpisode.fromJson(Map<String, dynamic> j) {
    return AnikotoEpisode(
      id: (j['id'] ?? 0) as int,
      number: (j['number'] ?? 0) as int,
      title: (j['title'] ?? '') as String,
      embedId: (j['episode_embed_id'] ?? '').toString(),
    );
  }
}
