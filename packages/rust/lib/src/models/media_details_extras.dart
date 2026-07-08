import 'movie.dart';

/// TMDB fields beyond [Movie] for details screens.
class MediaDetailsExtras {
  const MediaDetailsExtras({
    this.tagline = '',
    this.status = '',
    this.voteCount = 0,
    this.popularity = 0,
    this.cast = const [],
    this.crew = const [],
    this.keywords = const [],
    this.productionCompanies = const [],
    this.spokenLanguages = const [],
    this.originCountries = const [],
    this.certification = '',
    this.recommendations = const [],
    this.trailerYoutubeKey,
  });

  final String tagline;
  final String status;
  final int voteCount;
  final double popularity;
  final List<Map<String, String>> cast;
  final List<Map<String, String>> crew;
  final List<String> keywords;
  final List<String> productionCompanies;
  final List<String> spokenLanguages;
  final List<String> originCountries;
  final String certification;
  final List<Movie> recommendations;
  final String? trailerYoutubeKey;
}

class RichMediaDetails {
  const RichMediaDetails({required this.movie, required this.extras});

  final Movie movie;
  final MediaDetailsExtras extras;
}
