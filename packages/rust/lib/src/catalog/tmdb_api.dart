import 'dart:convert';

import 'package:rust/rust.dart';

class TmdbApi {
  static const String _imageBaseUrl = 'https://image.tmdb.org/t/p/w500';

  static Future<dynamic> _fetch(String resourcePath, {int timeoutSecs = 15}) async {
    final raw = await runTmdbGetJson(resourcePath, timeoutSecs: timeoutSecs);
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic> && decoded['error'] != null) {
      throw Exception(decoded['error']);
    }
    return decoded;
  }

  static Future<Map<String, dynamic>> _fetchMap(
    String resourcePath, {
    int timeoutSecs = 15,
  }) async {
    return await _fetch(resourcePath, timeoutSecs: timeoutSecs) as Map<String, dynamic>;
  }

  /// High-res backdrop for hero banners / full-width headers.
  static String getBackdropUrl(String path) => 'https://image.tmdb.org/t/p/w1280$path';

  /// Small profile photo for cast lists.
  static String getProfileUrl(String path) => 'https://image.tmdb.org/t/p/w185$path';

  /// Tiny still/thumbnail for episode lists.
  static String getStillUrl(String path) => 'https://image.tmdb.org/t/p/w300$path';

  /// Full original quality — only use when absolutely needed.
  static String getOriginalUrl(String path) => 'https://image.tmdb.org/t/p/original$path';

  Future<List<Movie>> getTrending({int page = 1}) async {
    final decoded = await _fetchMap('trending/movie/day?page=$page');
    return (decoded['results'] as List).map((json) => Movie.fromJson(json, mediaType: 'movie')).toList();
  }

  Future<List<Movie>> getTrendingTv({int page = 1}) async {
    final decoded = await _fetchMap('trending/tv/day?page=$page');
    return (decoded['results'] as List).map((json) => Movie.fromJson(json, mediaType: 'tv')).toList();
  }

  /// KissKH hub countries (excl. US/Hollywood): KR / CN+TW+HK / JP / TH / PH.
  static const asianDramaOriginalLanguages = {
    'ko',
    'ja',
    'zh',
    'th',
    'tl',
  };

  /// Today's trending TV filtered to Asian Drama languages, backfilled from
  /// discover popularity when trending is thin. Used by Asian Drama → Popular.
  Future<List<Movie>> getPopularAsianTvToday({int limit = 20}) async {
    final seen = <int>{};
    final out = <Movie>[];

    void take(Map<String, dynamic> json) {
      final ol =
          (json['original_language'] as String?)?.trim().toLowerCase() ?? '';
      if (!asianDramaOriginalLanguages.contains(ol)) return;
      final m = Movie.fromJson(json, mediaType: 'tv');
      if (m.id <= 0 || !seen.add(m.id)) return;
      if (m.posterPath.isEmpty && m.backdropPath.isEmpty) return;
      out.add(m);
    }

    for (var page = 1; page <= 3 && out.length < limit; page++) {
      final decoded = await _fetchMap('trending/tv/day?page=$page');
      for (final raw in decoded['results'] as List? ?? const []) {
        if (raw is! Map) continue;
        take(Map<String, dynamic>.from(raw));
        if (out.length >= limit) break;
      }
    }

    if (out.length < limit) {
      final langs = asianDramaOriginalLanguages.join('|');
      final decoded = await _fetchMap(
        'discover/tv?page=1&sort_by=popularity.desc'
        '&with_original_language=$langs&vote_count.gte=50',
      );
      for (final raw in decoded['results'] as List? ?? const []) {
        if (raw is! Map) continue;
        take(Map<String, dynamic>.from(raw));
        if (out.length >= limit) break;
      }
    }

    return out.take(limit).toList();
  }

  /// Website-style popular: discover sorted by popularity with a minimum vote
  /// floor so low-signal titles from raw `/popular` do not dominate the row.
  Future<List<Movie>> getPopular({String? watchRegion, int page = 1}) {
    return discoverMovies(
      watchRegion: watchRegion ?? TmdbWatchRegion.current,
      sortBy: 'popularity.desc',
      minVoteCount: 100,
      page: page,
    );
  }

  Future<List<Movie>> getPopularTv({String? watchRegion, int page = 1}) {
    return discoverTvShows(
      watchRegion: watchRegion ?? TmdbWatchRegion.current,
      sortBy: 'popularity.desc',
      minVoteCount: 100,
      page: page,
    );
  }

  Future<List<Movie>> getTopRated({int page = 1}) async {
    final decoded = await _fetchMap('movie/top_rated?page=$page');
    return (decoded['results'] as List).map((json) => Movie.fromJson(json, mediaType: 'movie')).toList();
  }

  Future<List<Movie>> getNowPlaying({int page = 1}) async {
    final decoded = await _fetchMap('movie/now_playing?page=$page');
    return (decoded['results'] as List).map((json) => Movie.fromJson(json, mediaType: 'movie')).toList();
  }

  Future<List<Movie>> getOnTheAir({int page = 1}) async {
    final decoded = await _fetchMap('tv/on_the_air?page=$page');
    return (decoded['results'] as List).map((json) => Movie.fromJson(json, mediaType: 'tv')).toList();
  }

  Future<List<String>> getBackdrops(
    int id, {
    String mediaType = 'movie',
    int limit = 12,
  }) async {
    try {
      final type = mediaType == 'tv' ? 'tv' : 'movie';
      final decoded = await _fetchMap('$type/$id/images');
      final backdrops = decoded['backdrops'] as List? ?? const [];
      return backdrops
          .take(limit)
          .map((e) => (e['file_path'] as String?) ?? '')
          .where((p) => p.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetch the English clear logo for a movie or TV show.
  /// Returns the logo file_path or empty string if none found.
  Future<String> getLogoPath(int id, {String mediaType = 'movie'}) async {
    try {
      final type = mediaType == 'tv' ? 'tv' : 'movie';
      final decoded = await _fetchMap('$type/$id/images?include_image_language=en,null');
      final logos = decoded['logos'] as List? ?? [];
      if (logos.isEmpty) return '';
      final enLogo = logos.firstWhere(
        (e) => e['iso_639_1'] == 'en',
        orElse: () => logos.first,
      );
      return enLogo['file_path'] as String? ?? '';
    } catch (_) {}
    return '';
  }

  Future<Movie> getMovieDetails(int movieId) async {
    final json = await _fetchMap(
      'movie/$movieId?append_to_response=images,external_ids',
    );

    final images = json['images'];
    final backdrops = (images != null && images['backdrops'] != null)
        ? (images['backdrops'] as List).map((e) => e['file_path'] as String).toList()
        : <String>[];

    String logoPath = '';
    if (images != null && images['logos'] != null) {
      final logos = images['logos'] as List;
      final enLogo = logos.firstWhere(
        (e) => e['iso_639_1'] == 'en',
        orElse: () => logos.isNotEmpty ? logos.first : null,
      );
      if (enLogo != null) {
        logoPath = enLogo['file_path'];
      }
    }

    return Movie.fromJson(json, mediaType: 'movie').copyWith(
      imdbId: json['imdb_id'],
      overview: json['overview'] ?? '',
      genres: (json['genres'] as List?)?.map((e) => e['name'] as String).toList() ?? [],
      runtime: json['runtime'] ?? 0,
      screenshots: backdrops,
      logoPath: logoPath,
      numberOfSeasons: json['number_of_seasons'] ?? 0,
    );
  }

  Future<Movie> getTvDetails(int tvId) async {
    final json = await _fetchMap(
      'tv/$tvId?append_to_response=images,external_ids',
    );

    final images = json['images'];
    final backdrops = (images != null && images['backdrops'] != null)
        ? (images['backdrops'] as List).map((e) => e['file_path'] as String).toList()
        : <String>[];

    String logoPath = '';
    if (images != null && images['logos'] != null) {
      final logos = images['logos'] as List;
      final enLogo = logos.firstWhere(
        (e) => e['iso_639_1'] == 'en',
        orElse: () => logos.isNotEmpty ? logos.first : null,
      );
      if (enLogo != null) {
        logoPath = enLogo['file_path'];
      }
    }

    final externalIds = json['external_ids'];
    final String? imdbId = externalIds != null ? externalIds['imdb_id'] : null;

    return Movie.fromJson(json, mediaType: 'tv').copyWith(
      imdbId: imdbId,
      overview: json['overview'] ?? '',
      genres: (json['genres'] as List?)?.map((e) => e['name'] as String).toList() ?? [],
      runtime: (json['episode_run_time'] as List?)?.isNotEmpty == true ? json['episode_run_time'][0] : 0,
      screenshots: backdrops,
      logoPath: logoPath,
      numberOfSeasons: json['number_of_seasons'] ?? 0,
    );
  }

  Future<Map<String, dynamic>> getTvSeasonDetails(int tvId, int seasonNumber) async {
    return _fetchMap('tv/$tvId/season/$seasonNumber');
  }

  Future<List<Movie>> searchMulti(String query, {int page = 1}) async {
    final decoded = await _fetchMap(
      'search/multi?query=${Uri.encodeComponent(query)}&page=$page',
    );
    return (decoded['results'] as List)
        .where((json) => json['media_type'] == 'movie' || json['media_type'] == 'tv')
        .map((json) => Movie.fromJson(json))
        .toList();
  }

  Future<List<TmdbPersonHit>> searchPerson(String query) async {
    final decoded =
        await _fetchMap('search/person?query=${Uri.encodeComponent(query)}');
    return (decoded['results'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (json) => TmdbPersonHit(
            id: (json['id'] as num?)?.toInt() ?? 0,
            name: (json['name'] ?? '').toString(),
            popularity: (json['popularity'] as num?)?.toDouble() ?? 0,
          ),
        )
        .where((p) => p.id > 0 && p.name.isNotEmpty)
        .toList();
  }

  /// Title multi-search plus discover for year / genre / person (e.g. `nolan 2022-2025`, `horror 2025`).
  Future<List<Movie>> searchStructured(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final parsed = parseSearchQuery(trimmed);
    final bounds = parsed.yearBounds;

    Future<List<Movie>> safe(Future<List<Movie>> Function() run) async {
      try {
        return await run();
      } catch (_) {
        return const [];
      }
    }

    final multiFutures = <Future<List<Movie>>>[
      safe(() => searchMulti(trimmed)),
      safe(() => searchMulti(trimmed, page: 2)),
    ];
    if (parsed.remainder.isNotEmpty &&
        parsed.remainder.toLowerCase() != trimmed.toLowerCase()) {
      multiFutures.add(safe(() => searchMulti(parsed.remainder)));
      multiFutures.add(safe(() => searchMulti(parsed.remainder, page: 2)));
    }

    int? personId;
    if (parsed.hasPersonCandidate) {
      personId = await _resolvePersonId(parsed.remainder);
    }

    final gte = bounds != null ? '${bounds.$1}-01-01' : null;
    final lte = bounds != null ? '${bounds.$2}-12-31' : null;
    final singleYear =
        bounds != null && bounds.$1 == bounds.$2 ? bounds.$1 : null;

    final discoverFutures = <Future<List<Movie>>>[];

    // TMDB returns 20/page; desktop grid is 4 cols → page1≈5 rows.
    // Fetch a second page for +5 rows on filter/discover results.
    const discoverPages = 2;

    void addMovieDiscover({List<int>? genres, int? people}) {
      for (var page = 1; page <= discoverPages; page++) {
        discoverFutures.add(
          safe(
            () => discoverMovies(
              genres: genres,
              withPeople: people,
              year: singleYear,
              releaseDateGte: singleYear == null ? gte : null,
              releaseDateLte: singleYear == null ? lte : null,
              minRating: parsed.minScore,
              maxRating: parsed.maxScore,
              withOriginCountry: parsed.originCountry,
              page: page,
            ),
          ),
        );
      }
    }

    void addTvDiscover({List<int>? genres, int? people}) {
      for (var page = 1; page <= discoverPages; page++) {
        discoverFutures.add(
          safe(
            () => discoverTvShows(
              genres: genres,
              withPeople: people,
              year: singleYear,
              releaseDateGte: singleYear == null ? gte : null,
              releaseDateLte: singleYear == null ? lte : null,
              minRating: parsed.minScore,
              maxRating: parsed.maxScore,
              withOriginCountry: parsed.originCountry,
              page: page,
            ),
          ),
        );
      }
    }

    final wantMovies =
        parsed.mediaType == null || parsed.mediaType == 'movie';
    final wantTv = parsed.mediaType == null || parsed.mediaType == 'tv';

    if (personId != null ||
        parsed.hasGenre ||
        bounds != null ||
        parsed.hasScore ||
        parsed.hasMediaType ||
        parsed.hasOriginCountry) {
      if (parsed.hasGenre) {
        if (wantMovies && parsed.movieGenreIds.isNotEmpty) {
          addMovieDiscover(genres: parsed.movieGenreIds, people: personId);
        }
        if (wantTv) {
          // Movie-only TMDB genres (Romance, Horror, …) still appear on many
          // series — fall back to movie ids so Series+Romance is not empty.
          final tvGenres = parsed.tvGenreIds.isNotEmpty
              ? parsed.tvGenreIds
              : parsed.movieGenreIds;
          if (tvGenres.isNotEmpty) {
            addTvDiscover(genres: tvGenres, people: personId);
          }
        }
      } else if (personId != null) {
        if (wantMovies) addMovieDiscover(people: personId);
        if (wantTv) addTvDiscover(people: personId);
      } else if (!parsed.hasPersonCandidate) {
        if (wantMovies) addMovieDiscover();
        if (wantTv) addTvDiscover();
      }
    }

    final lists = await Future.wait([
      ...multiFutures,
      ...discoverFutures,
    ]);

    final seen = <String>{};
    final out = <Movie>[];
    bool passesFilters(Movie m, {required bool applyYearFilter}) {
      if (applyYearFilter &&
          bounds != null &&
          !releaseDateInYearBounds(m.releaseDate, bounds)) {
        return false;
      }
      if (parsed.mediaType != null && m.mediaType != parsed.mediaType) {
        return false;
      }
      if (parsed.minScore != null && m.voteAverage < parsed.minScore!) {
        return false;
      }
      if (parsed.maxScore != null && m.voteAverage > parsed.maxScore!) {
        return false;
      }
      return true;
    }

    void addAll(List<Movie> items, {required bool applyYearFilter}) {
      for (final m in items) {
        if (!passesFilters(m, applyYearFilter: applyYearFilter)) continue;
        final key = '${m.mediaType}:${m.id}';
        if (!seen.add(key)) continue;
        out.add(m);
      }
    }

    // Skip multi-search noise when the query is filters-only (no title/person text).
    final runMulti = parsed.remainder.isNotEmpty || !parsed.hasStructuredFilters;
    for (var i = 0; i < multiFutures.length; i++) {
      if (!runMulti) continue;
      addAll(lists[i], applyYearFilter: bounds != null || parsed.hasScore || parsed.hasMediaType);
    }
    for (var i = multiFutures.length; i < lists.length; i++) {
      addAll(lists[i], applyYearFilter: parsed.hasScore || parsed.hasMediaType);
    }
    return out;
  }

  Future<int?> _resolvePersonId(String text) async {
    final hits = await searchPerson(text);
    if (hits.isEmpty) return null;
    final q = text.toLowerCase().trim();
    final tokens = q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    for (final p in hits.take(8)) {
      final name = p.name.toLowerCase();
      if (name == q) return p.id;
      if (tokens.every(name.contains)) return p.id;
    }
    final top = hits.first;
    if (top.popularity >= 3.0) return top.id;
    return null;
  }

  Future<List<Movie>> searchMovies(String query) async {
    final decoded = await _fetchMap('search/movie?query=${Uri.encodeComponent(query)}');
    return (decoded['results'] as List).map((json) => Movie.fromJson(json, mediaType: 'movie')).toList();
  }

  Future<List<Movie>> searchTvShows(String query) async {
    final decoded = await _fetchMap('search/tv?query=${Uri.encodeComponent(query)}');
    return (decoded['results'] as List).map((json) => Movie.fromJson(json, mediaType: 'tv')).toList();
  }

  Future<List<Map<String, dynamic>>> getMovieGenres() async {
    final decoded = await _fetchMap('genre/movie/list');
    return (decoded['genres'] as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getTvGenres() async {
    final decoded = await _fetchMap('genre/tv/list');
    return (decoded['genres'] as List).cast<Map<String, dynamic>>();
  }

  static const List<WatchProvider> fallbackWatchProviders = [
    WatchProvider(id: 8, name: 'Netflix', logoPath: '/pbpMk2JmcoNnQwx5JGpXngfoWtp.jpg'),
    WatchProvider(id: 337, name: 'Disney Plus', logoPath: '/97yvRBw1GzX7fXprcF80er19ot.jpg'),
    WatchProvider(id: 9, name: 'Prime Video', logoPath: '/pvske1MyAoymrs5bguRfVqYiM9a.jpg'),
    WatchProvider(id: 350, name: 'Apple TV+', logoPath: '/mcbz1LgtErU9p4UdbZ0rG6RTWHX.jpg'),
    WatchProvider(id: 1899, name: 'Max', logoPath: '/jbe4gVSfRlbPTdESXhEKpornsfu.jpg'),
    WatchProvider(id: 15, name: 'Hulu', logoPath: '/bxBlRPEPpMVDc4jMhSrTf2339DW.jpg'),
    WatchProvider(id: 2303, name: 'Paramount+', logoPath: '/fts6X10Jn4QT0X6ac3udKEn2tJA.jpg'),
    WatchProvider(id: 386, name: 'Peacock', logoPath: '/2aGrp1xw3qhwCYvNGAJZPdjfeeX.jpg'),
    WatchProvider(id: 283, name: 'Crunchyroll', logoPath: '/fzN5Jok5Ig1eJ7gyNGoMhnLSCfh.jpg'),
    WatchProvider(id: 73, name: 'Tubi', logoPath: '/zLYr7OPvpskMA4S79E3vlCi71iC.jpg'),
    WatchProvider(id: 300, name: 'Pluto TV', logoPath: '/4nTKDysENfAwArWP6XDNLmntQ3.png'),
    WatchProvider(id: 43, name: 'Starz', logoPath: '/giYWxN6DcOQGXYInphosLu3K5m.png'),
  ];

  /// Top flatrate watch providers for a region (used by Home top-bar filter).
  Future<List<WatchProvider>> getTopWatchProviders({
    int limit = 24,
    String? region,
  }) async {
    final watchRegion = region ?? TmdbWatchRegion.current;
    try {
      final decoded = await _fetchMap('watch/providers/movie?watch_region=$watchRegion');
      final results = (decoded['results'] as List? ?? [])
          .map((json) => WatchProvider.fromJson(json as Map<String, dynamic>))
          .where((p) => p.logoPath.isNotEmpty)
          .take(limit)
          .toList();
      if (results.isNotEmpty) return results;
    } catch (_) {}
    return fallbackWatchProviders.take(limit).toList();
  }

  Future<List<Movie>> discoverMovies({
    List<int>? genres,
    int? year,
    String? releaseDateGte,
    String? releaseDateLte,
    double? minRating,
    double? maxRating,
    int? minVoteCount,
    String? language,
    int? watchProviderId,
    int? withPeople,
    int? withCompanies,
    String? withOriginCountry,
    String? watchRegion,
    String sortBy = 'popularity.desc',
    int page = 1,
  }) async {
    final region = watchRegion ?? TmdbWatchRegion.current;
    var path = 'discover/movie?page=$page&watch_region=$region&sort_by=$sortBy';
    if (genres != null && genres.isNotEmpty) {
      path += '&with_genres=${genres.join(',')}';
    }
    if (year != null) {
      path += '&primary_release_year=$year';
    }
    if (releaseDateGte != null) {
      path += '&primary_release_date.gte=$releaseDateGte';
    }
    if (releaseDateLte != null) {
      path += '&primary_release_date.lte=$releaseDateLte';
    }
    if (minRating != null) {
      path += '&vote_average.gte=$minRating';
    }
    if (maxRating != null) {
      path += '&vote_average.lte=$maxRating';
    }
    if (minVoteCount != null) {
      path += '&vote_count.gte=$minVoteCount';
    }
    if (language != null) {
      path += '&with_original_language=$language';
    }
    if (watchProviderId != null) {
      path +=
          '&with_watch_providers=${WatchProviderFamily.orQuery(WatchProviderFamily.watchIdsFor(watchProviderId))}';
    }
    if (withPeople != null) {
      path += '&with_people=$withPeople';
    }
    if (withCompanies != null) {
      path += '&with_companies=$withCompanies';
    }
    if (withOriginCountry != null && withOriginCountry.isNotEmpty) {
      path += '&with_origin_country=$withOriginCountry';
    }

    final decoded = await _fetchMap(path);
    return (decoded['results'] as List).map((json) => Movie.fromJson(json, mediaType: 'movie')).toList();
  }

  Future<List<Movie>> discoverTvShows({
    List<int>? genres,
    int? year,
    String? releaseDateGte,
    String? releaseDateLte,
    double? minRating,
    double? maxRating,
    int? minVoteCount,
    String? language,
    int? watchProviderId,
    int? withPeople,
    int? withCompanies,
    int? withNetworks,
    String? withOriginCountry,
    String? watchRegion,
    String sortBy = 'popularity.desc',
    int page = 1,
  }) async {
    final region = watchRegion ?? TmdbWatchRegion.current;
    final watchIds = watchProviderId == null
        ? const <int>[]
        : WatchProviderFamily.watchIdsFor(watchProviderId);
    final familyNetworks =
        watchProviderId != null && withNetworks == null
            ? WatchProviderFamily.tvNetworkIdsFor(watchProviderId)
            : const <int>[];

    Future<List<Movie>> fetch({
      String? watchProviders,
      String? networks,
    }) async {
      var path = 'discover/tv?page=$page&watch_region=$region&sort_by=$sortBy';
      if (genres != null && genres.isNotEmpty) {
        path += '&with_genres=${genres.join(',')}';
      }
      if (year != null) {
        path += '&first_air_date_year=$year';
      }
      if (releaseDateGte != null) {
        path += '&first_air_date.gte=$releaseDateGte';
      }
      if (releaseDateLte != null) {
        path += '&first_air_date.lte=$releaseDateLte';
      }
      if (minRating != null) {
        path += '&vote_average.gte=$minRating';
      }
      if (maxRating != null) {
        path += '&vote_average.lte=$maxRating';
      }
      if (minVoteCount != null) {
        path += '&vote_count.gte=$minVoteCount';
      }
      if (language != null) {
        path += '&with_original_language=$language';
      }
      if (watchProviders != null && watchProviders.isNotEmpty) {
        path += '&with_watch_providers=$watchProviders';
      }
      if (withPeople != null) {
        path += '&with_people=$withPeople';
      }
      if (withCompanies != null) {
        path += '&with_companies=$withCompanies';
      }
      if (networks != null && networks.isNotEmpty) {
        path += '&with_networks=$networks';
      } else if (withNetworks != null) {
        path += '&with_networks=$withNetworks';
      }
      if (withOriginCountry != null && withOriginCountry.isNotEmpty) {
        path += '&with_origin_country=$withOriginCountry';
      }

      final decoded = await _fetchMap(path);
      return (decoded['results'] as List)
          .map((json) => Movie.fromJson(json, mediaType: 'tv'))
          .toList();
    }

    if (familyNetworks.isEmpty) {
      return fetch(
        watchProviders:
            watchIds.isEmpty ? null : WatchProviderFamily.orQuery(watchIds),
      );
    }

    final parts = await Future.wait([
      fetch(watchProviders: WatchProviderFamily.orQuery(watchIds)),
      fetch(networks: WatchProviderFamily.orQuery(familyNetworks)),
    ]);
    return _uniqueMovies(parts[0], parts[1]);
  }

  static List<Movie> _uniqueMovies(List<Movie> primary, List<Movie> extra) {
    final out = <Movie>[];
    final seen = <String>{};
    void add(Movie movie) {
      final key = '${movie.mediaType}:${movie.id}';
      if (seen.add(key)) out.add(movie);
    }

    for (final movie in primary) {
      add(movie);
    }
    for (final movie in extra) {
      add(movie);
    }
    return out;
  }

  /// Titles related to [seed] by TMDB recs/similar + genre/year/lang/people/studio.
  /// Never includes [seed] or [exclude] (case-insensitive). Cap [max].
  Future<List<String>> contextualSearchTitles(
    Movie seed, {
    Iterable<String> exclude = const [],
    int max = 64,
  }) async {
    final isTv = seed.mediaType == 'tv';
    final type = isTv ? 'tv' : 'movie';
    final seen = <String>{
      for (final e in exclude)
        if (e.trim().isNotEmpty) e.trim().toLowerCase(),
    };
    final seedTitle = seed.title.trim();
    if (seedTitle.isNotEmpty) seen.add(seedTitle.toLowerCase());

    Map<String, dynamic> details = const {};
    try {
      details = await _fetchMap(
        '$type/${seed.id}?append_to_response=credits',
        timeoutSecs: 10,
      );
    } catch (_) {}

    final genreIds = (details['genres'] as List? ?? const [])
        .whereType<Map>()
        .map((g) => g['id'])
        .whereType<int>()
        .take(2)
        .toList();
    final dateRaw = (details['release_date'] ??
            details['first_air_date'] ??
            seed.releaseDate)
        .toString();
    final year = int.tryParse(
      dateRaw.length >= 4 ? dateRaw.substring(0, 4) : '',
    );
    final language = (details['original_language'] as String?)?.trim();
    final companies = details['production_companies'] as List? ?? const [];
    int? companyId;
    for (final c in companies) {
      if (c is Map && c['id'] is int) {
        companyId = c['id'] as int;
        break;
      }
    }
    final networks = details['networks'] as List? ?? const [];
    int? networkId;
    for (final n in networks) {
      if (n is Map && n['id'] is int) {
        networkId = n['id'] as int;
        break;
      }
    }

    int? personId;
    final credits = details['credits'];
    if (credits is Map) {
      final crew = credits['crew'] as List? ?? const [];
      for (final raw in crew) {
        if (raw is! Map) continue;
        final job = (raw['job'] ?? '').toString();
        if (job == 'Director' || job == 'Creator' || job == 'Executive Producer') {
          final id = raw['id'];
          if (id is int) {
            personId = id;
            break;
          }
        }
      }
      if (personId == null) {
        final createdBy = details['created_by'] as List? ?? const [];
        for (final raw in createdBy) {
          if (raw is! Map) continue;
          final id = raw['id'];
          if (id is int) {
            personId = id;
            break;
          }
        }
      }
    }

    Future<List<Movie>> safe(Future<List<Movie>> Function() run) async {
      try {
        return await run();
      } catch (_) {
        return const [];
      }
    }

    final lists = await Future.wait([
      safe(() => isTv
          ? getTvRecommendations(seed.id)
          : getMovieRecommendations(seed.id)),
      safe(() => isTv ? getSimilarTvShows(seed.id) : getSimilarMovies(seed.id)),
      if (genreIds.isNotEmpty)
        safe(() => isTv
            ? discoverTvShows(genres: genreIds, year: year)
            : discoverMovies(genres: genreIds, year: year)),
      if (genreIds.isNotEmpty)
        safe(() => isTv
            ? discoverTvShows(genres: genreIds)
            : discoverMovies(genres: genreIds)),
      if (genreIds.isNotEmpty && language != null && language.isNotEmpty)
        safe(() => isTv
            ? discoverTvShows(genres: genreIds, language: language)
            : discoverMovies(genres: genreIds, language: language)),
      if (personId != null)
        safe(() => isTv
            ? discoverTvShows(withPeople: personId)
            : discoverMovies(withPeople: personId)),
      if (isTv && networkId != null)
        safe(() => discoverTvShows(withNetworks: networkId)),
      if (!isTv && companyId != null)
        safe(() => discoverMovies(withCompanies: companyId)),
    ]);

    final queues = [for (final list in lists) List<Movie>.from(list)];
    final titles = <String>[];
    var madeProgress = true;
    while (madeProgress && titles.length < max) {
      madeProgress = false;
      for (final queue in queues) {
        while (queue.isNotEmpty) {
          final item = queue.removeAt(0);
          final title = item.title.trim();
          if (title.isEmpty) continue;
          if (!seen.add(title.toLowerCase())) continue;
          titles.add(title);
          madeProgress = true;
          break;
        }
        if (titles.length >= max) break;
      }
    }
    return titles;
  }

  Future<List<Movie>> getSimilarMovies(int movieId) async {
    final decoded = await _fetchMap('movie/$movieId/similar');
    return (decoded['results'] as List).map((json) => Movie.fromJson(json, mediaType: 'movie')).toList();
  }

  Future<List<Movie>> getSimilarTvShows(int tvId) async {
    final decoded = await _fetchMap('tv/$tvId/similar');
    return (decoded['results'] as List).map((json) => Movie.fromJson(json, mediaType: 'tv')).toList();
  }

  /// TMDB's curated recommendations (much better than `/similar` which is just
  /// keyword/genre overlap). For TV shows like Vampire Diaries this returns
  /// The Originals, Legacies, Teen Wolf, etc.
  Future<List<Movie>> getMovieRecommendations(int movieId) async {
    final decoded = await _fetchMap('movie/$movieId/recommendations');
    return (decoded['results'] as List)
        .map((json) => Movie.fromJson(json, mediaType: 'movie'))
        .toList();
  }

  Future<List<Movie>> getTvRecommendations(int tvId) async {
    final decoded = await _fetchMap('tv/$tvId/recommendations');
    return (decoded['results'] as List)
        .map((json) => Movie.fromJson(json, mediaType: 'tv'))
        .toList();
  }

  /// Find a movie/tv show by its IMDB ID via TMDB's /find endpoint.
  Future<Movie?> findByImdbId(String imdbId, {String mediaType = 'movie'}) async {
    final decoded = await _fetchMap('find/$imdbId?external_source=imdb_id');
    final movieResults = decoded['movie_results'] as List? ?? [];
    final tvResults = decoded['tv_results'] as List? ?? [];

    if (mediaType == 'tv' && tvResults.isNotEmpty) {
      return Movie.fromJson(tvResults.first, mediaType: 'tv');
    }
    if (movieResults.isNotEmpty) {
      return Movie.fromJson(movieResults.first, mediaType: 'movie');
    }
    if (tvResults.isNotEmpty) {
      return Movie.fromJson(tvResults.first, mediaType: 'tv');
    }
    return null;
  }

  static String getImageUrl(String path) {
    return '$_imageBaseUrl$path';
  }

  /// Fetches ordered cast list for a movie or TV show.
  /// Returns up to [limit] entries each with:
  ///   name, character, profilePath (may be empty)
  Future<List<Map<String, String>>> getCredits(
      int id, String mediaType, {int limit = 12}) async {
    final type = mediaType == 'tv' ? 'tv' : 'movie';
    try {
      final decoded = await _fetchMap('$type/$id/credits', timeoutSecs: 10);
      final cast = (decoded['cast'] as List? ?? []);
      return cast.take(limit).map<Map<String, String>>((e) => {
        'name': (e['name'] ?? '').toString(),
        'character': (e['character'] ?? '').toString(),
        'profilePath': (e['profile_path'] ?? '').toString(),
      }).toList();
    } catch (_) {
      return [];
    }
  }

  static const _richAppendMovie =
      'videos,credits,keywords,recommendations,release_dates,external_ids,images,watch/providers';
  static const _richAppendTv =
      'videos,credits,keywords,recommendations,content_ratings,external_ids,images,watch/providers';

  static List<WatchProvider> parseWatchProviders(
    Map<String, dynamic> json, {
    String? region,
  }) {
    final watchRegion = region ?? TmdbWatchRegion.current;
    final root = json['watch/providers'];
    if (root is! Map<String, dynamic>) return const [];

    final results = root['results'];
    if (results is! Map<String, dynamic> || results.isEmpty) return const [];

    var regionData = results[watchRegion];
    regionData ??= results.values.first;
    if (regionData is! Map<String, dynamic>) return const [];

    final seen = <int>{};
    final providers = <WatchProvider>[];
    for (final key in ['flatrate', 'free', 'ads']) {
      final list = regionData[key] as List? ?? [];
      for (final raw in list) {
        if (raw is! Map<String, dynamic>) continue;
        final provider = WatchProvider.fromJson(raw);
        if (provider.logoPath.isEmpty) continue;
        if (seen.add(provider.id)) providers.add(provider);
      }
    }
    return providers;
  }

  static String? parseTrailerYoutubeKey(Map<String, dynamic> json) {
    final trailers = parseTrailers(json);
    for (final t in trailers) {
      if (t.type == 'Trailer' && t.official) return t.key;
    }
    for (final t in trailers) {
      if (t.type == 'Trailer') return t.key;
    }
    return trailers.isNotEmpty ? trailers.first.key : null;
  }

  static const _trailerTypes = {
    'Trailer',
    'Teaser',
    'Featurette',
    'Clip',
    'Behind the Scenes',
  };

  static const _trailerTypeOrder = {
    'Trailer': 0,
    'Teaser': 1,
    'Featurette': 2,
    'Clip': 3,
    'Behind the Scenes': 4,
  };

  static List<MediaTrailer> parseTrailers(Map<String, dynamic> json) {
    final videos = json['videos'];
    if (videos is! Map<String, dynamic>) return const [];
    final results = videos['results'] as List? ?? [];
    final seen = <String>{};
    final trailers = <MediaTrailer>[];

    for (final v in results) {
      if (v is! Map<String, dynamic>) continue;
      if (v['site'] != 'YouTube') continue;
      final type = (v['type'] ?? '').toString();
      if (!_trailerTypes.contains(type)) continue;
      final key = v['key']?.toString() ?? '';
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      trailers.add(MediaTrailer(
        key: key,
        name: (v['name'] ?? type).toString(),
        type: type,
        official: v['official'] == true,
        site: (v['site'] ?? 'YouTube').toString(),
      ));
    }

    trailers.sort((a, b) {
      if (a.official != b.official) return a.official ? -1 : 1;
      final typeCmp = (_trailerTypeOrder[a.type] ?? 99)
          .compareTo(_trailerTypeOrder[b.type] ?? 99);
      if (typeCmp != 0) return typeCmp;
      return a.name.compareTo(b.name);
    });

    return trailers;
  }

  /// TMDB `tv/{id}` seasons[] → season_number (≥1) → poster_path.
  static Map<int, String> parseSeasonPosters(Map<String, dynamic> json) {
    final seasons = json['seasons'] as List? ?? [];
    final map = <int, String>{};
    for (final raw in seasons) {
      if (raw is! Map<String, dynamic>) continue;
      final seasonNumber = (raw['season_number'] as num?)?.toInt();
      final poster = raw['poster_path']?.toString() ?? '';
      if (seasonNumber != null && seasonNumber > 0 && poster.isNotEmpty) {
        map[seasonNumber] = poster;
      }
    }
    return map;
  }

  static MediaDetailsExtras parseMediaExtras(
    Map<String, dynamic> json, {
    required String mediaType,
  }) {
    final credits = json['credits'] as Map<String, dynamic>?;
    final cast = (credits?['cast'] as List? ?? []).take(20).map<Map<String, String>>((e) {
      return {
        'name': (e['name'] ?? '').toString(),
        'character': (e['character'] ?? '').toString(),
        'profilePath': (e['profile_path'] ?? '').toString(),
      };
    }).toList();

    final crew = (credits?['crew'] as List? ?? [])
        .where((e) {
          final job = (e['job'] ?? '').toString().toLowerCase();
          return job.contains('director') ||
              job.contains('writer') ||
              job.contains('creator');
        })
        .take(8)
        .map<Map<String, String>>((e) => {
              'name': (e['name'] ?? '').toString(),
              'job': (e['job'] ?? '').toString(),
              'profilePath': (e['profile_path'] ?? '').toString(),
            })
        .toList();

    final keywordsRaw = json['keywords'];
    final keywordList = keywordsRaw is Map<String, dynamic>
        ? (keywordsRaw['keywords'] as List? ?? keywordsRaw['results'] as List? ?? [])
        : <dynamic>[];
    final keywords = keywordList
        .map((e) => (e is Map ? e['name'] : null)?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .cast<String>()
        .take(12)
        .toList();

    final companies = (json['production_companies'] as List? ?? [])
        .map((e) => (e['name'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .cast<String>()
        .toList();

    final languages = (json['spoken_languages'] as List? ?? [])
        .map((e) => (e['english_name'] ?? e['name'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .cast<String>()
        .toList();

    final countries = _parseOriginCountries(json, mediaType: mediaType);

    final networks = mediaType == 'tv'
        ? (json['networks'] as List? ?? [])
            .map((e) => (e['name'] ?? '').toString())
            .where((s) => s.isNotEmpty)
            .cast<String>()
            .toList()
        : const <String>[];

    final creators = mediaType == 'tv'
        ? (json['created_by'] as List? ?? [])
            .map((e) => (e['name'] ?? '').toString())
            .where((s) => s.isNotEmpty)
            .cast<String>()
            .toList()
        : const <String>[];

    var certification = '';
    if (mediaType == 'movie') {
      final rd = json['release_dates'] as Map<String, dynamic>?;
      final us = (rd?['results'] as List? ?? []).cast<Map<String, dynamic>?>().firstWhere(
            (r) => r?['iso_3166_1'] == 'US',
            orElse: () => null,
          );
      final dates = us?['release_dates'] as List? ?? [];
      for (final d in dates) {
        final c = d['certification']?.toString() ?? '';
        if (c.isNotEmpty) {
          certification = c;
          break;
        }
      }
    } else {
      final cr = json['content_ratings'] as Map<String, dynamic>?;
      final us = (cr?['results'] as List? ?? []).cast<Map<String, dynamic>?>().firstWhere(
            (r) => r?['iso_3166_1'] == 'US',
            orElse: () => null,
          );
      certification = us?['rating']?.toString() ?? '';
    }

    final recs = json['recommendations'] as Map<String, dynamic>?;
    final recResults = recs?['results'] as List? ?? [];
    final recommendations = recResults
        .take(12)
        .map((e) => Movie.fromJson(e as Map<String, dynamic>, mediaType: mediaType))
        .toList();

    return MediaDetailsExtras(
      tagline: json['tagline']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      voteCount: (json['vote_count'] as num?)?.toInt() ?? 0,
      popularity: (json['popularity'] as num?)?.toDouble() ?? 0,
      cast: cast,
      crew: crew,
      keywords: keywords,
      productionCompanies: companies,
      spokenLanguages: languages,
      originalLanguage: json['original_language']?.toString() ?? '',
      originCountries: countries,
      certification: certification,
      recommendations: recommendations,
      trailerYoutubeKey: parseTrailerYoutubeKey(json),
      budget: (json['budget'] as num?)?.toInt() ?? 0,
      revenue: (json['revenue'] as num?)?.toInt() ?? 0,
      trailers: parseTrailers(json),
      lastAirDate: json['last_air_date']?.toString() ?? '',
      networks: networks,
      creators: creators,
      seasonPosters:
          mediaType == 'tv' ? parseSeasonPosters(json) : const {},
    );
  }

  static List<String> _parseOriginCountries(
    Map<String, dynamic> json, {
    required String mediaType,
  }) {
    if (mediaType == 'movie') {
      return (json['production_countries'] as List? ?? [])
          .map((e) {
            if (e is! Map) return '';
            return (e['name'] ?? '').toString();
          })
          .where((s) => s.isNotEmpty)
          .cast<String>()
          .toList();
    }
    return (json['origin_country'] as List? ?? [])
        .map((e) => countryNameFromCode(e.toString()))
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static String countryNameFromCode(String code) {
    final upper = code.trim().toUpperCase();
    if (upper.isEmpty) return '';
    const names = {
      'AD': 'Andorra',
      'AE': 'United Arab Emirates',
      'AR': 'Argentina',
      'AT': 'Austria',
      'AU': 'Australia',
      'BE': 'Belgium',
      'BG': 'Bulgaria',
      'BR': 'Brazil',
      'CA': 'Canada',
      'CH': 'Switzerland',
      'CL': 'Chile',
      'CN': 'China',
      'CO': 'Colombia',
      'CZ': 'Czech Republic',
      'DE': 'Germany',
      'DK': 'Denmark',
      'ES': 'Spain',
      'FI': 'Finland',
      'FR': 'France',
      'GB': 'United Kingdom',
      'GR': 'Greece',
      'HK': 'Hong Kong',
      'HR': 'Croatia',
      'HU': 'Hungary',
      'ID': 'Indonesia',
      'IE': 'Ireland',
      'IL': 'Israel',
      'IN': 'India',
      'IR': 'Iran',
      'IS': 'Iceland',
      'IT': 'Italy',
      'JP': 'Japan',
      'KR': 'South Korea',
      'LU': 'Luxembourg',
      'MX': 'Mexico',
      'MY': 'Malaysia',
      'NL': 'Netherlands',
      'NO': 'Norway',
      'NZ': 'New Zealand',
      'PH': 'Philippines',
      'PL': 'Poland',
      'PT': 'Portugal',
      'RO': 'Romania',
      'RU': 'Russia',
      'SE': 'Sweden',
      'SG': 'Singapore',
      'TH': 'Thailand',
      'TR': 'Turkey',
      'TW': 'Taiwan',
      'UA': 'Ukraine',
      'US': 'United States',
      'ZA': 'South Africa',
    };
    return names[upper] ?? upper;
  }

  Movie _movieFromRichJson(Map<String, dynamic> json, {required String mediaType}) {
    final images = json['images'];
    final backdrops = (images != null && images['backdrops'] != null)
        ? (images['backdrops'] as List).map((e) => e['file_path'] as String).toList()
        : <String>[];

    var logoPath = '';
    if (images != null && images['logos'] != null) {
      final logos = images['logos'] as List;
      final enLogo = logos.cast<Map<String, dynamic>?>().firstWhere(
            (e) => e?['iso_639_1'] == 'en',
            orElse: () => logos.isNotEmpty ? logos.first as Map<String, dynamic> : null,
          );
      if (enLogo != null) logoPath = enLogo['file_path']?.toString() ?? '';
    }

    final externalIds = json['external_ids'];
    final imdbId = json['imdb_id']?.toString() ??
        (externalIds is Map ? externalIds['imdb_id']?.toString() : null);

    final runtime = mediaType == 'tv'
        ? ((json['episode_run_time'] as List?)?.isNotEmpty == true
            ? json['episode_run_time'][0]
            : 0)
        : (json['runtime'] ?? 0);

    return Movie.fromJson(json, mediaType: mediaType).copyWith(
      imdbId: imdbId,
      overview: json['overview']?.toString() ?? '',
      genres: (json['genres'] as List?)?.map((e) => e['name'] as String).toList() ?? [],
      runtime: runtime is int ? runtime : (runtime as num).toInt(),
      screenshots: backdrops,
      logoPath: logoPath,
      numberOfSeasons: json['number_of_seasons'] ?? 0,
      numberOfEpisodes: json['number_of_episodes'] ?? 0,
    );
  }

  Future<RichMediaDetails> getRichMovieDetails(int movieId) async {
    final json = await _fetchMap('movie/$movieId?append_to_response=$_richAppendMovie');
    return RichMediaDetails(
      movie: _movieFromRichJson(json, mediaType: 'movie'),
      extras: parseMediaExtras(json, mediaType: 'movie'),
      watchProviders: parseWatchProviders(json),
    );
  }

  Future<RichMediaDetails> getRichTvDetails(int tvId) async {
    final json = await _fetchMap('tv/$tvId?append_to_response=$_richAppendTv');
    return RichMediaDetails(
      movie: _movieFromRichJson(json, mediaType: 'tv'),
      extras: parseMediaExtras(json, mediaType: 'tv'),
      watchProviders: parseWatchProviders(json),
    );
  }

  Future<RichMediaDetails> getRichDetails(int id, String mediaType) {
    return mediaType == 'tv' ? getRichTvDetails(id) : getRichMovieDetails(id);
  }
}
