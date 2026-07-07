import 'package:api/models/movie.dart';

/// TMDB lists fetched once during splash; consumed by [HomeScreen].
class BootCache {
  BootCache._();

  static List<Movie>? trending;
  static List<Movie>? popular;
  static List<Movie>? topRated;
  static List<Movie>? nowPlaying;

  static void setTmdb({
    required List<Movie> trendingList,
    required List<Movie> popularList,
    required List<Movie> topRatedList,
    required List<Movie> nowPlayingList,
  }) {
    trending = trendingList;
    popular = popularList;
    topRated = topRatedList;
    nowPlaying = nowPlayingList;
  }

  static void clear() {
    trending = null;
    popular = null;
    topRated = null;
    nowPlaying = null;
  }
}
