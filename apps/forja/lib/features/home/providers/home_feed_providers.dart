import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/app/boot_cache.dart';
import 'package:forja/features/home/home_genre_categories.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:rust/rust.dart';

/// Bumps on pull-to-refresh / shell tab refresh to refetch Home TMDB rails.
final homeFeedRefreshProvider = StateProvider<int>((ref) => 0);

final tmdbApiProvider = Provider((ref) => TmdbApi());

final shellWatchProviderIdProvider =
    NotifierProvider<ShellWatchProviderIdNotifier, int?>(
  ShellWatchProviderIdNotifier.new,
);

class ShellWatchProviderIdNotifier extends Notifier<int?> {
  @override
  int? build() {
    final n = ShellBus.selectedWatchProviderId;
    void listener() => state = n.value;
    n.addListener(listener);
    ref.onDispose(() => n.removeListener(listener));
    return n.value;
  }
}

final shellHomeCategoryProvider =
    NotifierProvider<ShellHomeCategoryNotifier, ShellHomeCategory?>(
  ShellHomeCategoryNotifier.new,
);

class ShellHomeCategoryNotifier extends Notifier<ShellHomeCategory?> {
  @override
  ShellHomeCategory? build() {
    final n = ShellBus.homeCategory;
    void listener() => state = n.value;
    n.addListener(listener);
    ref.onDispose(() => n.removeListener(listener));
    return n.value;
  }
}

final shellHomeGenreIdProvider =
    NotifierProvider<ShellHomeGenreIdNotifier, String?>(
  ShellHomeGenreIdNotifier.new,
);

class ShellHomeGenreIdNotifier extends Notifier<String?> {
  @override
  String? build() {
    final n = ShellBus.homeSelectedGenreId;
    void listener() => state = n.value;
    n.addListener(listener);
    ref.onDispose(() => n.removeListener(listener));
    return n.value;
  }
}

void refreshHomeFeed(WidgetRef ref) {
  ref.read(homeFeedRefreshProvider.notifier).state++;
  ref.invalidate(homeTrendingProvider);
  ref.invalidate(homePopularProvider);
  ref.invalidate(homeFeaturedProvider);
  ref.invalidate(homeNowPlayingProvider);
}

({List<int>? movie, List<int>? tv}) _genreIds(String? genreId) {
  final genre = lookupHomeGenre(genreId);
  if (genre == null) return (movie: null, tv: null);
  return (movie: genre.movieGenres, tv: genre.tvGenres);
}

List<Movie> _enforceMediaFilter(List<Movie> items, ShellHomeCategory? filter) {
  if (filter == ShellHomeCategory.films) {
    return items.where((movie) => movie.mediaType != 'tv').toList();
  }
  if (filter == ShellHomeCategory.tvShows) {
    return items.where((movie) => movie.mediaType == 'tv').toList();
  }
  return items;
}

List<Movie> _uniqueMedia(List<Movie> primary, List<Movie> extra) {
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

List<Movie> _interleaveMedia(List<Movie> movies, List<Movie> tv) {
  final out = <Movie>[];
  final seen = <String>{};
  void add(Movie m) {
    final key = '${m.mediaType}:${m.id}';
    if (seen.add(key)) out.add(m);
  }
  final maxLen = math.max(movies.length, tv.length);
  for (var i = 0; i < maxLen; i++) {
    if (i < movies.length) add(movies[i]);
    if (i < tv.length) add(tv[i]);
  }
  return out;
}

Future<List<Movie>> _fetchMovies({
  required TmdbApi api,
  required Future<List<Movie>> Function() standard,
  List<int>? genres,
  int? watchProviderId,
  String sortBy = 'popularity.desc',
  double? minRating,
  String? releaseDateGte,
  String? releaseDateLte,
}) {
  if (genres == null || genres.isEmpty) return standard();
  return api.discoverMovies(
    genres: genres,
    watchProviderId: watchProviderId,
    sortBy: sortBy,
    minRating: minRating,
    releaseDateGte: releaseDateGte,
    releaseDateLte: releaseDateLte,
  );
}

Future<List<Movie>> _fetchTv({
  required TmdbApi api,
  required Future<List<Movie>> Function() standard,
  List<int>? genres,
  int? watchProviderId,
  String sortBy = 'popularity.desc',
  double? minRating,
  String? releaseDateGte,
  String? releaseDateLte,
}) {
  if (genres == null || genres.isEmpty) return standard();
  return api.discoverTvShows(
    genres: genres,
    watchProviderId: watchProviderId,
    sortBy: sortBy,
    minRating: minRating,
    releaseDateGte: releaseDateGte,
    releaseDateLte: releaseDateLte,
  );
}

Future<List<Movie>> _fetchMixed(
  Future<List<Movie>> Function() movieFetch,
  Future<List<Movie>> Function() tvFetch, {
  List<Movie>? movieCache,
}) {
  Future<List<Movie>> safeTv() => tvFetch().catchError((_) => <Movie>[]);

  if (movieCache != null) {
    return safeTv().then((tv) => _interleaveMedia(movieCache, tv));
  }
  final safeMovie = movieFetch().catchError((_) => <Movie>[]);
  return Future.wait([safeMovie, safeTv()])
      .then((results) => _interleaveMedia(results[0], results[1]));
}

Future<List<Movie>> _fetchMediaFiltered({
  required ShellHomeCategory? filter,
  required Future<List<Movie>> Function() movieFetch,
  required Future<List<Movie>> Function() tvFetch,
  List<Movie>? movieCache,
}) {
  if (filter == ShellHomeCategory.films) {
    if (movieCache != null) {
      return Future.value(_enforceMediaFilter(movieCache, filter));
    }
    return movieFetch()
        .then((movies) => _enforceMediaFilter(movies, filter))
        .catchError((_) => <Movie>[]);
  }
  if (filter == ShellHomeCategory.tvShows) {
    return tvFetch()
        .then((movies) => _enforceMediaFilter(movies, filter))
        .catchError((_) => <Movie>[]);
  }
  return _fetchMixed(movieFetch, tvFetch, movieCache: movieCache);
}

({String gte, String lte}) _currentMonthDateRange() {
  final now = DateTime.now();
  final lastDay = DateTime(now.year, now.month + 1, 0);
  String pad(int n) => n.toString().padLeft(2, '0');
  return (
    gte: '${now.year}-${pad(now.month)}-01',
    lte: '${lastDay.year}-${pad(lastDay.month)}-${pad(lastDay.day)}',
  );
}

HomeFeedContext _watchHomeFeedContext(Ref ref) {
  ref.watch(homeFeedRefreshProvider);
  final providerId = ref.watch(shellWatchProviderIdProvider);
  final filter = ref.watch(shellHomeCategoryProvider);
  final genreId = ref.watch(shellHomeGenreIdProvider);
  final epoch = ref.read(homeFeedRefreshProvider);
  final genres = _genreIds(genreId);
  final canUseBootCache = epoch == 0 &&
      providerId == null &&
      genreId == null &&
      filter == null;
  return HomeFeedContext(
    api: ref.read(tmdbApiProvider),
    providerId: providerId,
    filter: filter,
    genres: genres,
    canUseBootCache: canUseBootCache,
  );
}

class HomeFeedContext {
  const HomeFeedContext({
    required this.api,
    required this.providerId,
    required this.filter,
    required this.genres,
    required this.canUseBootCache,
  });

  final TmdbApi api;
  final int? providerId;
  final ShellHomeCategory? filter;
  final ({List<int>? movie, List<int>? tv}) genres;
  final bool canUseBootCache;
}

final homeTrendingProvider =
    FutureProvider.autoDispose<List<Movie>>((ref) async {
  final ctx = _watchHomeFeedContext(ref);
  if (ctx.providerId != null) {
    return _fetchMediaFiltered(
      filter: ctx.filter,
      movieFetch: () => _fetchMovies(
        api: ctx.api,
        standard: () => ctx.api.discoverMovies(watchProviderId: ctx.providerId),
        genres: ctx.genres.movie,
        watchProviderId: ctx.providerId,
      ),
      tvFetch: () => _fetchTv(
        api: ctx.api,
        standard: () => ctx.api.discoverTvShows(watchProviderId: ctx.providerId),
        genres: ctx.genres.tv,
        watchProviderId: ctx.providerId,
      ),
    );
  }
  return _fetchMediaFiltered(
    filter: ctx.filter,
    movieFetch: () => _fetchMovies(
      api: ctx.api,
      standard: ctx.api.getTrending,
      genres: ctx.genres.movie,
    ),
    tvFetch: () => _fetchTv(
      api: ctx.api,
      standard: ctx.api.getTrendingTv,
      genres: ctx.genres.tv,
    ),
    movieCache: ctx.canUseBootCache ? BootCache.trending : null,
  );
});

final homePopularProvider =
    FutureProvider.autoDispose<List<Movie>>((ref) async {
  final ctx = _watchHomeFeedContext(ref);
  if (ctx.providerId != null) {
    return _fetchMediaFiltered(
      filter: ctx.filter,
      movieFetch: () => _fetchMovies(
        api: ctx.api,
        standard: () => ctx.api.discoverMovies(
          watchProviderId: ctx.providerId,
          sortBy: 'vote_average.desc',
          minRating: 0,
        ),
        genres: ctx.genres.movie,
        watchProviderId: ctx.providerId,
        sortBy: 'vote_average.desc',
        minRating: 0,
      ),
      tvFetch: () => _fetchTv(
        api: ctx.api,
        standard: () => ctx.api.discoverTvShows(
          watchProviderId: ctx.providerId,
          sortBy: 'vote_average.desc',
          minRating: 0,
        ),
        genres: ctx.genres.tv,
        watchProviderId: ctx.providerId,
        sortBy: 'vote_average.desc',
        minRating: 0,
      ),
    );
  }
  return _fetchMediaFiltered(
    filter: ctx.filter,
    movieFetch: () => _fetchMovies(
      api: ctx.api,
      standard: ctx.api.getPopular,
      genres: ctx.genres.movie,
      sortBy: 'vote_average.desc',
    ),
    tvFetch: () => _fetchTv(
      api: ctx.api,
      standard: ctx.api.getPopularTv,
      genres: ctx.genres.tv,
      sortBy: 'vote_average.desc',
    ),
    movieCache: ctx.canUseBootCache ? BootCache.popular : null,
  );
});

final homeNowPlayingProvider =
    FutureProvider.autoDispose<List<Movie>>((ref) async {
  final ctx = _watchHomeFeedContext(ref);
  if (ctx.providerId != null) {
    return _fetchMediaFiltered(
      filter: ctx.filter,
      movieFetch: () => _fetchMovies(
        api: ctx.api,
        standard: () => ctx.api.discoverMovies(
          watchProviderId: ctx.providerId,
          sortBy: 'primary_release_date.desc',
        ),
        genres: ctx.genres.movie,
        watchProviderId: ctx.providerId,
        sortBy: 'primary_release_date.desc',
      ),
      tvFetch: () => _fetchTv(
        api: ctx.api,
        standard: () => ctx.api.discoverTvShows(
          watchProviderId: ctx.providerId,
          sortBy: 'first_air_date.desc',
        ),
        genres: ctx.genres.tv,
        watchProviderId: ctx.providerId,
        sortBy: 'first_air_date.desc',
      ),
    );
  }
  return _fetchMediaFiltered(
    filter: ctx.filter,
    movieFetch: () => _fetchMovies(
      api: ctx.api,
      standard: ctx.api.getNowPlaying,
      genres: ctx.genres.movie,
      sortBy: 'primary_release_date.desc',
    ),
    tvFetch: () => _fetchTv(
      api: ctx.api,
      standard: ctx.api.getOnTheAir,
      genres: ctx.genres.tv,
      sortBy: 'first_air_date.desc',
    ),
    movieCache: ctx.canUseBootCache ? BootCache.nowPlaying : null,
  );
});

final homeFeaturedProvider =
    FutureProvider.autoDispose<List<Movie>>((ref) async {
  final ctx = _watchHomeFeedContext(ref);
  final range = _currentMonthDateRange();

  Future<List<Movie>> load({
    String? releaseDateGte,
    String? releaseDateLte,
    double? minRating,
  }) {
    return _fetchMediaFiltered(
      filter: ctx.filter,
      movieFetch: () => _fetchMovies(
        api: ctx.api,
        standard: () => ctx.api.discoverMovies(
          releaseDateGte: releaseDateGte,
          releaseDateLte: releaseDateLte,
          minRating: minRating,
          watchProviderId: ctx.providerId,
          sortBy: 'popularity.desc',
        ),
        genres: ctx.genres.movie,
        releaseDateGte: releaseDateGte,
        releaseDateLte: releaseDateLte,
        minRating: minRating,
        watchProviderId: ctx.providerId,
        sortBy: 'popularity.desc',
      ),
      tvFetch: () => _fetchTv(
        api: ctx.api,
        standard: () => ctx.api.discoverTvShows(
          releaseDateGte: releaseDateGte,
          releaseDateLte: releaseDateLte,
          minRating: minRating,
          watchProviderId: ctx.providerId,
          sortBy: 'popularity.desc',
        ),
        genres: ctx.genres.tv,
        releaseDateGte: releaseDateGte,
        releaseDateLte: releaseDateLte,
        minRating: minRating,
        watchProviderId: ctx.providerId,
        sortBy: 'popularity.desc',
      ),
    );
  }

  final month = await load(
    releaseDateGte: range.gte,
    releaseDateLte: range.lte,
    minRating: ctx.providerId != null ? null : 6.0,
  );
  if (ctx.providerId == null) return month;
  // Calendar-month + service is often a handful of titles. Keep new-this-month
  // first, then fill from popular on that service.
  if (month.length >= 8) return month;
  final popular = await load();
  return _uniqueMedia(month, popular);
});
