import 'dart:convert';

import 'package:rust/rust.dart';

class TmdbService {
  Future<Map<String, dynamic>> _fetchMap(String resourcePath) async {
    final raw = RustLib.instance.tmdbGetJson(resourcePath);
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic> && decoded['error'] != null) {
      throw Exception(decoded['error']);
    }
    return decoded as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getMovieDetails(String tmdbId) async {
    return _fetchMap('movie/$tmdbId');
  }

  Future<Map<String, dynamic>> getTvShowDetails(String tmdbId) async {
    return _fetchMap('tv/$tmdbId');
  }

  String getMovieTitle(Map<String, dynamic> movieData) {
    return movieData['title'] ?? '';
  }

  String getTvShowTitle(Map<String, dynamic> tvData) {
    return tvData['name'] ?? '';
  }

  String getReleaseYear(Map<String, dynamic> data) {
    final releaseDate = data['release_date'] ?? data['first_air_date'] ?? '';
    if (releaseDate.isNotEmpty) {
      return releaseDate.split('-')[0];
    }
    return '';
  }

  /// Fetches season details including all episodes for a given TV show season.
  /// Returns the TMDB season object with an 'episodes' list.
  Future<Map<String, dynamic>> getTvSeasonDetails(int tvId, int seasonNumber) async {
    return _fetchMap('tv/$tvId/season/$seasonNumber');
  }

  /// Returns the total number of seasons for a TV show.
  Future<int> getTvSeasonCount(int tvId) async {
    final data = await getTvShowDetails(tvId.toString());
    return (data['number_of_seasons'] as int?) ?? 0;
  }
}
