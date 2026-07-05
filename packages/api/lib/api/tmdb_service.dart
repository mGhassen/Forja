import 'dart:convert';
import 'package:http/http.dart' as http;

class TmdbService {
  static const String apiKey = 'c3515fdc674ea2bd7b514f4bc3616a4a';
  static const String baseUrl = 'https://api.themoviedb.org/3';

  Future<Map<String, dynamic>> getMovieDetails(String tmdbId) async {
    final url = '$baseUrl/movie/$tmdbId?api_key=$apiKey';
    
    final response = await http.get(Uri.parse(url));
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch movie details: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> getTvShowDetails(String tmdbId) async {
    final url = '$baseUrl/tv/$tmdbId?api_key=$apiKey';
    
    final response = await http.get(Uri.parse(url));
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch TV show details: ${response.statusCode}');
    }
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
    final url = '$baseUrl/tv/$tvId/season/$seasonNumber?api_key=$apiKey';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch season details: ${response.statusCode}');
    }
  }

  /// Returns the total number of seasons for a TV show.
  Future<int> getTvSeasonCount(int tvId) async {
    final data = await getTvShowDetails(tvId.toString());
    return (data['number_of_seasons'] as int?) ?? 0;
  }
}
