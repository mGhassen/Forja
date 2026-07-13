import 'dart:async';
import 'package:rust/rust.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:forja/shared/catalog/bestsimilar_scraper.dart';
import 'package:forja/shared/widgets/home_loading_skeleton.dart';
import 'package:forja/shared/services/tracker/trakt_service.dart';
import 'package:forja/shared/services/tracker/simkl_service.dart';
import 'package:forja/shell/app_router.dart';
import 'package:forja/app/boot_cache.dart';
import 'package:forja/shell/home_top_bar.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shell/shell_tab_refresh.dart';
import 'package:forja/features/home/home_genre_categories.dart';
import 'package:forja/features/home/home_hero.dart';
import 'package:forja/features/home/stremio_catalog_screen.dart';
import 'package:forja/features/home/widgets/because_you_watched_section.dart';
import 'package:forja/features/home/widgets/continue_watching_section.dart';
import 'package:forja/features/home/widgets/home_mood_section.dart';
import 'package:forja/features/home/widgets/home_movie_section.dart';
import 'package:forja/features/home/widgets/stremio_catalog_section.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';

bool _usesShellHomeLayout(BuildContext context) {
  return ShellScope.profileOf(context) != ShellProfile.mobile;
}


SliverToBoxAdapter _homeRowSliver(
  Widget section, {
  required bool isFirstAfterHero,
}) {
  return SliverToBoxAdapter(
    child: Builder(
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isFirstAfterHero)
            SizedBox(height: shellHomeRowSpacing(context)),
          RepaintBoundary(child: section),
        ],
      ),
    ),
  );
}


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin, ShellTabRefresh<HomeScreen> {

  final TmdbApi _api = TmdbApi();
  final StremioService _stremio = StremioService();
  final ScrollController _homeScrollController = ScrollController();
  final HomeHeroController _homeHeroController = HomeHeroController();
  late Future<List<Movie>> _trendingFuture;
  late Future<List<Movie>> _popularFuture;
  late Future<List<Movie>> _featuredThisMonthFuture;
  late Future<List<Movie>> _nowPlayingFuture;

  List<({String id, String label, Future<List<Movie>> future})>
      _randomCategoryRows = [];
  int _homeFeedEpoch = 0;


  // Stremio catalog data
  List<Map<String, dynamic>> _stremioCatalogs = [];
  final Map<String, List<Map<String, dynamic>>> _catalogItems = {};
  bool _catalogsLoaded = false;
  bool _stremioCatalogsLoading = true;

  // Trakt personalized sections
  List<Movie> _traktRecommendations = [];
  List<Movie> _traktUpcomingShows = [];
  List<Movie> _traktUpcomingMovies = [];
  bool _traktRecsLoading = false;
  bool _traktShowsLoading = false;
  bool _traktMoviesLoading = false;

  // "Because you watched ___" — randomized seed pulled from continue-watching
  // once per session, then BestSimilar.com recommendations (mapped to TMDB).
  Map<String, dynamic>? _becauseSeed; // raw history item
  Future<List<Movie>>? _becauseFuture;
  int _becausePoolSize = 0; // unique in-progress shows; controls shuffle button
  StreamSubscription<List<Map<String, dynamic>>>? _historySeedSub;
  VoidCallback? _splashDismissedListener;
  VoidCallback? _watchProviderListener;
  VoidCallback? _homeCategoryListener;
  VoidCallback? _homeGenreListener;

  bool _shellOffsetSyncScheduled = false;

  // Mood/genre filter state
  String _selectedMood = 'mind';
  Future<List<Movie>>? _moodFuture;

  // Mood definitions — movie and TV use different TMDB genre IDs.
  static const List<({
    String id,
    String label,
    IconData icon,
    Color accent,
    List<int> movieGenres,
    List<int> tvGenres,
  })> _moods = [
    (
      id: 'mind',
      label: 'Mind-Bending',
      icon: Icons.psychology_rounded,
      accent: Color(0xFF8B5CF6),
      movieGenres: [878, 9648],
      tvGenres: [10765, 9648],
    ),
    (
      id: 'feel',
      label: 'Feel-Good',
      icon: Icons.wb_sunny_rounded,
      accent: Color(0xFFFBBF24),
      movieGenres: [35, 10751],
      tvGenres: [35, 10751],
    ),
    (
      id: 'dark',
      label: 'Dark Thrillers',
      icon: Icons.dark_mode_rounded,
      accent: Color(0xFF64748B),
      movieGenres: [53, 80],
      tvGenres: [80, 9648],
    ),
    (
      id: 'romance',
      label: 'Romance',
      icon: Icons.favorite_rounded,
      accent: Color(0xFFEC4899),
      movieGenres: [10749],
      tvGenres: [18],
    ),
    (
      id: 'horror',
      label: 'Horror',
      icon: Icons.bedtime_rounded,
      accent: Color(0xFF7C3AED),
      movieGenres: [27],
      tvGenres: [10765, 9648],
    ),
    (
      id: 'action',
      label: 'Action',
      icon: Icons.local_fire_department_rounded,
      accent: Color(0xFFF97316),
      movieGenres: [28, 12],
      tvGenres: [10759],
    ),
    (
      id: 'animated',
      label: 'Animated',
      icon: Icons.brush_rounded,
      accent: Color(0xFF06B6D4),
      movieGenres: [16],
      tvGenres: [16],
    ),
    (
      id: 'drama',
      label: 'Drama',
      icon: Icons.theaters_rounded,
      accent: Color(0xFF3B82F6),
      movieGenres: [18],
      tvGenres: [18],
    ),
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  Duration get shellStaleAfter => ShellTokens.tabStaleHome;

  @override
  Future<void> onShellTabRefresh({required bool force}) => _reloadHomeFeed();

  int? get _watchProviderId => ShellBus.selectedWatchProviderId.value;

  ShellHomeCategory? get _mediaFilter => ShellBus.homeCategory.value;

  ({List<int>? movie, List<int>? tv}) get _genreIds {
    final genre = lookupHomeGenre(ShellBus.homeSelectedGenreId.value);
    if (genre == null) return (movie: null, tv: null);
    return (movie: genre.movieGenres, tv: genre.tvGenres);
  }

  Future<List<Movie>> _fetchMovies({
    required Future<List<Movie>> Function() standard,
    List<int>? genres,
    int? watchProviderId,
    String sortBy = 'popularity.desc',
    double? minRating,
    String? releaseDateGte,
    String? releaseDateLte,
  }) {
    if (genres == null || genres.isEmpty) return standard();
    return _api.discoverMovies(
      genres: genres,
      watchProviderId: watchProviderId,
      sortBy: sortBy,
      minRating: minRating,
      releaseDateGte: releaseDateGte,
      releaseDateLte: releaseDateLte,
    );
  }

  Future<List<Movie>> _fetchTv({
    required Future<List<Movie>> Function() standard,
    List<int>? genres,
    int? watchProviderId,
    String sortBy = 'popularity.desc',
    double? minRating,
    String? releaseDateGte,
    String? releaseDateLte,
  }) {
    if (genres == null || genres.isEmpty) return standard();
    return _api.discoverTvShows(
      genres: genres,
      watchProviderId: watchProviderId,
      sortBy: sortBy,
      minRating: minRating,
      releaseDateGte: releaseDateGte,
      releaseDateLte: releaseDateLte,
    );
  }

  Future<List<Movie>> _fetchCategoryRow(
    ({String id, String label, List<int> movieGenres, List<int> tvGenres})
        category,
  ) {
    final providerId = _watchProviderId;
    final globalGenres = _genreIds;
    final movieGenres = globalGenres.movie ?? category.movieGenres;
    final tvGenres = globalGenres.tv ?? category.tvGenres;
    return _fetchMediaFiltered(
      movieFetch: () => _api.discoverMovies(
        genres: movieGenres,
        watchProviderId: providerId,
      ),
      tvFetch: () => _api.discoverTvShows(
        genres: tvGenres,
        watchProviderId: providerId,
      ),
    );
  }

  void _resetRandomCategoryRows() {
    final selectedGenreId = ShellBus.homeSelectedGenreId.value;
    final List<
        ({
          String id,
          String label,
          List<int> movieGenres,
          List<int> tvGenres,
        })> picked;
    if (selectedGenreId != null) {
      picked = homeGenreCategories
          .where((category) => category.id == selectedGenreId)
          .toList();
    } else {
      final pool = List.of(homeGenreCategories)..shuffle(math.Random());
      picked = pool.take(3).toList();
    }
    _randomCategoryRows = [
      for (final category in picked)
        (
          id: category.id,
          label: category.label,
          future: _fetchCategoryRow(category),
        ),
    ];
  }

  static const int _kGenreRowOrderBase = 21;

  List<Widget> _randomCategoryRowSlivers() => [
        for (var i = 0; i < _randomCategoryRows.length; i++)
          _homeRowSliver(
            HomeMovieSection(
              key: ValueKey(
                '${_randomCategoryRows[i].id}-$_homeFeedEpoch',
              ),
              title: _randomCategoryRows[i].label,
              future: _randomCategoryRows[i].future,
              onMovieTap: _openDetails,
              tvRowId: 'genre-${_randomCategoryRows[i].id}',
              tvRowOrder: _kGenreRowOrderBase + i,
            ),
            isFirstAfterHero: false,
          ),
      ];

  List<Movie> _enforceMediaFilter(List<Movie> items) {
    final filter = _mediaFilter;
    if (filter == ShellHomeCategory.films) {
      return items.where((movie) => movie.mediaType != 'tv').toList();
    }
    if (filter == ShellHomeCategory.tvShows) {
      return items.where((movie) => movie.mediaType == 'tv').toList();
    }
    return items;
  }

  Future<List<Movie>> _fetchMediaFiltered({
    required Future<List<Movie>> Function() movieFetch,
    required Future<List<Movie>> Function() tvFetch,
    List<Movie>? movieCache,
    void Function(List<Movie> movies)? onLoaded,
  }) {
    final filter = _mediaFilter;
    if (filter == ShellHomeCategory.films) {
      if (movieCache != null) {
        final movies = _enforceMediaFilter(movieCache);
        onLoaded?.call(movies);
        return Future.value(movies);
      }
      return movieFetch()
          .then((movies) {
            final filtered = _enforceMediaFilter(movies);
            onLoaded?.call(filtered);
            return filtered;
          })
          .catchError((_) => <Movie>[]);
    }
    if (filter == ShellHomeCategory.tvShows) {
      return tvFetch()
          .then((movies) {
            final filtered = _enforceMediaFilter(movies);
            onLoaded?.call(filtered);
            return filtered;
          })
          .catchError((_) => <Movie>[]);
    }
    return _fetchMixed(
      movieFetch,
      tvFetch,
      movieCache: movieCache,
      onLoaded: onLoaded,
    );
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

  Future<List<Movie>> _fetchMixed(
    Future<List<Movie>> Function() movieFetch,
    Future<List<Movie>> Function() tvFetch, {
    List<Movie>? movieCache,
    void Function(List<Movie> movies)? onLoaded,
  }) {
    Future<List<Movie>> safeTv() =>
        tvFetch().catchError((_) => <Movie>[]);

    if (movieCache != null) {
      return safeTv().then((tv) {
        final merged = _interleaveMedia(movieCache, tv);
        onLoaded?.call(merged);
        return merged;
      });
    }
    final safeMovie = movieFetch().catchError((_) => <Movie>[]);
    return Future.wait([safeMovie, safeTv()]).then((results) {
      final merged = _interleaveMedia(results[0], results[1]);
      onLoaded?.call(merged);
      return merged;
    });
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

  Future<List<Movie>> _loadFeaturedThisMonth() {
    final range = _currentMonthDateRange();
    final providerId = _watchProviderId;
    final genres = _genreIds;
    return _fetchMediaFiltered(
      movieFetch: () => _fetchMovies(
        standard: () => _api.discoverMovies(
          releaseDateGte: range.gte,
          releaseDateLte: range.lte,
          minRating: 6.0,
          watchProviderId: providerId,
          sortBy: 'popularity.desc',
        ),
        genres: genres.movie,
        releaseDateGte: range.gte,
        releaseDateLte: range.lte,
        minRating: 6.0,
        watchProviderId: providerId,
        sortBy: 'popularity.desc',
      ),
      tvFetch: () => _fetchTv(
        standard: () => _api.discoverTvShows(
          releaseDateGte: range.gte,
          releaseDateLte: range.lte,
          minRating: 6.0,
          watchProviderId: providerId,
          sortBy: 'popularity.desc',
        ),
        genres: genres.tv,
        releaseDateGte: range.gte,
        releaseDateLte: range.lte,
        minRating: 6.0,
        watchProviderId: providerId,
        sortBy: 'popularity.desc',
      ),
    );
  }

  void _resetHomeCategoryFeeds({bool useBootCache = false}) {
    _homeFeedEpoch++;
    final providerId = _watchProviderId;
    final genres = _genreIds;
    final canUseBootCache = useBootCache &&
        providerId == null &&
        ShellBus.homeSelectedGenreId.value == null &&
        _mediaFilter == null;

    if (providerId != null) {
      _trendingFuture = _fetchMediaFiltered(
        movieFetch: () => _fetchMovies(
          standard: () => _api.discoverMovies(watchProviderId: providerId),
          genres: genres.movie,
          watchProviderId: providerId,
        ),
        tvFetch: () => _fetchTv(
          standard: () => _api.discoverTvShows(watchProviderId: providerId),
          genres: genres.tv,
          watchProviderId: providerId,
        ),
      );
      _popularFuture = _fetchMediaFiltered(
        movieFetch: () => _fetchMovies(
          standard: () => _api.discoverMovies(
            watchProviderId: providerId,
            sortBy: 'vote_average.desc',
            minRating: 7,
          ),
          genres: genres.movie,
          watchProviderId: providerId,
          sortBy: 'vote_average.desc',
          minRating: 7,
        ),
        tvFetch: () => _fetchTv(
          standard: () => _api.discoverTvShows(
            watchProviderId: providerId,
            sortBy: 'vote_average.desc',
            minRating: 7,
          ),
          genres: genres.tv,
          watchProviderId: providerId,
          sortBy: 'vote_average.desc',
          minRating: 7,
        ),
      );
      _nowPlayingFuture = _fetchMediaFiltered(
        movieFetch: () => _fetchMovies(
          standard: () => _api.discoverMovies(
            watchProviderId: providerId,
            sortBy: 'primary_release_date.desc',
          ),
          genres: genres.movie,
          watchProviderId: providerId,
          sortBy: 'primary_release_date.desc',
        ),
        tvFetch: () => _fetchTv(
          standard: () => _api.discoverTvShows(
            watchProviderId: providerId,
            sortBy: 'first_air_date.desc',
          ),
          genres: genres.tv,
          watchProviderId: providerId,
          sortBy: 'first_air_date.desc',
        ),
      );
      _featuredThisMonthFuture = _loadFeaturedThisMonth();
    } else {
      _trendingFuture = _fetchMediaFiltered(
        movieFetch: () => _fetchMovies(
          standard: _api.getTrending,
          genres: genres.movie,
        ),
        tvFetch: () => _fetchTv(
          standard: _api.getTrendingTv,
          genres: genres.tv,
        ),
        movieCache: canUseBootCache ? BootCache.trending : null,
      );
      _popularFuture = _fetchMediaFiltered(
        movieFetch: () => _fetchMovies(
          standard: _api.getPopular,
          genres: genres.movie,
          sortBy: 'vote_average.desc',
        ),
        tvFetch: () => _fetchTv(
          standard: _api.getPopularTv,
          genres: genres.tv,
          sortBy: 'vote_average.desc',
        ),
        movieCache: canUseBootCache ? BootCache.popular : null,
      );
      _nowPlayingFuture = _fetchMediaFiltered(
        movieFetch: () => _fetchMovies(
          standard: _api.getNowPlaying,
          genres: genres.movie,
          sortBy: 'primary_release_date.desc',
        ),
        tvFetch: () => _fetchTv(
          standard: _api.getOnTheAir,
          genres: genres.tv,
          sortBy: 'first_air_date.desc',
        ),
        movieCache: canUseBootCache ? BootCache.nowPlaying : null,
      );
      _featuredThisMonthFuture = _loadFeaturedThisMonth();
    }
    _moodFuture = _loadMoodMovies(_selectedMood);
    _resetRandomCategoryRows();
  }

  Future<void> _reloadHomeFeed() async {
    if (!mounted) return;
    setState(() => _resetHomeCategoryFeeds());
    await _loadStremioCatalogs();
  }

  void _onWatchProviderChanged() {
    if (!mounted) return;
    setState(() => _resetHomeCategoryFeeds());
  }

  void _onHomeCategoryChanged() {
    if (!mounted) return;
    setState(() => _resetHomeCategoryFeeds());
  }

  void _onHomeGenreChanged() {
    if (!mounted) return;
    setState(() => _resetHomeCategoryFeeds());
  }


  void _syncHomeScrollOffset() {
    if (_shellOffsetSyncScheduled) return;
    _shellOffsetSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _shellOffsetSyncScheduled = false;
      if (!mounted || !_homeScrollController.hasClients) return;
      final offset = _homeScrollController.offset;
      if (ShellBus.homeScrollOffset.value != offset) {
        ShellBus.homeScrollOffset.value = offset;
      }
    });
  }


  @override
  void initState() {
    super.initState();
    _homeScrollController.addListener(_syncHomeScrollOffset);
    _resetHomeCategoryFeeds(useBootCache: true);

    _loadStremioCatalogs();
    SettingsService.addonChangeNotifier.addListener(_onAddonsChanged);
    _watchProviderListener = _onWatchProviderChanged;
    ShellBus.selectedWatchProviderId.addListener(_watchProviderListener!);
    _homeCategoryListener = _onHomeCategoryChanged;
    ShellBus.homeCategory.addListener(_homeCategoryListener!);
    _homeGenreListener = _onHomeGenreChanged;
    ShellBus.homeSelectedGenreId.addListener(_homeGenreListener!);

    _schedulePostSplashWork();
    markShellTabFresh();
  }

  void _schedulePostSplashWork() {
    void run() {
      TraktService().fullSync();
      SimklService().fullSync();
      _loadTraktRecommendations();
      _loadTraktCalendar();
      _loadTraktCalendarMovies();
      _initBecauseYouWatched();
    }

    void schedule() {
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        if (mounted) run();
      });
    }

    if (ShellBus.splashDismissed.value) {
      schedule();
      return;
    }

    _splashDismissedListener = () {
      if (!ShellBus.splashDismissed.value) return;
      ShellBus.splashDismissed.removeListener(_splashDismissedListener!);
      _splashDismissedListener = null;
      schedule();
    };
    ShellBus.splashDismissed.addListener(_splashDismissedListener!);
  }

  void _initBecauseYouWatched() {
    final svc = WatchHistoryService();
    if (!_pickBecauseSeed(svc.current)) {
      _historySeedSub = svc.historyStream.listen((items) {
        if (_pickBecauseSeed(items)) {
          _historySeedSub?.cancel();
          _historySeedSub = null;
        }
      });
    }
  }

  /// Returns in-progress continue-watching items (2–90%), one per tmdbId.
  List<Map<String, dynamic>> _inProgressPool(List<Map<String, dynamic>> history) {
    return inProgressPoolByShow(history);
  }

  String _seedMediaType(Map<String, dynamic> seed) {
    final mediaType = (seed['mediaType'] as String?) ??
        (seed['season'] != null ? 'tv' : 'movie');
    return mediaType == 'tv' || mediaType == 'series' ? 'tv' : 'movie';
  }

  Map<String, dynamic>? _pickOppositeSeed(
    List<Map<String, dynamic>> pool,
    Map<String, dynamic> primary,
  ) {
    final wantOpposite = _seedMediaType(primary) == 'tv' ? 'movie' : 'tv';
    final candidates =
        pool.where((s) => _seedMediaType(s) == wantOpposite).toList();
    if (candidates.isEmpty) return null;
    return candidates[math.Random().nextInt(candidates.length)];
  }

  /// Returns true if a seed was successfully picked. Filters to in-progress
  /// items (between 2% and 90% watched) and picks one at random per session.
  bool _pickBecauseSeed(List<Map<String, dynamic>> history) {
    if (!mounted || history.isEmpty) return false;
    final pool = _inProgressPool(history);
    if (pool.isEmpty) return false;
    final seed = pool[math.Random().nextInt(pool.length)];
    final secondary = _pickOppositeSeed(pool, seed);
    setState(() {
      _becauseSeed = seed;
      _becausePoolSize = pool.length;
      _becauseFuture = _loadBecauseRecsMixed(seed, secondary);
    });
    return true;
  }

  Future<List<Movie>> _loadBecauseRecsMixed(
    Map<String, dynamic> primary,
    Map<String, dynamic>? secondary,
  ) async {
    if (secondary == null) return _loadBecauseRecs(primary);
    final results = await Future.wait([
      _loadBecauseRecs(primary),
      _loadBecauseRecs(secondary),
    ]);
    return _interleaveMedia(results[0], results[1]);
  }

  Future<List<Movie>> _loadBecauseRecs(Map<String, dynamic> seed) async {
    final title = (seed['title'] as String?)?.trim();
    if (title == null || title.isEmpty) {
      debugPrint('[BecauseYouWatched] no title in seed');
      return const [];
    }
    final mediaType = (seed['mediaType'] as String?) ??
        (seed['season'] != null ? 'tv' : 'movie');
    final isTv = mediaType == 'tv' || mediaType == 'series';
    final wantType = isTv ? 'tv' : 'movie';
    debugPrint('[BecauseYouWatched] seed="$title" isTv=$isTv');

    try {
      // 1) Autocomplete on bestsimilar; pick the closest hit (forgiving).
      final hits = await BestSimilarScraper.autocomplete(title);
      debugPrint('[BecauseYouWatched] autocomplete hits=${hits.length}');
      if (hits.isEmpty) return const [];

      final lowerTitle = title.toLowerCase();
      BSAutocompleteHit? hit;
      // Prefer same-type exact title match.
      for (final h in hits) {
        if (h.isTv == isTv && h.title.toLowerCase() == lowerTitle) {
          hit = h; break;
        }
      }
      // Then any exact title match.
      hit ??= hits.firstWhere(
        (h) => h.title.toLowerCase() == lowerTitle,
        orElse: () => hits.first,
      );
      debugPrint('[BecauseYouWatched] picked hit id=${hit.id} title="${hit.title}"');

      // 2) Detail page → similar items.
      final details =
          await BestSimilarScraper.fetchDetails(id: hit.id, slug: hit.slug);
      if (details == null || details.similar.isEmpty) {
        debugPrint('[BecauseYouWatched] no similar items returned');
        return const [];
      }
      debugPrint('[BecauseYouWatched] bestsimilar similar=${details.similar.length}');

      // 3) Resolve each BS item to a TMDB Movie (parallel) — relaxed threshold
      //    so we don't drop everything when the year is unknown.
      final lookups = details.similar.map((it) async {
        try {
          final hits = await _api.searchMulti(it.title);
          if (hits.isEmpty) return null;
          Movie? best;
          var bestScore = -1;
          for (final h in hits) {
            var s = 0;
            final ht = h.title.toLowerCase();
            final it2 = it.title.toLowerCase();
            if (ht == it2) {
              s += 5;
            } else if (ht.startsWith(it2) || it2.startsWith(ht)) {
              s += 2;
            }
            if (h.mediaType == wantType) s += 3;
            if (it.year != null && h.releaseDate.length >= 4) {
              final hy = int.tryParse(h.releaseDate.substring(0, 4));
              if (hy == it.year) {
                s += 4;
              } else if (hy != null && (hy - it.year!).abs() <= 1) {
                s += 1;
              }
            }
            if (h.posterPath.isNotEmpty) s += 1;
            if (s > bestScore) {
              bestScore = s;
              best = h;
            }
          }
          if (best == null || bestScore < 2) return null;
          if (best.posterPath.isEmpty) return null;
          return MapEntry(it.similarityPercent ?? -1, best);
        } catch (_) {
          return null;
        }
      });
      final resolved = await Future.wait(lookups);

      // 4) Sort by bestsimilar similarity % (desc), drop dupes & nulls.
      //    Items without a percentage fall to the bottom.
      final ranked = resolved.whereType<MapEntry<int, Movie>>().toList()
        ..sort((a, b) => b.key.compareTo(a.key));
      final out = <Movie>[];
      final seen = <String>{};
      for (final e in ranked) {
        final key = '${e.value.mediaType}:${e.value.id}';
        if (!seen.add(key)) continue;
        out.add(e.value);
      }
      debugPrint('[BecauseYouWatched] tmdb-resolved=${out.length} (sorted by %)');
      return out;
    } catch (e) {
      debugPrint('[BecauseYouWatched] failed: $e');
      return const [];
    }
  }

  void _shuffleBecauseSeed() {
    _pickBecauseSeed(WatchHistoryService().current);
  }

  Future<void> _loadTraktRecommendations() async {
    try {
      if (!await TraktService().isLoggedIn()) return;
      if (mounted) setState(() => _traktRecsLoading = true);
      // Fetch movie + show recommendations and convert via TMDB
      final movieRecs = await TraktService().getRecommendations('movies');
      final showRecs = await TraktService().getRecommendations('shows');
      final all = [...movieRecs, ...showRecs];
      final entries = all.take(20).map((rec) {
        final item = rec['movie'] ?? rec['show'];
        if (item == null) return null;
        final ids = item['ids'] as Map<String, dynamic>?;
        final tmdbId = ids?['tmdb'] as int?;
        if (tmdbId == null) return null;
        final type = rec.containsKey('show') ? 'tv' : 'movie';
        return (tmdbId: tmdbId, type: type);
      }).whereType<({int tmdbId, String type})>().toList();

      // Parallel TMDB lookups in batches of 5
      final movies = <Movie>[];
      for (var i = 0; i < entries.length; i += 5) {
        final batch = entries.skip(i).take(5);
        final results = await Future.wait(
          batch.map((e) async {
            try {
              return e.type == 'tv'
                  ? await _api.getTvDetails(e.tmdbId)
                  : await _api.getMovieDetails(e.tmdbId);
            } catch (_) { return null; }
          }),
        );
        movies.addAll(results.whereType<Movie>());
      }
      if (mounted && movies.isNotEmpty) {
        setState(() => _traktRecommendations = movies);
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _traktRecsLoading = false);
    }
  }

  Future<void> _loadTraktCalendar() async {
    try {
      if (!await TraktService().isLoggedIn()) return;
      if (mounted) setState(() => _traktShowsLoading = true);
      final shows = await TraktService().getCalendarShows(days: 14);
      final movies = <Movie>[];
      for (final entry in shows.take(20)) {
        final show = entry['show'] as Map<String, dynamic>? ?? {};
        final tmdbId = (show['ids'] as Map<String, dynamic>?)?['tmdb'] as int?;
        if (tmdbId == null) continue;
        try {
          movies.add(await _api.getTvDetails(tmdbId));
        } catch (_) {}
      }
      if (mounted && movies.isNotEmpty) {
        setState(() => _traktUpcomingShows = movies);
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _traktShowsLoading = false);
    }
  }

  Future<void> _loadTraktCalendarMovies() async {
    try {
      if (!await TraktService().isLoggedIn()) return;
      if (mounted) setState(() => _traktMoviesLoading = true);
      final entries = await TraktService().getCalendarMovies(days: 30);
      final movies = <Movie>[];
      for (final entry in entries.take(20)) {
        final movie = entry['movie'] as Map<String, dynamic>? ?? {};
        final tmdbId = (movie['ids'] as Map<String, dynamic>?)?['tmdb'] as int?;
        if (tmdbId == null) continue;
        try {
          movies.add(await _api.getMovieDetails(tmdbId));
        } catch (_) {}
      }
      if (mounted && movies.isNotEmpty) {
        setState(() => _traktUpcomingMovies = movies);
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _traktMoviesLoading = false);
    }
  }


  Future<List<Movie>> _loadMoodMovies(String moodId) async {
    final mood = _moods.firstWhere((m) => m.id == moodId, orElse: () => _moods.first);
    final providerId = _watchProviderId;
    return _fetchMediaFiltered(
      movieFetch: () => _api.discoverMovies(
        genres: mood.movieGenres,
        minRating: 6.0,
        watchProviderId: providerId,
      ),
      tvFetch: () => _api.discoverTvShows(
        genres: mood.tvGenres,
        minRating: 6.0,
        watchProviderId: providerId,
      ),
    ).catchError((_) => <Movie>[]);
  }

  void _selectMood(String moodId) {
    if (moodId == _selectedMood) return;
    setState(() {
      _selectedMood = moodId;
      _moodFuture = _loadMoodMovies(moodId);
    });
  }


  void _onAddonsChanged() {
    // Clear stale data and schedule a rebuild so the old sliders disappear
    // immediately while the new ones load.
    setState(() {
      _stremioCatalogs = [];
      _catalogItems.clear();
      _catalogsLoaded = false;
      _stremioCatalogsLoading = true;
    });
    _loadStremioCatalogs();
  }

  @override
  void dispose() {
    SettingsService.addonChangeNotifier.removeListener(_onAddonsChanged);
    if (_splashDismissedListener != null) {
      ShellBus.splashDismissed.removeListener(_splashDismissedListener!);
    }
    if (_watchProviderListener != null) {
      ShellBus.selectedWatchProviderId.removeListener(_watchProviderListener!);
    }
    if (_homeCategoryListener != null) {
      ShellBus.homeCategory.removeListener(_homeCategoryListener!);
    }
    if (_homeGenreListener != null) {
      ShellBus.homeSelectedGenreId.removeListener(_homeGenreListener!);
    }
    _homeScrollController.removeListener(_syncHomeScrollOffset);
    _homeScrollController.dispose();
    ShellBus.homeScrollOffset.value = 0;
    _historySeedSub?.cancel();
    super.dispose();
  }


  Future<void> _openDetails(Movie movie) async {
    if (!mounted) return;
    await AppRouter.openMovie(context, movie: movie);
  }

  Future<void> _watchNow(Movie movie) async {
    if (!mounted) return;
    await AppRouter.openMovie(context, movie: movie, autoPlay: true);
  }

  Future<void> _loadStremioCatalogs() async {
    if (mounted) setState(() => _stremioCatalogsLoading = true);
    try {
      final catalogs = await _stremio.getAllCatalogs();
      if (!mounted || catalogs.isEmpty) return;

      // Group non-search-required catalogs by addon, preserving order.
      final Map<String, List<Map<String, dynamic>>> byAddon = {};
      for (final c in catalogs) {
        if (c['searchRequired'] == true) continue;
        final key = c['addonBaseUrl'] as String;
        byAddon.putIfAbsent(key, () => []).add(c);
      }

      // Mark that we've started loading so the build can show shimmer / placeholders.
      if (mounted) setState(() => _catalogsLoaded = true);

      // For each addon, try catalogs in order until one returns items.
      // All addons are tried in parallel; within each addon they are tried sequentially.
      await Future.wait(byAddon.values.map((addonCatalogs) async {
        for (final cat in addonCatalogs) {
          try {
            final items = await _stremio.getCatalog(
              baseUrl: cat['addonBaseUrl'],
              type: cat['catalogType'],
              id: cat['catalogId'],
            );
            if (items.isEmpty) continue; // try next catalog for this addon

            // Tag each item with the addon that provided it
            for (final item in items) {
              item['_addonBaseUrl'] = cat['addonBaseUrl'];
              item['_addonName'] = cat['addonName'];
            }
            if (mounted) {
              final itemKey = '${cat['addonBaseUrl']}/${cat['catalogType']}/${cat['catalogId']}';
              setState(() {
                // Add the winning catalog to the list if not already present
                if (!_stremioCatalogs.any((c) =>
                    c['addonBaseUrl'] == cat['addonBaseUrl'] &&
                    c['catalogId'] == cat['catalogId'])) {
                  _stremioCatalogs = [..._stremioCatalogs, cat];
                }
                _catalogItems[itemKey] = items;
              });
            }
            return; // done for this addon
          } catch (_) {}
        }
      }));
    } catch (e) {
      debugPrint('[HomeScreen] Error loading Stremio catalogs: $e');
    } finally {
      if (mounted) setState(() => _stremioCatalogsLoading = false);
    }
  }

  void _openStremioCatalog(Map<String, dynamic> catalog) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StremioCatalogScreen(initialCatalog: catalog)),
    );
  }

  Future<void> _openStremioItem(Map<String, dynamic> item) async {
    final id = item['id']?.toString() ?? '';
    final type = item['type']?.toString() ?? 'movie';
    final name = item['name']?.toString() ?? 'Unknown';
    final poster = item['poster']?.toString() ?? '';
    final isCustomId = !id.startsWith('tt');
    
    // Check if this is a collection by ID prefix
    final isCollection = id.startsWith('ctmdb.') || type == 'collections';

    // IMDB ID → TMDB lookup
    if (!isCustomId && !isCollection) {
      try {
        final movie = await _api.findByImdbId(id, mediaType: type == 'series' ? 'tv' : 'movie');
        if (movie != null && mounted) {
          await AppRouter.openDetails(
            context,
            movie: movie,
            stremioItem: item,
          );
          return;
        }
      } catch (_) {}
    }

    // For non-custom IDs that failed, try name search
    if (!isCustomId && !isCollection) {
      try {
        final results = await _api.searchMulti(name);
        if (results.isNotEmpty && mounted) {
          final match = results.firstWhere(
            (m) => m.title.toLowerCase() == name.toLowerCase(),
            orElse: () => results.first,
          );
          await AppRouter.openDetails(
            context,
            movie: match,
            stremioItem: item,
          );
          return;
        }
      } catch (_) {}
    }

    // Custom ID, collection, or all lookups failed
    if (mounted) {
      // Override type to 'collections' if it's a collection ID
      final actualType = isCollection ? 'collections' : (type == 'series' ? 'tv' : 'movie');
      
      final movie = Movie(
        id: id.hashCode,
        imdbId: id.startsWith('tt') ? id : null,
        title: name,
        posterPath: poster,
        backdropPath: item['background']?.toString() ?? poster,
        voteAverage: double.tryParse(item['imdbRating']?.toString() ?? '') ?? 0,
        releaseDate: item['releaseInfo']?.toString() ?? '',
        overview: item['description']?.toString() ?? '',
        mediaType: actualType,
      );
      
      // Update the stremioItem type to collections if needed
      final updatedItem = Map<String, dynamic>.from(item);
      if (isCollection) {
        updatedItem['type'] = 'collections';
      }
      
      await AppRouter.openDetails(
        context,
        movie: movie,
        stremioItem: updatedItem,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final usesShellHome = _usesShellHomeLayout(context);
    final fullHero = homeIsFullCinematicHero(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncHomeScrollOffset();
    });

    final content = RefreshIndicator(
          onRefresh: () => refreshIfStale(force: true),
          color: ForjaShellColors.sectionAccent,
          child: CustomScrollView(
            controller: _homeScrollController,
            scrollCacheExtent: ScrollCacheExtent.pixels(500),
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: RepaintBoundary(
                  child: HomeCinematicHero(
                    key: ValueKey(_homeFeedEpoch),
                    moviesFuture: _trendingFuture,
                    compact: !fullHero,
                    usesShellHomeLayout: usesShellHome,
                    scrollController: _homeScrollController,
                    controller: _homeHeroController,
                    onOpenDetails: _openDetails,
                    onWatchNow: _watchNow,
                  ),
                ),
              ),

              if (!usesShellHome)
                _homeRowSliver(
                  HomeContinueWatchingSection(compactTop: true),
                  isFirstAfterHero: true,
                ),

              if (!usesShellHome)
                _homeRowSliver(
                  HomeMovieSection(
                    title: 'Featured This Month',
                    future: _featuredThisMonthFuture,
                    onMovieTap: _openDetails,
                  ),
                  isFirstAfterHero: false,
                ),

              if (usesShellHome)
                _homeRowSliver(
                  HomeMovieSection(
                    title: 'Featured This Month',
                    future: _featuredThisMonthFuture,
                    onMovieTap: _openDetails,
                    compactTop: true,
                    tvFocusUp: _homeHeroController.revealPlayFocus,
                    tvRowId: 'featured',
                    tvRowOrder: 0,
                  ),
                  isFirstAfterHero: false,
                ),

              if (usesShellHome)
                _homeRowSliver(
                  HomeMovieSection(
                    title: 'Popular',
                    future: _popularFuture,
                    onMovieTap: _openDetails,
                    showRank: true,
                    tvRowId: 'popular',
                    tvRowOrder: 1,
                  ),
                  isFirstAfterHero: false,
                ),

              if (usesShellHome)
                _homeRowSliver(
                  HomeContinueWatchingSection(
                    compactTop: false,
                    tvRowId: 'continue',
                    tvRowOrder: 2,
                  ),
                  isFirstAfterHero: false,
                ),

              // Mood / Genre chips — interactive filter
              _homeRowSliver(
                HomeMoodSection(
                  moods: _moods,
                  selectedId: _selectedMood,
                  onSelect: _selectMood,
                  future: _moodFuture,
                  onMovieTap: _openDetails,
                  compactTop: false,
                  tvRowOrder: 3,
                ),
                isFirstAfterHero: false,
              ),

              // "Because you watched ___" — BestSimilar.com recommendations
              // (the /recommendations endpoint, not the trash /similar one)
              if (_becauseSeed != null && _becauseFuture != null)
                _homeRowSliver(
                  HomeBecauseYouWatchedSection(
                    seedTitle: (_becauseSeed!['title'] as String?) ?? '',
                    seedPosterPath: (_becauseSeed!['posterPath'] as String?) ?? '',
                    future: _becauseFuture!,
                    onMovieTap: _openDetails,
                    // Only allow re-rolling when there's actually more than
                    // one in-progress show to choose between.
                    onShuffle: _becausePoolSize > 1 ? _shuffleBecauseSeed : null,
                  ),
                  isFirstAfterHero: false,
                ),

              if (!usesShellHome)
                _homeRowSliver(
                  HomeMovieSection(
                    title: 'Popular',
                    future: _popularFuture,
                    onMovieTap: _openDetails,
                    showRank: true,
                  ),
                  isFirstAfterHero: false,
                ),

              // Stremio Addon Catalogs
              if (_stremioCatalogsLoading && _stremioCatalogs.isEmpty)
                for (var i = 0; i < 2; i++)
                  _homeRowSliver(
                    homeLoadingShimmer(
                      homeMovieRowSkeleton(
                        context,
                        titleWidth: 180,
                        showSubtitle: true,
                      ),
                    ),
                    isFirstAfterHero: false,
                  ),

              if (_catalogsLoaded || _stremioCatalogs.isNotEmpty)
                ..._stremioCatalogs.map((cat) {
                  final key = '${cat['addonBaseUrl']}/${cat['catalogType']}/${cat['catalogId']}';
                  final items = _catalogItems[key];
                  if (items == null || items.isEmpty) {
                    return _homeRowSliver(
                      homeLoadingShimmer(
                        homeMovieRowSkeleton(
                          context,
                          titleWidth: 180,
                          showSubtitle: true,
                        ),
                      ),
                      isFirstAfterHero: false,
                    );
                  }
                  return _homeRowSliver(
                    HomeStremioCatalogSection(
                      catalog: cat,
                      items: items,
                      onItemTap: _openStremioItem,
                      onShowAll: () => _openStremioCatalog(cat),
                    ),
                    isFirstAfterHero: false,
                  );
                }),

              // Trakt Recommendations
              if (_traktRecsLoading)
                _homeRowSliver(
                  homeLoadingShimmer(
                    homeMovieRowSkeleton(context, titleWidth: 180),
                  ),
                  isFirstAfterHero: false,
                )
              else if (_traktRecommendations.isNotEmpty)
                _homeRowSliver(
                  HomeStaticMovieSection(
                    title: 'Recommended for You',
                    movies: _traktRecommendations,
                    onMovieTap: _openDetails,
                    tvRowId: 'trakt-recs',
                    tvRowOrder: 11,
                  ),
                  isFirstAfterHero: false,
                ),

              // Trakt Calendar
              if (_traktShowsLoading)
                _homeRowSliver(
                  homeLoadingShimmer(
                    homeMovieRowSkeleton(context, titleWidth: 170),
                  ),
                  isFirstAfterHero: false,
                )
              else if (_traktUpcomingShows.isNotEmpty)
                _homeRowSliver(
                  HomeStaticMovieSection(
                    title: 'Upcoming Schedule',
                    movies: _traktUpcomingShows,
                    onMovieTap: _openDetails,
                    tvRowId: 'trakt-shows',
                    tvRowOrder: 12,
                  ),
                  isFirstAfterHero: false,
                ),

              if (_traktMoviesLoading)
                _homeRowSliver(
                  homeLoadingShimmer(
                    homeMovieRowSkeleton(context, titleWidth: 160),
                  ),
                  isFirstAfterHero: false,
                )
              else if (_traktUpcomingMovies.isNotEmpty)
                _homeRowSliver(
                  HomeStaticMovieSection(
                    title: 'Upcoming Movies',
                    movies: _traktUpcomingMovies,
                    onMovieTap: _openDetails,
                    tvRowId: 'trakt-movies',
                    tvRowOrder: 13,
                  ),
                  isFirstAfterHero: false,
                ),

              // New Releases
              _homeRowSliver(
                HomeMovieSection(
                  title: 'New Releases',
                  future: _nowPlayingFuture,
                  onMovieTap: _openDetails,
                  tvRowId: 'new-releases',
                  tvRowOrder: 20,
                ),
                isFirstAfterHero: false,
              ),

              ..._randomCategoryRowSlivers(),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        );

    if (!usesShellHome) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          content,
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: HomeTopBar(),
          ),
        ],
      );
    }

    return content;
  }

}
