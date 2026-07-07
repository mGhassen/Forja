import 'dart:convert';

import 'package:rust/rust.dart';

class TmdbApi {
  static const String _imageBaseUrl = 'https://image.tmdb.org/t/p/w500';

  static Future<dynamic> _fetch(String resourcePath, {int timeoutSecs = 15}) async {
    final raw = RustLib.instance.tmdbGetJson(resourcePath, timeoutSecs: timeoutSecs);
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

  Future<List<Movie>> getPopular() async {
    final decoded = await _fetchMap('movie/popular');
    return (decoded['results'] as List).map((json) => Movie.fromJson(json, mediaType: 'movie')).toList();
  }

  Future<List<Movie>> getTopRated() async {
    final decoded = await _fetchMap('movie/top_rated');
    return (decoded['results'] as List).map((json) => Movie.fromJson(json, mediaType: 'movie')).toList();
  }

  Future<List<Movie>> getNowPlaying() async {
    final decoded = await _fetchMap('movie/now_playing');
    return (decoded['results'] as List).map((json) => Movie.fromJson(json, mediaType: 'movie')).toList();
  }

  Future<List<String>> getBackdrops(int movieId) async {
    try {
      final decoded = await _fetchMap('movie/$movieId/images');
      final backdrops = decoded['backdrops'] as List;
      return backdrops.take(5).map((e) => e['file_path'] as String).toList();
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

  Future<List<Movie>> discoverMovies({List<int>? genres, int? year, double? minRating, String? language, int page = 1}) async {
    var path = 'discover/movie?page=$page';
    if (genres != null && genres.isNotEmpty) {
      path += '&with_genres=${genres.join(',')}';
    }
    if (year != null) {
      path += '&primary_release_year=$year';
    }
    if (minRating != null) {
      path += '&vote_average.gte=$minRating';
    }
    if (language != null) {
      path += '&with_original_language=$language';
    }

    final decoded = await _fetchMap(path);
    return (decoded['results'] as List).map((json) => Movie.fromJson(json, mediaType: 'movie')).toList();
  }

  Future<List<Movie>> discoverTvShows({List<int>? genres, int? year, double? minRating, String? language, int page = 1}) async {
    var path = 'discover/tv?page=$page';
    if (genres != null && genres.isNotEmpty) {
      path += '&with_genres=${genres.join(',')}';
    }
    if (year != null) {
      path += '&first_air_date_year=$year';
    }
    if (minRating != null) {
      path += '&vote_average.gte=$minRating';
    }
    if (language != null) {
      path += '&with_original_language=$language';
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
}
