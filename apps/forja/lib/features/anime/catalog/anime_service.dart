// Anime backend — AniList GraphQL for metadata, megaplay/vidwish for streams.
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
    AnikotoSeries? s;
    try {
      final data = await anikotoResolveSeries(
        anilistId: anime.id,
        titleEnglish: anime.titleEnglish,
        titleRomaji: anime.titleRomaji,
        expectedEpisodes: anime.episodes ?? 0,
      );
      if (data != null) {
        s = AnikotoSeries(
          id: data.id,
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
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Anikoto] resolve failed: $e');
    }
    _anikotoCache[anime.id] = s;
    return s;
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

  // ─── Stream embed URLs (Megaplay / Vidwish) ────────────────────
  // Paths/hosts from [ProviderRuntimeConfig] (RFC-039); builtins match
  // megaplay.buzz/api (s-2 catalog + /stream/ani/ AniList).

  String _embed({
    required String server, // 'megaplay' | 'vidwish'
    required int anilistId,
    required int episode,
    required String category,
    String? embedId, // anikoto episode_embed_id
  }) {
    final cfg = server == 'vidwish'
        ? ProviderRuntimeConfig.instance.vidwish
        : ProviderRuntimeConfig.instance.megaplay;
    return cfg.buildUrl(
      anilistId: anilistId,
      episode: episode,
      lang: category,
      embedId: embedId,
    );
  }

  /// Build Megaplay/Vidwish + Miruro/AllAnime/VidNest embeds for an episode.
  ///
  /// Megaplay/Vidwish always emit: Anikoto `s-2` when matched, else `/stream/ani/`.
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

    final all = <AnimeEmbed>[
      AnimeEmbed(
        label: AnimeStreamProviders.displayName('megaplay'),
        server: 'megaplay',
        category: 'sub',
        url: _embed(
          server: 'megaplay',
          anilistId: anilistId,
          episode: episode,
          category: 'sub',
          embedId: embedId,
        ),
      ),
      AnimeEmbed(
        label: AnimeStreamProviders.displayName('vidwish'),
        server: 'vidwish',
        category: 'sub',
        url: _embed(
          server: 'vidwish',
          anilistId: anilistId,
          episode: episode,
          category: 'sub',
          embedId: embedId,
        ),
      ),
      AnimeEmbed(
        label: AnimeStreamProviders.displayName('megaplay'),
        server: 'megaplay',
        category: 'dub',
        url: _embed(
          server: 'megaplay',
          anilistId: anilistId,
          episode: episode,
          category: 'dub',
          embedId: embedId,
        ),
      ),
      AnimeEmbed(
        label: AnimeStreamProviders.displayName('vidwish'),
        server: 'vidwish',
        category: 'dub',
        url: _embed(
          server: 'vidwish',
          anilistId: anilistId,
          episode: episode,
          category: 'dub',
          embedId: embedId,
        ),
      ),
    ];
    // Miruro fallback — emit one embed per known provider per category. The
    // resolver fans them all out in parallel; whichever returns a stream
    // first wins. The episodes lookup is cached inside MiruroExtractor so all
    // parallel attempts share a single network round-trip.
    for (final cat in const ['sub', 'dub']) {
      for (final prov in miruroKnownProviders) {
        all.add(AnimeEmbed(
          label: AnimeStreamProviders.displayName('miruro:$prov'),
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
    // AnimeRealms removed — upstream /api/watch is gone (see changelog).
    // VidNest — AniList-native API (HiAnime + AnimePahe mirrors).
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

  /// Referer to spoof when extracting megaplay/vidwish embeds. They block
  /// direct page loads — extraction only works when this header is present.
  static String get embedReferer =>
      ProviderRuntimeConfig.instance.megaplay.scrapeReferer;

  /// Direct HTTP extractor for megaplay.buzz / vidwish.live embeds.
  ///
  /// Both providers expose the same internal API:
  ///   1. GET /stream/s-2/{id}/{lang}     → HTML containing `data-id="..."`
  ///   2. GET /stream/getSources?id={dataId} → JSON { sources:{file}, tracks:[] }
  /// Resolve one or more playable URLs for [embed]. Miruro may return several
  /// CDN mirrors per provider; other servers return at most one.
  Future<List<AnimeStreamResult>> extractDirectCandidates(AnimeEmbed embed) async {
    if (embed.server == 'miruro') {
      return _extractMiruroAll(embed);
    }
    final one = await extractDirect(embed);
    return one != null ? [one] : const [];
  }

  Future<AnimeStreamResult?> extractDirect(AnimeEmbed embed) async {
    if (embed.server == 'miruro') {
      return _extractMiruro(embed);
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
        return AnimeStreamPref(
          sourceKey: key,
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

  /// Vidwish still prefers Anikoto `s-2` ids (AniList mapping is spotty).
  /// Megaplay works via `/stream/ani/` without Anikoto. Auto still resolves
  /// Anikoto so Vidwish can use `s-2` when available.
  static bool savedSourceNeedsAnikoto(String? sourceKey) {
    if (sourceKey == null || sourceKey.isEmpty) return true;
    if (sourceKey == 'megaplay') return false;
    return sourceKey == 'vidwish';
  }

  /// Lightweight reachability check before replaying cached stream URLs.
  ///
  /// Always runs [resolvePlaybackHttpHeaders] first — anime CDNs (nekostream /
  /// mewstream) 403 without the Megaplay Referer, and cache/reload paths often
  /// still carry scrape (`enma.lol`) or Miruro origins.
  Future<bool> probeStreamUrl(
    String url,
    Map<String, String> headers,
  ) async {
    if (url.isEmpty) return false;
    try {
      final hdrs = resolvePlaybackHttpHeaders(headers, streamUrl: url);
      return await probeStreamUrlRust(url, hdrs);
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
      if (await probeStreamUrl(url, headers)) return true;
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

class AnimeStreamPref {
  final String sourceKey;
  final String? sourceTitle;

  const AnimeStreamPref({required this.sourceKey, this.sourceTitle});
}

class AnimeEmbed {
  final String label;     // real upstream name, e.g. Megaplay, HiAnime
  final String server;    // 'megaplay' | 'vidwish'
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
      case 'vidwish':
        return 'https://${ProviderRuntimeConfig.instance.vidwish.host}';
      case 'miruro':
        final o = MiruroDomains.primary;
        return o.endsWith('/') ? o.substring(0, o.length - 1) : o;
      case 'allanime':
        return 'https://allmanga.to';
      case 'vidnest':
        return 'https://vidnest.fun';
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
  final List<AnikotoEpisode> episodes;
  const AnikotoSeries({required this.id, required this.episodes});
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
