import 'dart:convert';

import 'package:rust/rust.dart';
import '../models/media_details_extras.dart';
import '../models/watch_provider.dart';

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

  Future<List<Movie>> getTrending() async {
    final decoded = await _fetchMap('trending/movie/day');
    return (decoded['results'] as List).map((json) => Movie.fromJson(json, mediaType: 'movie')).toList();
  }

  Future<List<Movie>> getTrendingTv() async {
    final decoded = await _fetchMap('trending/tv/day');
    return (decoded['results'] as List).map((json) => Movie.fromJson(json, mediaType: 'tv')).toList();
  }

  /// Website-style popular: discover sorted by popularity with a minimum vote
  /// floor so low-signal titles from raw `/popular` do not dominate the row.
  Future<List<Movie>> getPopular({String? watchRegion}) {
    return discoverMovies(
      watchRegion: watchRegion ?? TmdbWatchRegion.current,
      sortBy: 'popularity.desc',
      minVoteCount: 100,
    );
  }

  Future<List<Movie>> getPopularTv({String? watchRegion}) {
    return discoverTvShows(
      watchRegion: watchRegion ?? TmdbWatchRegion.current,
      sortBy: 'popularity.desc',
      minVoteCount: 100,
    );
  }

  Future<List<Movie>> getTopRated() async {
    final decoded = await _fetchMap('movie/top_rated');
    return (decoded['results'] as List).map((json) => Movie.fromJson(json, mediaType: 'movie')).toList();
  }

  Future<List<Movie>> getNowPlaying() async {
    final decoded = await _fetchMap('movie/now_playing');
    return (decoded['results'] as List).map((json) => Movie.fromJson(json, mediaType: 'movie')).toList();
  }

  Future<List<Movie>> getOnTheAir() async {
    final decoded = await _fetchMap('tv/on_the_air');
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

  Future<List<Movie>> searchMulti(String query) async {
    final decoded = await _fetchMap('search/multi?query=${Uri.encodeComponent(query)}');
    return (decoded['results'] as List)
        .where((json) => json['media_type'] == 'movie' || json['media_type'] == 'tv')
        .map((json) => Movie.fromJson(json))
        .toList();
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
    WatchProvider(id: 8, name: 'Netflix', logoPath: '/t2yyOv40HZolWobUddeOKCzK00l.png'),
    WatchProvider(id: 337, name: 'Disney Plus', logoPath: '/7rDHAkCx4R4x9uYkl25W2YiOinRd9EwK.png'),
    WatchProvider(id: 9, name: 'Prime Video', logoPath: '/emthp39XA2YScoYLtFEer2eNJ0U.png'),
    WatchProvider(id: 350, name: 'Apple TV+', logoPath: '/6LfztECW4G3jXb16TzXBIy9XW19.png'),
    WatchProvider(id: 1899, name: 'Max', logoPath: '/pbbY8oE2AxGcH2ww1iflHQ4bTzM.png'),
    WatchProvider(id: 15, name: 'Hulu', logoPath: '/bnoevw11yf2tcsc7dol6y688nkm.png'),
    WatchProvider(id: 531, name: 'Paramount+', logoPath: '/6uhHDRkj59HQD3TCfDm2N1Kc5P.png'),
    WatchProvider(id: 386, name: 'Peacock', logoPath: '/8UGimH0nX3WHQfB6eTJkksbef2.png'),
    WatchProvider(id: 283, name: 'Crunchyroll', logoPath: '/8n0UUKuxl2AdGYrpQxdSA3KWW69.png'),
    WatchProvider(id: 73, name: 'Tubi', logoPath: '/7w3aFA8jP8fRWGj8n007iPorQGn.png'),
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
    int? minVoteCount,
    String? language,
    int? watchProviderId,
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
    if (minVoteCount != null) {
      path += '&vote_count.gte=$minVoteCount';
    }
    if (language != null) {
      path += '&with_original_language=$language';
    }
    if (watchProviderId != null) {
      path += '&with_watch_providers=$watchProviderId';
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
    int? minVoteCount,
    String? language,
    int? watchProviderId,
    String? watchRegion,
    String sortBy = 'popularity.desc',
    int page = 1,
  }) async {
    final region = watchRegion ?? TmdbWatchRegion.current;
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
    if (minVoteCount != null) {
      path += '&vote_count.gte=$minVoteCount';
    }
    if (language != null) {
      path += '&with_original_language=$language';
    }
    if (watchProviderId != null) {
      path += '&with_watch_providers=$watchProviderId';
    }

    final decoded = await _fetchMap(path);
    return (decoded['results'] as List).map((json) => Movie.fromJson(json, mediaType: 'tv')).toList();
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
