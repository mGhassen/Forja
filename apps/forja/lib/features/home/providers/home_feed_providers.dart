import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/app/boot_cache.dart';
import 'package:forja/features/home/home_catalog_rotate.dart';
import 'package:forja/features/home/home_genre_categories.dart';
import 'package:forja/features/home/home_rail_dedupe.dart';
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
    return items.where((movie) => movie.mediaType == 'movie').toList();
  }
  if (filter == ShellHomeCategory.tvShows) {
    return items
        .where((movie) =>
            movie.mediaType == 'tv' || movie.mediaType == 'series')
        .toList();
  }
  return items;
}

List<Movie> _uniqueMedia(List<Movie> primary, List<Movie> extra) {
  return mergeHomeRailPages([primary, extra]);
}

List<Movie> _interleaveMedia(List<Movie> movies, List<Movie> tv) {
  final out = <Movie>[];
  final seen = <String>{};
  void add(Movie m) {
    if (seen.add(homeMediaKey(m))) out.add(m);
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
  required Future<List<Movie>> Function(int page) standard,
  List<int>? genres,
  int? watchProviderId,
  String sortBy = 'popularity.desc',
  double? minRating,
  String? releaseDateGte,
  String? releaseDateLte,
  int page = 1,
}) {
  if (genres == null || genres.isEmpty) return standard(page);
  return api.discoverMovies(
    genres: genres,
    watchProviderId: watchProviderId,
    sortBy: sortBy,
    minRating: minRating,
    releaseDateGte: releaseDateGte,
    releaseDateLte: releaseDateLte,
    page: page,
  );
}

Future<List<Movie>> _fetchTv({
  required TmdbApi api,
  required Future<List<Movie>> Function(int page) standard,
  List<int>? genres,
  int? watchProviderId,
  String sortBy = 'popularity.desc',
  double? minRating,
  String? releaseDateGte,
  String? releaseDateLte,
  int page = 1,
}) {
  if (genres == null || genres.isEmpty) return standard(page);
  return api.discoverTvShows(
    genres: genres,
    watchProviderId: watchProviderId,
    sortBy: sortBy,
    minRating: minRating,
    releaseDateGte: releaseDateGte,
    releaseDateLte: releaseDateLte,
    page: page,
  );
}

Future<List<Movie>> _fetchMoviesPool({
  required TmdbApi api,
  required Future<List<Movie>> Function(int page) standard,
  required int bucket,
  required String salt,
  List<int>? genres,
  int? watchProviderId,
  String sortBy = 'popularity.desc',
  double? minRating,
  String? releaseDateGte,
  String? releaseDateLte,
  List<Movie>? page1Cache,
  bool preserveRankOrder = false,
}) {
  return rotateHomeRailPool(
    bucket: bucket,
    salt: salt,
    page1Cache: page1Cache,
    preserveRankOrder: preserveRankOrder,
    fetchPage: (p) => _fetchMovies(
      api: api,
      standard: standard,
      genres: genres,
      watchProviderId: watchProviderId,
      sortBy: sortBy,
      minRating: minRating,
      releaseDateGte: releaseDateGte,
      releaseDateLte: releaseDateLte,
      page: p,
    ),
  );
}

Future<List<Movie>> _fetchTvPool({
  required TmdbApi api,
  required Future<List<Movie>> Function(int page) standard,
  required int bucket,
  required String salt,
  List<int>? genres,
  int? watchProviderId,
  String sortBy = 'popularity.desc',
  double? minRating,
  String? releaseDateGte,
  String? releaseDateLte,
  bool preserveRankOrder = false,
}) {
  return rotateHomeRailPool(
    bucket: bucket,
    salt: salt,
    preserveRankOrder: preserveRankOrder,
    fetchPage: (p) => _fetchTv(
      api: api,
      standard: standard,
      genres: genres,
      watchProviderId: watchProviderId,
      sortBy: sortBy,
      minRating: minRating,
      releaseDateGte: releaseDateGte,
      releaseDateLte: releaseDateLte,
      page: p,
    ),
  );
}

Future<List<Movie>> _fetchMixed(
  Future<List<Movie>> Function() movieFetch,
  Future<List<Movie>> Function() tvFetch,
) {
  final safeMovie = movieFetch().catchError((_) => <Movie>[]);
  final safeTv = tvFetch().catchError((_) => <Movie>[]);
  return Future.wait([safeMovie, safeTv])
      .then((results) => _interleaveMedia(results[0], results[1]));
}

Future<List<Movie>> _fetchMediaFiltered({
  required ShellHomeCategory? filter,
  required Future<List<Movie>> Function() movieFetch,
  required Future<List<Movie>> Function() tvFetch,
}) {
  if (filter == ShellHomeCategory.films) {
    return movieFetch()
        .then((movies) => _enforceMediaFilter(movies, filter))
        .catchError((_) => <Movie>[]);
  }
  if (filter == ShellHomeCategory.tvShows) {
    return tvFetch()
        .then((movies) => _enforceMediaFilter(movies, filter))
        .catchError((_) => <Movie>[]);
  }
  return _fetchMixed(movieFetch, tvFetch);
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
  // Watch notifier for rebuilds; read ShellBus as source of truth so a lagged
  // notifier frame cannot fetch the unfiltered mix after Films/TV is tapped.
  ref.watch(shellHomeCategoryProvider);
  ref.watch(shellHomeGenreIdProvider);
  final filter = ShellBus.homeCategory.value;
  final genreId = ShellBus.homeSelectedGenreId.value;
  final epoch = ref.read(homeFeedRefreshProvider);
  final bucket = homeCatalogHourBucket();
  ref.watch(homeCatalogHourBucketProvider);
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
    bucket: bucket,
  );
}

/// Ticks when the local hour changes so Home rails rotate their mix.
final homeCatalogHourBucketProvider =
    NotifierProvider<HomeCatalogHourBucketNotifier, int>(
  HomeCatalogHourBucketNotifier.new,
);

class HomeCatalogHourBucketNotifier extends Notifier<int> {
  Timer? _timer;

  @override
  int build() {
    ref.onDispose(() => _timer?.cancel());
    _scheduleNextTick();
    return homeCatalogHourBucket();
  }

  void _scheduleNextTick() {
    _timer?.cancel();
    final now = DateTime.now();
    final nextHour = DateTime(now.year, now.month, now.day, now.hour + 1);
    final delay = nextHour.difference(now) + const Duration(seconds: 1);
    _timer = Timer(delay, () {
      state = homeCatalogHourBucket();
      _scheduleNextTick();
    });
  }
}

class HomeFeedContext {
  const HomeFeedContext({
    required this.api,
    required this.providerId,
    required this.filter,
    required this.genres,
    required this.canUseBootCache,
    required this.bucket,
  });

  final TmdbApi api;
  final int? providerId;
  final ShellHomeCategory? filter;
  final ({List<int>? movie, List<int>? tv}) genres;
  final bool canUseBootCache;
  final int bucket;
}

final homeTrendingProvider =
    FutureProvider.autoDispose<List<Movie>>((ref) async {
  final ctx = _watchHomeFeedContext(ref);
  if (ctx.providerId != null) {
    return _fetchMediaFiltered(
      filter: ctx.filter,
      movieFetch: () => _fetchMoviesPool(
        api: ctx.api,
        bucket: ctx.bucket,
        salt: 'trending-m-prov',
        standard: (page) =>
            ctx.api.discoverMovies(watchProviderId: ctx.providerId, page: page),
        genres: ctx.genres.movie,
        watchProviderId: ctx.providerId,
      ),
      tvFetch: () => _fetchTvPool(
        api: ctx.api,
        bucket: ctx.bucket,
        salt: 'trending-tv-prov',
        standard: (page) =>
            ctx.api.discoverTvShows(watchProviderId: ctx.providerId, page: page),
        genres: ctx.genres.tv,
        watchProviderId: ctx.providerId,
      ),
    );
  }
  return _fetchMediaFiltered(
    filter: ctx.filter,
    movieFetch: () => _fetchMoviesPool(
      api: ctx.api,
      bucket: ctx.bucket,
      salt: 'trending-m',
      standard: (page) => ctx.api.getTrending(page: page),
      genres: ctx.genres.movie,
      page1Cache: ctx.canUseBootCache ? BootCache.trending : null,
    ),
    tvFetch: () => _fetchTvPool(
      api: ctx.api,
      bucket: ctx.bucket,
      salt: 'trending-tv',
      standard: (page) => ctx.api.getTrendingTv(page: page),
      genres: ctx.genres.tv,
    ),
  );
});

final homePopularProvider =
    FutureProvider.autoDispose<List<Movie>>((ref) async {
  final ctx = _watchHomeFeedContext(ref);
  if (ctx.providerId != null) {
    return _fetchMediaFiltered(
      filter: ctx.filter,
      movieFetch: () => _fetchMoviesPool(
        api: ctx.api,
        bucket: ctx.bucket,
        salt: 'popular-m-prov',
        preserveRankOrder: true,
        standard: (page) => ctx.api.discoverMovies(
          watchProviderId: ctx.providerId,
          sortBy: 'vote_average.desc',
          minRating: 0,
          page: page,
        ),
        genres: ctx.genres.movie,
        watchProviderId: ctx.providerId,
        sortBy: 'vote_average.desc',
        minRating: 0,
      ),
      tvFetch: () => _fetchTvPool(
        api: ctx.api,
        bucket: ctx.bucket,
        salt: 'popular-tv-prov',
        preserveRankOrder: true,
        standard: (page) => ctx.api.discoverTvShows(
          watchProviderId: ctx.providerId,
          sortBy: 'vote_average.desc',
          minRating: 0,
          page: page,
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
    movieFetch: () => _fetchMoviesPool(
      api: ctx.api,
      bucket: ctx.bucket,
      salt: 'popular-m',
      preserveRankOrder: true,
      standard: (page) => ctx.api.getPopular(page: page),
      genres: ctx.genres.movie,
      sortBy: 'vote_average.desc',
      page1Cache: ctx.canUseBootCache ? BootCache.popular : null,
    ),
    tvFetch: () => _fetchTvPool(
      api: ctx.api,
      bucket: ctx.bucket,
      salt: 'popular-tv',
      preserveRankOrder: true,
      standard: (page) => ctx.api.getPopularTv(page: page),
      genres: ctx.genres.tv,
      sortBy: 'vote_average.desc',
    ),
  );
});

final homeNowPlayingProvider =
    FutureProvider.autoDispose<List<Movie>>((ref) async {
  final ctx = _watchHomeFeedContext(ref);
  if (ctx.providerId != null) {
    return _fetchMediaFiltered(
      filter: ctx.filter,
      movieFetch: () => _fetchMoviesPool(
        api: ctx.api,
        bucket: ctx.bucket,
        salt: 'now-m-prov',
        standard: (page) => ctx.api.discoverMovies(
          watchProviderId: ctx.providerId,
          sortBy: 'primary_release_date.desc',
          page: page,
        ),
        genres: ctx.genres.movie,
        watchProviderId: ctx.providerId,
        sortBy: 'primary_release_date.desc',
      ),
      tvFetch: () => _fetchTvPool(
        api: ctx.api,
        bucket: ctx.bucket,
        salt: 'now-tv-prov',
        standard: (page) => ctx.api.discoverTvShows(
          watchProviderId: ctx.providerId,
          sortBy: 'first_air_date.desc',
          page: page,
        ),
        genres: ctx.genres.tv,
        watchProviderId: ctx.providerId,
        sortBy: 'first_air_date.desc',
      ),
    );
  }
  return _fetchMediaFiltered(
    filter: ctx.filter,
    movieFetch: () => _fetchMoviesPool(
      api: ctx.api,
      bucket: ctx.bucket,
      salt: 'now-m',
      standard: (page) => ctx.api.getNowPlaying(page: page),
      genres: ctx.genres.movie,
      sortBy: 'primary_release_date.desc',
      page1Cache: ctx.canUseBootCache ? BootCache.nowPlaying : null,
    ),
    tvFetch: () => _fetchTvPool(
      api: ctx.api,
      bucket: ctx.bucket,
      salt: 'now-tv',
      standard: (page) => ctx.api.getOnTheAir(page: page),
      genres: ctx.genres.tv,
      sortBy: 'first_air_date.desc',
    ),
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
    required String salt,
  }) {
    return _fetchMediaFiltered(
      filter: ctx.filter,
      movieFetch: () => _fetchMoviesPool(
        api: ctx.api,
        bucket: ctx.bucket,
        salt: '$salt-m',
        standard: (page) => ctx.api.discoverMovies(
          releaseDateGte: releaseDateGte,
          releaseDateLte: releaseDateLte,
          minRating: minRating,
          watchProviderId: ctx.providerId,
          sortBy: 'popularity.desc',
          page: page,
        ),
        genres: ctx.genres.movie,
        releaseDateGte: releaseDateGte,
        releaseDateLte: releaseDateLte,
        minRating: minRating,
        watchProviderId: ctx.providerId,
        sortBy: 'popularity.desc',
      ),
      tvFetch: () => _fetchTvPool(
        api: ctx.api,
        bucket: ctx.bucket,
        salt: '$salt-tv',
        standard: (page) => ctx.api.discoverTvShows(
          releaseDateGte: releaseDateGte,
          releaseDateLte: releaseDateLte,
          minRating: minRating,
          watchProviderId: ctx.providerId,
          sortBy: 'popularity.desc',
          page: page,
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
    salt: 'featured-month',
  );
  // Calendar-month (+ optional service/genre) is often thin. Keep new-this-month
  // first, then fill from popular on the same filters so the row stays full.
  final needsFill = ctx.providerId != null ||
      (ctx.genres.movie != null && ctx.genres.movie!.isNotEmpty) ||
      (ctx.genres.tv != null && ctx.genres.tv!.isNotEmpty);
  if (!needsFill) return month;
  if (month.length >= kHomeRailDisplayCap) return month;
  final popular = await load(salt: 'featured-fill');
  return _uniqueMedia(month, popular);
});
