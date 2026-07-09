// Anime backend — AniList GraphQL for metadata; Miruro + AnimeRealms playback.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:rust/rust.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:forja/features/anime/catalog/miruro_extractor.dart';

class AnimeService {
  static const String _anikotoUa =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';

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

  static const String _mediaFields = '''
    id
    title { romaji english native }
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
    trailer { id site thumbnail }
    streamingEpisodes { title thumbnail url site }
  ''';

  // ─── Public lists ───────────────────────────────────────────────
  Future<List<AnimeCard>> getSpotlight() => _list(
        sort: 'TRENDING_DESC',
        perPage: 10,
        extraFilter: 'status_in: [RELEASING, FINISHED]',
      );

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
        }
      }
    ''';
    final data = await _query(q, {'id': anilistId});
    return AnimeCard.fromJson(data['Media'] as Map<String, dynamic>);
  }

  Future<List<AnimeCard>> getRelations(int anilistId) async {
    final q = '''
      query (\$id: Int) {
        Media(id: \$id, type: ANIME) {
          relations { nodes { $_mediaFields } }
        }
      }
    ''';
    const animeFormats = {
      'TV', 'TV_SHORT', 'MOVIE', 'OVA', 'ONA', 'SPECIAL', 'MUSIC',
    };
    final data = await _query(q, {'id': anilistId});
    final nodes = (data['Media']?['relations']?['nodes'] as List?) ?? [];
    return nodes
        .cast<Map<String, dynamic>>()
        .where((n) => animeFormats.contains(n['format'] as String?))
        .map(AnimeCard.fromJson)
        .toList();
  }

  /// Walk the PREQUEL/SEQUEL/PARENT/SIDE_STORY edge chain from this anime
  /// to assemble the full ordered list of "seasons" (entries that share
  /// continuity). AniList stores each season as a separate Media id, so
  /// we follow PREQUEL edges to the root, then SEQUEL edges to the tip.
  ///
  /// PARENT is included because some franchises wire S2+ as PARENT->S1
  /// rather than PREQUEL/SEQUEL. SIDE_STORY is excluded — those are
  /// spin-offs, not numbered seasons.
  ///
  /// Result is ordered chronologically (root → latest) and ALWAYS includes
  /// the input anime. Returns just the input if no chain neighbors exist.
  Future<List<AnimeCard>> getSeasons(int anilistId) async {
    const q = r'''
      query ($id: Int) {
        Media(id: $id, type: ANIME) {
          id title { romaji english } format episodes status
          coverImage { large extraLarge color }
          startDate { year month day }
          relations {
            edges {
              relationType
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

    // Cache fetched nodes to avoid duplicate AniList queries when the
    // chain branches (e.g. a special links to multiple sequels).
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

    int? neighbor(Map<String, dynamic> media, Set<String> wanted) {
      final edges = (media['relations']?['edges'] as List?) ?? const [];
      for (final e in edges) {
        if (e is! Map) continue;
        final type = (e['relationType'] ?? '').toString();
        if (!wanted.contains(type)) continue;
        final node = e['node'];
        if (node is! Map) continue;
        if ((node['type'] ?? '') != 'ANIME') continue;
        final fmt = (node['format'] ?? '').toString();
        // Only chain through TV / TV_SHORT / ONA — other formats are
        // movies/specials that are usually side material, not next season.
        if (!{'TV', 'TV_SHORT', 'ONA'}.contains(fmt)) continue;
        final id = node['id'];
        if (id is int) return id;
      }
      return null;
    }

    // 1. Walk to root via PREQUEL/PARENT.
    final visited = <int>{anilistId};
    int rootId = anilistId;
    final root = await fetch(anilistId);
    if (root == null) {
      try {
        return [await getDetails(anilistId)];
      } catch (_) {
        return const [];
      }
    }
    var current = root;
    while (true) {
      final p = neighbor(current, const {'PREQUEL', 'PARENT'});
      if (p == null || !visited.add(p)) break;
      final m = await fetch(p);
      if (m == null) break;
      rootId = p;
      current = m;
    }

    // 2. Walk forward from root via SEQUEL.
    final chain = <int>[rootId];
    current = (await fetch(rootId))!;
    while (true) {
      final s = neighbor(current, const {'SEQUEL'});
      if (s == null || !visited.add(s)) break;
      final m = await fetch(s);
      if (m == null) break;
      chain.add(s);
      current = m;
    }

    // 3. Always include the input anime even if it isn't on the spine
    // (rare: it might only be reachable via PARENT branch).
    if (!chain.contains(anilistId)) chain.add(anilistId);

    return chain
        .map((id) => fetched[id])
        .whereType<Map<String, dynamic>>()
        .map((m) => AnimeCard.fromJson(m))
        .toList();
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

  Future<AnikotoSeries?> resolveAnikoto(AnimeCard anime) async {
    if (_anikotoCache.containsKey(anime.id)) return _anikotoCache[anime.id];
    final s = await _findAnikotoSeries(anime);
    _anikotoCache[anime.id] = s;
    return s;
  }

  Future<AnikotoSeries?> _findAnikotoSeries(AnimeCard anime) async {
    // Strategy A: walk the /recent-anime feed (sorted by recency). This is
    // fast for currently-airing or recently-completed shows.
    const int maxPages = 6;
    const int perPage = 60;
    for (var page = 1; page <= maxPages; page++) {
      try {
        final list = await _anikotoGet('/recent-anime?page=$page&per_page=$perPage');
        final data = (list?['data'] as List?) ?? const [];
        for (final raw in data) {
          final m = (raw as Map).cast<String, dynamic>();
          final ani = (m['ani_id'] ?? '').toString();
          if (ani == anime.id.toString()) {
            return _loadAnikotoSeries(
              m['id'] as int,
              expectedAnilistId: anime.id,
            );
          }
        }
        if (data.length < perPage) break; // last page
      } catch (e) {
        debugPrint('[Anikoto] page $page failed: $e');
        break;
      }
    }

    // Strategy B: search anikototv.to (the upstream catalog) via its HTML
    // search page. The API itself has no search endpoint, so we scrape slugs
    // from the search results, lift the numeric data-id from each watch page,
    // then verify against AniList ID through /series/{id}.
    final queries = <String>[
      anime.titleEnglish,
      anime.titleRomaji,
    ].where((q) => q.trim().isNotEmpty).toSet();
    final candidates = <String>[];
    final seenSlugs = <String>{};
    for (final q in queries) {
      for (final slug in await _anikotoSearchSlugs(q)) {
        if (seenSlugs.add(slug)) candidates.add(slug);
      }
    }
    // Walk search results in rank order. One Piece's main TV entry is often
    // past the first page of specials — stopping at 8 slugs mapped to the
    // wrong 1-ep movie/OVA while the user picked ep 1 of the real series.
    final resolved = <_AnikotoCandidate>[];
    final aniIdMatches = <_AnikotoCandidate>[];
    final expected = anime.episodes ?? 0;
    for (final slug in candidates) {
      final id = await _anikotoIdFromSlug(slug);
      if (id == null) continue;
      try {
        final j = await _anikotoGet('/series/$id');
        final aniId = (j?['data']?['anime']?['ani_id'] ?? '').toString();
        final epCount = (j?['data']?['episodes'] as List?)?.length ?? 0;
        final cand = _AnikotoCandidate(slug: slug, id: id, episodes: epCount);
        if (aniId == anime.id.toString()) {
          aniIdMatches.add(cand);
          if (expected > 0 && epCount >= (expected * 0.85).floor()) {
            if (kDebugMode) {
              debugPrint(
                  '[Anikoto] ani_id match ${cand.slug} id=${cand.id} '
                  'eps=$epCount (expected $expected)');
            }
            return _loadAnikotoSeries(
              cand.id,
              expectedAnilistId: anime.id,
            );
          }
        } else {
          resolved.add(cand);
        }
      } catch (_) {}
    }

    // Pick the best ani_id match by episode-count fit. If AniList knows the
    // total, prefer the candidate closest to it (and at least half of it).
    // Otherwise prefer the one with the most episodes.
    if (aniIdMatches.isNotEmpty) {
      _AnikotoCandidate best;
      if (expected > 0) {
        aniIdMatches.sort((a, b) {
          final da = (a.episodes - expected).abs();
          final db = (b.episodes - expected).abs();
          if (da != db) return da.compareTo(db);
          return b.episodes.compareTo(a.episodes);
        });
        best = aniIdMatches.first;
        // If even the closest match is way off (e.g. 1-ep special when
        // AniList expects 26), fall through to fuzzy on the resolved pool.
        if (best.episodes < (expected / 2).ceil() && resolved.isNotEmpty) {
          // Treat the ani_id matches as ordinary candidates for fuzzy too.
          resolved.addAll(aniIdMatches);
        } else {
          if (kDebugMode) {
            debugPrint(
                '[Anikoto] ani_id match ${best.slug} id=${best.id} '
                'eps=${best.episodes} (expected $expected)');
          }
          return _loadAnikotoSeries(
            best.id,
            expectedAnilistId: anime.id,
          );
        }
      } else {
        aniIdMatches.sort((a, b) => b.episodes.compareTo(a.episodes));
        final best = aniIdMatches.first;
        if (kDebugMode) {
          debugPrint(
              '[Anikoto] ani_id match ${best.slug} id=${best.id} '
              'eps=${best.episodes}');
        }
        return _loadAnikotoSeries(
          best.id,
          expectedAnilistId: anime.id,
        );
      }
    }

    // Strategy C: no ani_id matched. Score every probed slug against the
    // AniList titles by token overlap and use the best one. This rescues
    // shows where anikoto stores no AniList linkage (Demon Slayer etc.).
    if (resolved.isNotEmpty) {
      final titleTokens = <String>{};
      for (final t in queries) {
        titleTokens.addAll(_slugTokens(t));
      }
      titleTokens.removeWhere(_anikotoStopwords.contains);
      if (titleTokens.isNotEmpty) {
        _AnikotoCandidate? best;
        double bestScore = 0;
        for (final c in resolved) {
          // Drop the trailing ~5-char hash anikoto appends to slugs.
          final slugTokens = c.slug
              .split('-')
              .where((t) => t.length > 1 && !RegExp(r'^[a-z0-9]{5}$').hasMatch(t))
              .toSet()
            ..removeWhere(_anikotoStopwords.contains);
          if (slugTokens.isEmpty) continue;
          final inter = slugTokens.intersection(titleTokens).length;
          if (inter == 0) continue;
          final union = slugTokens.length + titleTokens.length - inter;
          final j = inter / union;
          if (j > bestScore) {
            bestScore = j;
            best = c;
          }
        }
        if (best != null && bestScore >= 0.40) {
          if (expected > 5 && best.episodes < (expected / 2).ceil()) {
            if (kDebugMode) {
              debugPrint(
                  '[Anikoto] reject fuzzy ${best.slug}: ${best.episodes} eps '
                  'vs expected $expected');
            }
            return null;
          }
          debugPrint(
              '[Anikoto] fuzzy match ${best.slug} score=${bestScore.toStringAsFixed(2)} '
              'eps=${best.episodes}');
          return _loadAnikotoSeries(
            best.id,
            expectedAnilistId: anime.id,
            fuzzyMatch: true,
          );
        }
      }
    }
    return null;
  }

  static const _anikotoStopwords = <String>{
    'the', 'a', 'an', 'of', 'and', 'or', 'to', 'in', 'on',
    'no', 'wa', 'ga', 'ni', 'wo', 'de', 'mo',
    'season', 'part', 'arc', 'tv', 'special', 'ova', 'ona',
  };

  Set<String> _slugTokens(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .split(RegExp(r'\s+'))
      .where((t) => t.length > 1)
      .toSet();

  static const int _anikotoSearchMaxSlugs = 40;
  static const int _anikotoSearchMaxPages = 4;

  // Scrape https://anikototv.to/search?keyword=… for unique watch slugs.
  Future<List<String>> _anikotoSearchSlugs(String query) async {
    try {
      final seen = <String>{};
      for (var page = 1;
          page <= _anikotoSearchMaxPages && seen.length < _anikotoSearchMaxSlugs;
          page++) {
        final base =
            'https://anikototv.to/search?keyword=${Uri.encodeQueryComponent(query)}';
        final url = page == 1 ? base : '$base&page=$page';
        final res = await animeHttp('GET', url, headers: {
          'User-Agent': _anikotoUa,
          'Accept': 'text/html',
        });
        if (res.status != 200) break;
        final matches = RegExp(r'/watch/([a-z0-9-]+)').allMatches(res.body);
        var added = 0;
        for (final m in matches) {
          final slug = m.group(1)!;
          if (seen.add(slug)) added++;
          if (seen.length >= _anikotoSearchMaxSlugs) break;
        }
        if (added == 0) break;
      }
      return seen.toList();
    } catch (e) {
      debugPrint('[Anikoto] search "$query" failed: $e');
      return const [];
    }
  }

  // Lift the anikoto numeric series ID from a /watch/{slug} HTML page.
  Future<int?> _anikotoIdFromSlug(String slug) async {
    try {
      final res = await animeHttp('GET', 'https://anikototv.to/watch/$slug', headers: {
        'User-Agent': _anikotoUa,
        'Accept': 'text/html',
      });
      if (res.status != 200) return null;
      final m = RegExp(r'data-id="(\d+)"').firstMatch(res.body);
      if (m == null) return null;
      return int.tryParse(m.group(1)!);
    } catch (e) {
      debugPrint('[Anikoto] watch/$slug failed: $e');
      return null;
    }
  }

  Future<AnikotoSeries?> _loadAnikotoSeries(
    int anikotoId, {
    int? expectedAnilistId,
    bool fuzzyMatch = false,
  }) async {
    try {
      final j = await _anikotoGet('/series/$anikotoId');
      final loadedAniId =
          (j?['data']?['anime']?['ani_id'] ?? '').toString().trim();
      if (expectedAnilistId != null &&
          loadedAniId.isNotEmpty &&
          loadedAniId != expectedAnilistId.toString()) {
        if (kDebugMode) {
          debugPrint(
              '[Anikoto] reject series $anikotoId: ani_id=$loadedAniId '
              '!= $expectedAnilistId');
        }
        return null;
      }
      final eps = ((j?['data']?['episodes'] as List?) ?? const [])
          .cast<Map>()
          .map((e) => AnikotoEpisode.fromJson(e.cast<String, dynamic>()))
          .toList();
      final verified = expectedAnilistId != null &&
          loadedAniId == expectedAnilistId.toString();
      if (kDebugMode && fuzzyMatch && !verified) {
        debugPrint(
            '[Anikoto] fuzzy series $anikotoId (${eps.length} eps) — '
            'megaplay disabled (no ani_id link)');
      }
      return AnikotoSeries(
        id: anikotoId,
        episodes: eps,
        aniIdVerified: verified,
      );
    } catch (e) {
      debugPrint('[Anikoto] /series/$anikotoId failed: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _anikotoGet(String path) async {
    final res = await animeHttp(
      'GET',
      'https://anikotoapi.site$path',
      headers: {
        'Accept': 'application/json',
        'User-Agent': _anikotoUa,
      },
      maxRetries: 0,
    );
    if (res.status != 200) {
      debugPrint('[Anikoto] $path HTTP ${res.status}');
      return null;
    }
    final j = jsonDecode(res.body);
    if (j is! Map) return null;
    final map = j.cast<String, dynamic>();
    if (map['ok'] == false) {
      debugPrint('[Anikoto] $path error: ${map['error'] ?? map['code']}');
      return null;
    }
    return map;
  }

  Future<List<AnimeEpisode>> getEpisodes(AnimeCard anime) async {
    // Always fetch fresh details so we get streamingEpisodes thumbnails
    // (the AnimeCard from list views may not include them).
    AnimeCard fresh = anime;
    try {
      fresh = await getDetails(anime.id);
    } catch (_) {}
    final thumbMap = _buildEpisodeThumbnailMap(fresh.streamingEpisodes);

    // 1. Try Anikoto (has real episode count + IDs)
    final series = await resolveAnikoto(anime);
    if (series != null && series.episodes.isNotEmpty) {
      return series.episodes
          .map((e) => AnimeEpisode(
                number: e.number,
                title: e.title.isEmpty ? 'Episode ${e.number}' : e.title,
                aired: true,
                thumbnail: thumbMap[e.number],
              ))
          .toList();
    }
    // 2. Fallback: synthesize from AniList total (legacy behaviour)
    final count = fresh.episodes ??
        anime.episodes ??
        fresh.nextAiringEpisode?['episode'] ??
        anime.nextAiringEpisode?['episode'];
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

  Map<int, String> buildEpisodeThumbnailMap(
          List<Map<String, String>> streamEps) =>
      _buildEpisodeThumbnailMap(streamEps);

  // ─── Miruro catalog (PlayTorrio playback path) ──────────────────
  final MiruroExtractor _miruro = MiruroExtractor();

  Future<MiruroEpisodes?> getMiruroEpisodes(int anilistId) async {
    try {
      final data = await _miruro.fetchEpisodes(anilistId);
      if (data == null) return null;
      return MiruroEpisodes.fromJson(data);
    } catch (e) {
      if (kDebugMode) debugPrint('[Miruro] episodes failed: $e');
      return null;
    }
  }

  /// Default Miruro provider: kiwi → zoro → first available.
  static String defaultMiruroProvider(Iterable<String> providers) {
    final list = providers.toList();
    if (list.isEmpty) return 'kiwi';
    if (list.contains('kiwi')) return 'kiwi';
    if (list.contains('zoro')) return 'zoro';
    return list.first;
  }

  List<AnimeEpisode> miruroEpisodesFor({
    required MiruroEpisodes episodes,
    required String provider,
    required String category,
    Map<int, String> thumbnails = const {},
  }) {
    final prov = episodes.providers[provider];
    if (prov == null) return const [];
    final raw = category == 'dub' ? prov.dubEpisodes : prov.subEpisodes;
    return raw
        .map(
          (e) => AnimeEpisode(
            number: e.number,
            title: e.title.isEmpty ? 'Episode ${e.number}' : e.title,
            aired: true,
            thumbnail: thumbnails[e.number],
            streamId: e.id,
          ),
        )
        .toList();
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
    String? provider,
    bool useAnimeRealms = false,
    String? episodeId,
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
        if (provider != null && provider.isNotEmpty) 'provider': provider,
        'useAnimeRealms': useAnimeRealms,
        if (episodeId != null && episodeId.isNotEmpty) 'episodeId': episodeId,
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
}

// ════════════════════════════════════════════════════════════════════
//  Models
// ════════════════════════════════════════════════════════════════════

class AnimeCard {
  final int id;
  final String titleEnglish;
  final String titleRomaji;
  final String titleNative;
  final String? coverLarge;
  final String? coverExtraLarge;
  final String? coverColor;
  final String? bannerImage;
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

  String get displayTitle =>
      titleEnglish.isNotEmpty ? titleEnglish : (titleRomaji.isNotEmpty ? titleRomaji : titleNative);
  String get coverUrl => coverExtraLarge ?? coverLarge ?? '';
  String get bannerOrCover => bannerImage ?? coverUrl;
  String get cleanDescription => (description ?? '')
      .replaceAll(RegExp(r'<br\s*/?>'), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .trim();

  const AnimeCard({
    required this.id,
    required this.titleEnglish,
    required this.titleRomaji,
    required this.titleNative,
    this.coverLarge,
    this.coverExtraLarge,
    this.coverColor,
    this.bannerImage,
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
  });

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
    return AnimeCard(
      id: (json['id'] ?? 0) as int,
      titleEnglish: (title['english'] ?? '') as String,
      titleRomaji: (title['romaji'] ?? '') as String,
      titleNative: (title['native'] ?? '') as String,
      coverLarge: cover['large'] as String?,
      coverExtraLarge: cover['extraLarge'] as String?,
      coverColor: cover['color'] as String?,
      bannerImage: json['bannerImage'] as String?,
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
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': {'english': titleEnglish, 'romaji': titleRomaji, 'native': titleNative},
        'coverImage': {'large': coverLarge, 'extraLarge': coverExtraLarge, 'color': coverColor},
        'bannerImage': bannerImage,
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
  final String? streamId;

  const AnimeEpisode({
    required this.number,
    required this.title,
    this.aired = true,
    this.thumbnail,
    this.streamId,
  });
}

class MiruroEpisodes {
  final Map<String, MiruroProvider> providers;

  const MiruroEpisodes({required this.providers});

  factory MiruroEpisodes.fromJson(Map<String, dynamic> json) {
    final provs = <String, MiruroProvider>{};
    final providersMap = json['providers'] as Map<String, dynamic>? ?? {};
    for (final entry in providersMap.entries) {
      provs[entry.key] = MiruroProvider.fromJson(
        (entry.value as Map).cast<String, dynamic>(),
      );
    }
    return MiruroEpisodes(providers: provs);
  }
}

class MiruroProvider {
  final List<MiruroPlaybackEpisode> subEpisodes;
  final List<MiruroPlaybackEpisode> dubEpisodes;

  const MiruroProvider({
    this.subEpisodes = const [],
    this.dubEpisodes = const [],
  });

  factory MiruroProvider.fromJson(Map<String, dynamic> json) {
    final episodes = json['episodes'];
    var sub = <MiruroPlaybackEpisode>[];
    var dub = <MiruroPlaybackEpisode>[];
    if (episodes is Map<String, dynamic>) {
      if (episodes['sub'] is List) {
        sub = (episodes['sub'] as List)
            .map((e) => MiruroPlaybackEpisode.fromJson(
                (e as Map).cast<String, dynamic>()))
            .toList();
      }
      if (episodes['dub'] is List) {
        dub = (episodes['dub'] as List)
            .map((e) => MiruroPlaybackEpisode.fromJson(
                (e as Map).cast<String, dynamic>()))
            .toList();
      }
    }
    return MiruroProvider(subEpisodes: sub, dubEpisodes: dub);
  }
}

class MiruroPlaybackEpisode {
  final String id;
  final int number;
  final String title;

  const MiruroPlaybackEpisode({
    required this.id,
    required this.number,
    this.title = '',
  });

  factory MiruroPlaybackEpisode.fromJson(Map<String, dynamic> json) {
    return MiruroPlaybackEpisode(
      id: (json['id'] ?? '').toString(),
      number: (json['number'] as num?)?.toInt() ?? 0,
      title: (json['title'] as String?) ?? '',
    );
  }
}

class AnikotoSeries {
  final int id;
  final List<AnikotoEpisode> episodes;
  /// True when Anikoto's `ani_id` matches the AniList card we resolved for.
  final bool aniIdVerified;
  const AnikotoSeries({
    required this.id,
    required this.episodes,
    this.aniIdVerified = false,
  });
}

class _AnikotoCandidate {
  final String slug;
  final int id;
  final int episodes;
  const _AnikotoCandidate({required this.slug, required this.id, this.episodes = 0});
}

class AnikotoEpisode {
  final int id;
  final int number;
  final String title;
  final String embedId; // episode_embed_id used by /stream/s-2/{id}/{lang}
  final String? embedUrlSub;
  final String? embedUrlDub;

  const AnikotoEpisode({
    required this.id,
    required this.number,
    required this.title,
    required this.embedId,
    this.embedUrlSub,
    this.embedUrlDub,
  });

  factory AnikotoEpisode.fromJson(Map<String, dynamic> j) {
    final embedUrl = (j['embed_url'] as Map?)?.cast<String, dynamic>() ?? {};
    return AnikotoEpisode(
      id: (j['id'] ?? 0) as int,
      number: (j['number'] ?? 0) as int,
      title: (j['title'] ?? '') as String,
      embedId: (j['episode_embed_id'] ?? '').toString(),
      embedUrlSub: (embedUrl['sub'] as String?)?.trim(),
      embedUrlDub: (embedUrl['dub'] as String?)?.trim(),
    );
  }
}
