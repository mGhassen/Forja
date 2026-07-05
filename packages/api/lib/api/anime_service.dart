// Anime backend — AniList GraphQL for metadata, megaplay.buzz for streams.
// Replaces the old miruro/animerealms stack. UI clone of enma.lol.

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'allanime_extractor.dart';
import 'watchhentai_extractor.dart';
import 'hentaini_extractor.dart';
import 'miruro_extractor.dart';

class AnimeService {
  static const String _gql = 'https://graphql.anilist.co';
  final HttpClient _client = HttpClient()..connectionTimeout = const Duration(seconds: 15);

  // ─── GraphQL helper ─────────────────────────────────────────────
  Future<dynamic> _query(String query, [Map<String, dynamic>? vars]) async {
    final req = await _client.postUrl(Uri.parse(_gql));
    req.headers.contentType = ContentType.json;
    req.headers.set('Accept', 'application/json');
    req.write(jsonEncode({'query': query, 'variables': vars ?? {}}));
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    final data = jsonDecode(body);
    if (data['errors'] != null) {
      throw Exception('AniList: ${data['errors']}');
    }
    return data['data'];
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
            return _loadAnikotoSeries(m['id'] as int);
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
    final candidates = <String>{};
    final queries = <String>[
      anime.titleEnglish,
      anime.titleRomaji,
    ].where((q) => q.trim().isNotEmpty).toSet();
    for (final q in queries) {
      candidates.addAll(await _anikotoSearchSlugs(q));
      if (candidates.length >= 10) break;
    }
    // Probe the first ~8 candidates. /series/{id} returns ani_id and an
    // episodes list. We collect (slug, id, epCount) for every candidate —
    // including ani_id matches — because anikoto frequently links the same
    // AniList ID to a 1-episode special AND the real multi-episode series
    // (Demon Slayer S1's "Sibling's Bond" special vs the 26-ep main show).
    final probe = candidates.take(8).toList();
    final resolved = <_AnikotoCandidate>[];
    final aniIdMatches = <_AnikotoCandidate>[];
    for (final slug in probe) {
      final id = await _anikotoIdFromSlug(slug);
      if (id == null) continue;
      try {
        final j = await _anikotoGet('/series/$id');
        final aniId = (j?['data']?['anime']?['ani_id'] ?? '').toString();
        final epCount = (j?['data']?['episodes'] as List?)?.length ?? 0;
        final cand = _AnikotoCandidate(slug: slug, id: id, episodes: epCount);
        if (aniId == anime.id.toString()) {
          aniIdMatches.add(cand);
        } else {
          resolved.add(cand);
        }
      } catch (_) {}
    }

    // Pick the best ani_id match by episode-count fit. If AniList knows the
    // total, prefer the candidate closest to it (and at least half of it).
    // Otherwise prefer the one with the most episodes.
    if (aniIdMatches.isNotEmpty) {
      final expected = anime.episodes ?? 0;
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
          return _loadAnikotoSeries(best.id);
        }
      } else {
        aniIdMatches.sort((a, b) => b.episodes.compareTo(a.episodes));
        return _loadAnikotoSeries(aniIdMatches.first.id);
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
          debugPrint('[Anikoto] fuzzy match ${best.slug} score=${bestScore.toStringAsFixed(2)}');
          return _loadAnikotoSeries(best.id);
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

  // Scrape https://anikototv.to/search?keyword=… for unique watch slugs.
  Future<List<String>> _anikotoSearchSlugs(String query) async {
    try {
      final uri = Uri.parse(
          'https://anikototv.to/search?keyword=${Uri.encodeQueryComponent(query)}');
      final req = await _client.getUrl(uri);
      req.headers.set('User-Agent',
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
      req.headers.set('Accept', 'text/html');
      final res = await req.close();
      if (res.statusCode != 200) return const [];
      final html = await res.transform(utf8.decoder).join();
      final matches = RegExp(r'/watch/([a-z0-9-]+)').allMatches(html);
      final seen = <String>{};
      for (final m in matches) {
        final slug = m.group(1)!;
        if (seen.add(slug) && seen.length >= 12) break;
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
      final uri = Uri.parse('https://anikototv.to/watch/$slug');
      final req = await _client.getUrl(uri);
      req.headers.set('User-Agent',
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
      req.headers.set('Accept', 'text/html');
      final res = await req.close();
      if (res.statusCode != 200) return null;
      final html = await res.transform(utf8.decoder).join();
      final m = RegExp(r'data-id="(\d+)"').firstMatch(html);
      if (m == null) return null;
      return int.tryParse(m.group(1)!);
    } catch (e) {
      debugPrint('[Anikoto] watch/$slug failed: $e');
      return null;
    }
  }

  Future<AnikotoSeries?> _loadAnikotoSeries(int anikotoId) async {
    try {
      final j = await _anikotoGet('/series/$anikotoId');
      final eps = ((j?['data']?['episodes'] as List?) ?? const [])
          .cast<Map>()
          .map((e) => AnikotoEpisode.fromJson(e.cast<String, dynamic>()))
          .toList();
      return AnikotoSeries(id: anikotoId, episodes: eps);
    } catch (e) {
      debugPrint('[Anikoto] /series/$anikotoId failed: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _anikotoGet(String path) async {
    final req = await _client.getUrl(Uri.parse('https://anikotoapi.site$path'));
    req.headers.set('Accept', 'application/json');
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    final j = jsonDecode(body);
    if (j is Map) return j.cast<String, dynamic>();
    return null;
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

  /// Map AniList streamingEpisodes -> {episodeNumber: thumbnailUrl}.
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

  // ─── Stream embed URLs (the 4 servers enma.lol uses) ───────────
  // HD-1 = megaplay.buzz, HD-2 = vidwish.live. Both expose:
  //   /stream/s-2/{anikoto_embed_id}/{sub|dub}   ← preferred (catalog ID)
  //   /stream/ani/{anilist_id}/{ep}/{sub|dub}    ← fallback (mapping incomplete)
  //
  // Direct access to embeds is disabled by megaplay/vidwish; they only respond
  // when loaded as an iframe with a referer from an embedding site. We pass
  // `referer: https://www.enma.lol/` to the extractor for that reason.

  String? _embed({
    required String host, // 'megaplay.buzz' | 'vidwish.live'
    required int anilistId,
    required int episode,
    required String category,
    String? embedId, // anikoto episode_embed_id
  }) {
    // /stream/ani/{anilistId}/{ep}/{cat} consistently 404s — the only
    // reliable URL pattern is /stream/s-2/{embedId}/{cat}. If we don't
    // have an embedId from Anikoto, return null so the caller can skip
    // this server entirely instead of building a dead URL.
    if (embedId == null || embedId.isEmpty) return null;
    return 'https://$host/stream/s-2/$embedId/$category?autoPlay=1';
  }

  /// Build all 4 server embeds for a given episode. Requires [series]
  /// (Anikoto resolution) — without it the `/stream/s-2/` URL can't be
  /// built and the returned list is empty.
  List<AnimeEmbed> buildAllEmbeds({
    required int anilistId,
    required int episode,
    AnikotoSeries? series,
    String? category, // null = all 4; else filtered pair
    List<String> animeTitles = const [],
    bool isAdult = false,
  }) {
    String? embedId;
    if (series != null) {
      final ep = series.episodes
          .where((e) => e.number == episode)
          .cast<AnikotoEpisode?>()
          .firstWhere((_) => true, orElse: () => null);
      embedId = ep?.embedId;
    }

    final all = <AnimeEmbed>[];
    if (embedId != null && embedId.isNotEmpty) {
      all.addAll([
        AnimeEmbed(
          label: 'HD-1', server: 'megaplay', category: 'sub',
          url: _embed(host: 'megaplay.buzz', anilistId: anilistId, episode: episode, category: 'sub', embedId: embedId)!,
        ),
        AnimeEmbed(
          label: 'HD-2', server: 'vidwish', category: 'sub',
          url: _embed(host: 'vidwish.live', anilistId: anilistId, episode: episode, category: 'sub', embedId: embedId)!,
        ),
        AnimeEmbed(
          label: 'HD-1', server: 'megaplay', category: 'dub',
          url: _embed(host: 'megaplay.buzz', anilistId: anilistId, episode: episode, category: 'dub', embedId: embedId)!,
        ),
        AnimeEmbed(
          label: 'HD-2', server: 'vidwish', category: 'dub',
          url: _embed(host: 'vidwish.live', anilistId: anilistId, episode: episode, category: 'dub', embedId: embedId)!,
        ),
      ]);
    }
    // Miruro fallback — emit one embed per known provider per category. The
    // resolver fans them all out in parallel; whichever returns a stream
    // first wins. The episodes lookup is cached inside MiruroExtractor so all
    // parallel attempts share a single network round-trip.
    for (final cat in const ['sub', 'dub']) {
      for (final prov in MiruroExtractor.knownProviders) {
        all.add(AnimeEmbed(
          label: 'Miruro·$prov',
          server: 'miruro',
          category: cat,
          url: 'miruro://anilist/$anilistId/$episode/$cat/$prov',
        ));
      }
    }
    // AllAnime (allmanga.to) fallback — same parallel-race pattern. Only emit
    // if at least one title was provided so the extractor can search.
    final titles = animeTitles
        .where((t) => t.trim().isNotEmpty)
        .map((t) => Uri.encodeComponent(t.trim()))
        .join(',');
    if (titles.isNotEmpty) {
      for (final cat in const ['sub', 'dub']) {
        for (final prov in AllAnimeExtractor.knownProviders) {
          all.add(AnimeEmbed(
            label: 'AllAnime·$prov',
            server: 'allanime',
            category: cat,
            url: 'allanime://search/$episode/$cat/$prov?t=$titles',
          ));
        }
      }
    }
    // WatchHentai — only for adult titles. Single embed; the extractor
    // searches watchhentai.net's catalog for any of the provided titles.
    if (isAdult && titles.isNotEmpty) {
      all.add(AnimeEmbed(
        label: 'WatchHentai',
        server: 'watchhentai',
        category: 'sub',
        url: 'watchhentai://discover/$episode?t=$titles',
      ));
      all.add(AnimeEmbed(
        label: 'Hentaini',
        server: 'hentaini',
        category: 'sub',
        url: 'hentaini://discover/$episode?t=$titles',
      ));
    }
    if (category == null) return all;
    return all.where((e) => e.category == category).toList();
  }

  /// Referer to spoof when extracting megaplay/vidwish embeds. They block
  /// direct page loads — extraction only works when this header is present.
  static const String embedReferer = 'https://www.enma.lol/';

  /// Direct HTTP extractor for megaplay.buzz / vidwish.live embeds.
  ///
  /// Both providers expose the same internal API:
  ///   1. GET /stream/s-2/{id}/{lang}     → HTML containing `data-id="..."`
  ///   2. GET /stream/getSources?id={dataId} → JSON { sources:{file}, tracks:[] }
  ///
  /// No webview / JS execution required. Returns null on failure so callers
  /// can fall back to the headless extractor.
  Future<AnimeStreamResult?> extractDirect(AnimeEmbed embed) async {
    if (embed.server == 'miruro') {
      return _extractMiruro(embed);
    }
    if (embed.server == 'allanime') {
      return _extractAllAnime(embed);
    }
    if (embed.server == 'watchhentai') {
      return _extractWatchHentai(embed);
    }
    if (embed.server == 'hentaini') {
      return _extractHentaini(embed);
    }
    try {
      final embedUri = Uri.parse(embed.url);
      final origin = '${embedUri.scheme}://${embedUri.host}';

      // Step 1: fetch embed HTML to extract data-id
      final pageReq = await _client.getUrl(embedUri);
      pageReq.headers
        ..set('Referer', embedReferer)
        ..set('User-Agent',
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36')
        ..set('Accept',
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8');
      final pageRes = await pageReq.close();
      if (pageRes.statusCode != 200) {
        if (kDebugMode) {
          debugPrint('[extractDirect] embed page HTTP ${pageRes.statusCode}');
        }
        return null;
      }
      final html = await pageRes.transform(utf8.decoder).join();
      final m = RegExp(r'data-id\s*=\s*"(\d+)"').firstMatch(html);
      if (m == null) {
        if (kDebugMode) debugPrint('[extractDirect] data-id not found');
        return null;
      }
      final dataId = m.group(1)!;

      // Step 2: fetch sources JSON
      final apiUri = Uri.parse('$origin/stream/getSources?id=$dataId');
      final apiReq = await _client.getUrl(apiUri);
      apiReq.headers
        ..set('Referer', embed.url)
        ..set('Origin', origin)
        ..set('X-Requested-With', 'XMLHttpRequest')
        ..set('User-Agent',
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36')
        ..set('Accept', 'application/json, text/plain, */*');
      final apiRes = await apiReq.close();
      if (apiRes.statusCode != 200) {
        if (kDebugMode) {
          debugPrint('[extractDirect] getSources HTTP ${apiRes.statusCode}');
        }
        return null;
      }
      final body = await apiRes.transform(utf8.decoder).join();
      final json = jsonDecode(body);
      final file = (json['sources'] is Map ? json['sources']['file'] : null)
          as String?;
      if (file == null || file.isEmpty) {
        if (kDebugMode) debugPrint('[extractDirect] no sources.file');
        return null;
      }
      final tracks = <AnimeTrack>[];
      final rawTracks = json['tracks'];
      if (rawTracks is List) {
        for (final t in rawTracks) {
          if (t is Map &&
              t['file'] is String &&
              ((t['kind'] ?? 'captions') == 'captions' ||
                  (t['kind'] ?? '') == 'subtitles')) {
            tracks.add(AnimeTrack(
              url: t['file'] as String,
              label: (t['label'] as String?) ?? 'Unknown',
              isDefault: t['default'] == true,
            ));
          }
        }
      }
      if (kDebugMode) {
        debugPrint('[extractDirect] OK file=$file tracks=${tracks.length}');
      }
      return AnimeStreamResult(
        url: file,
        referer: '$origin/',
        origin: origin,
        tracks: tracks,
      );
    } catch (e, st) {
      if (kDebugMode) debugPrint('[extractDirect] error: $e\n$st');
      return null;
    }
  }

  // Miruro extractor — uses the secure-pipe API to resolve a direct HLS
  // stream + subtitle tracks from any AniList episode/category. Sentinel URL
  // format is `miruro://anilist/{anilistId}/{episode}/{category}`.
  final MiruroExtractor _miruro = MiruroExtractor();

  Future<AnimeStreamResult?> _extractMiruro(AnimeEmbed embed) async {
    final m = RegExp(r'^miruro://anilist/(\d+)/(\d+)/(sub|dub)/([a-z0-9]+)$')
        .firstMatch(embed.url);
    if (m == null) return null;
    final anilistId = int.parse(m.group(1)!);
    final ep = int.parse(m.group(2)!);
    final cat = m.group(3)!;
    final provider = m.group(4)!;

    final res = await _miruro.extractWithProvider(
      anilistId: anilistId,
      episodeNumber: ep,
      category: cat,
      provider: provider,
    );
    if (res == null) return null;

    return AnimeStreamResult(
      url: res.url,
      referer: res.referer,
      origin: res.origin,
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

  // AllAnime extractor — sentinel URL format:
  //   allanime://search/{episode}/{category}/{provider}?t={enc_title1},{enc_title2}
  final AllAnimeExtractor _allanime = AllAnimeExtractor();
  final WatchHentaiExtractor _watchHentai = WatchHentaiExtractor();
  final HentainiExtractor _hentaini = HentainiExtractor();

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

    final res = await _allanime.extractWithProvider(
      titleCandidates: titles,
      episodeNumber: ep,
      category: cat,
      provider: provider,
    );
    if (res == null) return null;

    return AnimeStreamResult(
      url: res.url,
      referer: res.referer,
      origin: res.origin,
      tracks: res.tracks
          .map((t) => AnimeTrack(
                url: t.url,
                label: t.label.isNotEmpty ? t.label : 'Unknown',
                isDefault: t.isDefault,
              ))
          .toList(),
    );
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
    final res = await _watchHentai.extract(
      titleCandidates: titles,
      episode: ep,
    );
    if (res == null) return null;
    return AnimeStreamResult(
      url: res.url,
      referer: res.referer,
      origin: res.origin,
    );
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
    final res = await _hentaini.extract(
      titleCandidates: titles,
      episode: ep,
    );
    if (res == null) return null;
    return AnimeStreamResult(
      url: res.url,
      referer: res.referer,
      origin: res.origin,
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

  const AnimeEpisode({
    required this.number,
    required this.title,
    this.aired = true,
    this.thumbnail,
  });
}

class AnimeEmbed {
  final String label;     // 'HD-1' | 'HD-2'
  final String server;    // 'megaplay' | 'vidwish'
  final String category;  // 'sub' | 'dub'
  final String url;

  const AnimeEmbed({
    required this.label,
    required this.server,
    required this.category,
    required this.url,
  });

  String get displayName {
    switch (server) {
      case 'miruro':
        return 'Miruro · ${category.toUpperCase()}';
      case 'allanime':
        return 'AllAnime · ${category.toUpperCase()}';
      case 'watchhentai':
        return 'WatchHentai';
      case 'hentaini':
        return 'Hentaini';
      default:
        return '$label · ${category.toUpperCase()}';
    }
  }
  String get refererOrigin {
    switch (server) {
      case 'vidwish':
        return 'https://vidwish.live';
      case 'miruro':
        return 'https://www.miruro.tv';
      case 'allanime':
        return 'https://allmanga.to';
      case 'watchhentai':
        return 'https://watchhentai.net';
      case 'hentaini':
        return 'https://hentaini.com';
      default:
        return 'https://megaplay.buzz';
    }
  }
}

/// Result of a successful stream extraction.
class AnimeStreamResult {
  final String url;       // m3u8 / mp4
  final String referer;   // header to send to CDN
  final String origin;    // header to send to CDN
  final List<AnimeTrack> tracks;

  const AnimeStreamResult({
    required this.url,
    required this.referer,
    required this.origin,
    this.tracks = const [],
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
  final List<AnikotoEpisode> episodes;
  const AnikotoSeries({required this.id, required this.episodes});
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
