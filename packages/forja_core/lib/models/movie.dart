class Movie {
  final int id;
  final String? imdbId;
  final String title;
  final String posterPath;
  final String backdropPath;
  final String logoPath;
  final double voteAverage;
  final String releaseDate;
  final String overview;
  final List<String> genres;
  final int runtime;
  final List<String> screenshots;
  final String mediaType; // 'movie' or 'tv'
  final int numberOfSeasons;

  Movie({
    required this.id,
    this.imdbId,
    required this.title,
    required this.posterPath,
    required this.backdropPath,
    this.logoPath = '',
    required this.voteAverage,
    required this.releaseDate,
    this.overview = '',
    this.genres = const [],
    this.runtime = 0,
    this.screenshots = const [],
    this.mediaType = 'movie',
    this.numberOfSeasons = 0,
  });

  factory Movie.fromJson(Map<String, dynamic> json, {String? mediaType}) {
    // TMDB uses imdb_id for movies, but for TV it might be in external_ids
    String? imdbId = json['imdb_id'];
    if (imdbId == null && json['external_ids'] != null) {
      imdbId = json['external_ids']['imdb_id'];
    }

    return Movie(
      id: json['id'] ?? 0,
      imdbId: imdbId,
      title: json['title'] ?? json['name'] ?? 'Unknown',
      posterPath: json['poster_path'] ?? '',
      backdropPath: json['backdrop_path'] ?? '',
      logoPath: '', 
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
      releaseDate: json['release_date'] ?? json['first_air_date'] ?? '',
      overview: json['overview'] ?? '',
      genres: (json['genres'] as List?)?.map((e) => e['name'] as String).toList() ?? [],
      runtime: json['runtime'] ?? 0,
      screenshots: [],
      mediaType: mediaType ?? json['media_type'] ?? (json['title'] != null ? 'movie' : 'tv'),
      numberOfSeasons: json['number_of_seasons'] ?? 0,
    );
  }

  Movie copyWith({
    int? id,
    String? imdbId,
    String? title,
    String? posterPath,
    String? backdropPath,
    String? logoPath,
    double? voteAverage,
    String? releaseDate,
    String? overview,
    List<String>? genres,
    int? runtime,
    List<String>? screenshots,
    String? mediaType,
    int? numberOfSeasons,
  }) {
    return Movie(
      id: id ?? this.id,
      imdbId: imdbId ?? this.imdbId,
      title: title ?? this.title,
      posterPath: posterPath ?? this.posterPath,
      backdropPath: backdropPath ?? this.backdropPath,
      logoPath: logoPath ?? this.logoPath,
      voteAverage: voteAverage ?? this.voteAverage,
      releaseDate: releaseDate ?? this.releaseDate,
      overview: overview ?? this.overview,
      genres: genres ?? this.genres,
      runtime: runtime ?? this.runtime,
      screenshots: screenshots ?? this.screenshots,
      mediaType: mediaType ?? this.mediaType,
      numberOfSeasons: numberOfSeasons ?? this.numberOfSeasons,
    );
  }
}
