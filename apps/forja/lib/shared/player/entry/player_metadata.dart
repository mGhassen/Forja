import 'package:rust/rust.dart';

class PlayerHeroMetadata {
  const PlayerHeroMetadata({
    required this.movie,
    this.episodeOverview,
  });

  final Movie movie;
  final String? episodeOverview;
}

bool playerNeedsRichMetadata(Movie movie) {
  return movie.logoPath.isEmpty ||
      movie.overview.isEmpty ||
      movie.genres.isEmpty;
}

String? tmdbLogoImageUrlFromPath(String rawPath) {
  final path = rawPath.trim();
  if (path.isEmpty || path.toLowerCase().endsWith('.svg')) return null;
  if (path.startsWith('http')) return path;
  return TmdbApi.getImageUrl(path);
}

/// TMDB title logo for hero / loading chrome when [Movie.logoPath] is empty.
Future<String?> resolveTmdbLogoImageUrl(Movie movie) async {
  final fromMovie = tmdbLogoImageUrlFromPath(movie.logoPath);
  if (fromMovie != null) return fromMovie;
  if (movie.id <= 0) return null;
  try {
    final logoPath =
        await TmdbApi().getLogoPath(movie.id, mediaType: movie.mediaType);
    if (logoPath.isEmpty) return null;
    return TmdbApi.getImageUrl(logoPath);
  } catch (_) {
    return null;
  }
}

Future<PlayerHeroMetadata?> loadPlayerHeroMetadata({
  required Movie movie,
  int? season,
  int? episode,
}) async {
  if (movie.id <= 0) return null;

  var enriched = movie;
  if (playerNeedsRichMetadata(movie)) {
    try {
      final rich = await TmdbApi().getRichDetails(movie.id, movie.mediaType);
      enriched = rich.movie.copyWith(
        imdbId: (rich.movie.imdbId?.isNotEmpty == true)
            ? rich.movie.imdbId
            : movie.imdbId,
        posterPath: rich.movie.posterPath.isNotEmpty
            ? rich.movie.posterPath
            : movie.posterPath,
        backdropPath: rich.movie.backdropPath.isNotEmpty
            ? rich.movie.backdropPath
            : movie.backdropPath,
        logoPath: rich.movie.logoPath.isNotEmpty
            ? rich.movie.logoPath
            : movie.logoPath,
      );
    } catch (_) {}
  }

  String? episodeOverview;
  if (movie.mediaType == 'tv' && season != null && episode != null) {
    try {
      final data = await TmdbApi().getTvSeasonDetails(enriched.id, season);
      final episodes = data['episodes'] as List?;
      if (episodes != null) {
        for (final ep in episodes) {
          if (ep is! Map) continue;
          if (ep['episode_number'] == episode) {
            final overview = ep['overview']?.toString().trim() ?? '';
            if (overview.isNotEmpty) episodeOverview = overview;
            break;
          }
        }
      }
    } catch (_) {}
  }

  return PlayerHeroMetadata(
    movie: enriched,
    episodeOverview: episodeOverview,
  );
}
