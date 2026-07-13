import 'dart:async';
import 'package:rust/rust.dart';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:forja/shared/catalog/bestsimilar_scraper.dart';
import 'package:forja/shared/widgets/home_loading_skeleton.dart';
import 'package:forja/shared/widgets/hub_details/hub_details_play_row.dart';
import 'package:forja/shared/widgets/my_list_button.dart';
import 'package:forja/shared/services/tracker/trakt_service.dart';
import 'package:forja/shared/services/tracker/simkl_service.dart';
import 'package:forja/shell/app_router.dart';
import 'package:forja/app/boot_cache.dart';
import 'package:forja/shell/home_top_bar.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shell/shell_tab_refresh.dart';
import 'package:forja/features/home/home_genre_categories.dart';
import 'package:forja/features/home/stremio_catalog_screen.dart';
import 'package:forja/features/home/widgets/because_you_watched_section.dart';
import 'package:forja/features/home/widgets/continue_watching_section.dart';
import 'package:forja/features/home/widgets/home_mood_section.dart';
import 'package:forja/features/home/widgets/home_movie_section.dart';
import 'package:forja/features/home/widgets/stremio_catalog_section.dart';
import 'package:forja/shared/widgets/hero/hero_pill_buttons.dart';
import 'package:forja/shared/widgets/hero/hero_title.dart';
import 'package:forja/shared/widgets/hero_overview_text.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:forja/shared/tv/media_details_tv_scope.dart';

bool _usesShellHomeLayout(BuildContext context) {
  return ShellScope.profileOf(context) != ShellProfile.mobile;
}

bool _isFullCinematicHero(BuildContext context) {
  if (ShellScope.metricsOf(context).usesTvDensity) return true;
  return MediaQuery.sizeOf(context).width >= ShellTokens.heroDesktopMinBodyWidth;
}

double _heroTextTopInset(BuildContext context) =>
    ShellTokens.heroTextColumnTopInsetDesktop;

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
  static const int _heroLoopLength = 10000;
  static const int _heroLoopStart = 5000;

  final TmdbApi _api = TmdbApi();
  final StremioService _stremio = StremioService();
  final PageController _heroController =
      PageController(initialPage: _heroLoopStart);
  final ScrollController _homeScrollController = ScrollController();
  final FocusNode _tvHeroPlayFocus = FocusNode(debugLabel: 'hero-play');
  final FocusNode _tvHeroGalleryFocus = FocusNode(debugLabel: 'hero-gallery');
  bool _tvHeroInitialFocusDone = false;
  late Future<List<Movie>> _trendingFuture;
  late Future<List<Movie>> _popularFuture;
  late Future<List<Movie>> _featuredThisMonthFuture;
  late Future<List<Movie>> _nowPlayingFuture;

  List<({String id, String label, Future<List<Movie>> future})>
      _randomCategoryRows = [];
  int _homeFeedEpoch = 0;

  Timer? _heroTimer;
  int _heroIndex = 0;

  // Hero logo cache: movieId -> logo URL
  final Map<int, String> _heroLogos = {};

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
  bool _heroHeightSyncScheduled = false;
  bool _heroHeightSyncDesktop = false;

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
        onLoaded: (movies) => _fetchHeroLogos(movies.take(5).toList()),
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
        onLoaded: (movies) => _fetchHeroLogos(movies.take(5).toList()),
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
    _heroIndex = 0;
    if (_heroController.hasClients) {
      _heroController.jumpToPage(_heroLoopStart);
    }
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

  void _publishHomeHeroHeight(bool usesShellHome) {
    _heroHeightSyncDesktop = usesShellHome;
    if (_heroHeightSyncScheduled) return;
    _heroHeightSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _heroHeightSyncScheduled = false;
      if (!mounted) return;
      final compact = !_isFullCinematicHero(context);
      final height = _cinematicHeroHeight(context, compact: compact) +
          (_heroHeightSyncDesktop ? _desktopTopBarBleed(context) : 0);
      if (ShellBus.homeHeroHeight.value != height) {
        ShellBus.homeHeroHeight.value = height;
      }
    });
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

  void _scrollHeroIntoView() {
    if (!_homeScrollController.hasClients) return;
    _homeScrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _focusHomeHeroGallery() {
    ShellTvFocusCoordinator.revealHeroForTab('home');
    ShellTvFocus.focusHomeHeroGallery();
  }

  void _focusHomeHeroMenu() {
    ShellTvFocusCoordinator.revealHeroForTab('home');
    ShellTvFocus.focusHomeMenu();
  }

  void _stepHeroFilm(int delta, List<Movie> movies) {
    if (movies.isEmpty) return;
    final count = movies.length;
    var next = (_heroIndex + delta) % count;
    if (next < 0) next += count;
    final instant = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    _goToHeroStep(next, movies, instant: instant);
  }

  void _revealedHeroPlayFocus() {
    void focusPlay() {
      if (!mounted) return;
      ShellTvFocus.focusHomeHeroPlay();
    }

    _scrollHeroIntoView();
    if (!_homeScrollController.hasClients) {
      focusPlay();
      return;
    }
    _homeScrollController
        .animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        )
        .whenComplete(focusPlay);
  }

  @override
  void initState() {
    super.initState();
    ShellTvFocus.homeHeroPlay = _tvHeroPlayFocus;
    ShellTvFocus.homeHeroGallery = _tvHeroGalleryFocus;
    ShellTvFocusCoordinator.registerTabDefaults(
      'home',
      defaultFocus: () => _tvHeroPlayFocus,
      heroReveal: _scrollHeroIntoView,
    );
    _homeScrollController.addListener(_syncHomeScrollOffset);
    _resetHomeCategoryFeeds(useBootCache: true);

    _startHeroTimer();
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

  void _startHeroTimer() {
    _heroTimer?.cancel();
    _heroTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
      if (!_heroController.hasClients) return;
      _heroController.nextPage(
        duration: const Duration(milliseconds: 1000),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _onHeroPageChanged(int pageIndex, List<Movie> movies) {
    if (movies.isEmpty) return;
    final count = movies.length;
    final realIndex = pageIndex % count;
    if (_heroIndex != realIndex) {
      setState(() => _heroIndex = realIndex);
    }

    if (pageIndex <= 2 || pageIndex >= _heroLoopLength - 3) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_heroController.hasClients) return;
        _heroController.jumpToPage(_heroLoopStart + realIndex);
      });
    }
  }

  void _goToHeroStep(
    int stepIndex,
    List<Movie> movies, {
    bool instant = false,
  }) {
    if (!_heroController.hasClients || movies.isEmpty) return;
    final count = movies.length;
    final currentPage = _heroController.page?.round() ?? _heroLoopStart;
    final currentReal = currentPage % count;
    if (currentReal == stepIndex) return;

    var delta = stepIndex - currentReal;
    if (delta > count ~/ 2) {
      delta -= count;
    } else if (delta < -count ~/ 2) {
      delta += count;
    }

    final targetPage = currentPage + delta;
    if (instant) {
      _heroController.jumpToPage(targetPage);
      return;
    }

    _heroController.animateToPage(
      targetPage,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildHeroStepIndicators(
    List<Movie> movies, {
    Axis axis = Axis.vertical,
  }) {
    const selectedColor = Colors.white;
    final unselectedColor = Colors.white.withValues(alpha: 0.25);

    final dots = List.generate(movies.length, (i) {
      final selected = i == _heroIndex;
      final isVertical = axis == Axis.vertical;
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => _goToHeroStep(i, movies),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: isVertical
                ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
                : const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              width: isVertical ? (selected ? 8.0 : 6.0) : (selected ? 28.0 : 8.0),
              height: isVertical ? (selected ? 24.0 : 6.0) : 3.0,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(isVertical ? 4 : 2),
                color: selected ? selectedColor : unselectedColor,
              ),
            ),
          ),
        ),
      );
    });

    if (axis == Axis.vertical) {
      return Column(mainAxisSize: MainAxisSize.min, children: dots);
    }
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: dots);
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

  Future<void> _fetchHeroLogos(List<Movie> movies) async {
    for (final movie in movies) {
      if (_heroLogos.containsKey(movie.id)) continue;
      try {
        final logoPath = await _api.getLogoPath(movie.id, mediaType: movie.mediaType);
        if (!mounted) return;
        setState(() {
          _heroLogos[movie.id] = logoPath.isNotEmpty
              ? TmdbApi.getImageUrl(logoPath)
              : '';
        });
      } catch (_) {}
    }
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
    ShellBus.homeHeroHeight.value = 0;
    if (ShellTvFocus.homeHeroPlay == _tvHeroPlayFocus) {
      ShellTvFocus.homeHeroPlay = null;
    }
    if (ShellTvFocus.homeHeroGallery == _tvHeroGalleryFocus) {
      ShellTvFocus.homeHeroGallery = null;
    }
    _heroTimer?.cancel();
    _heroController.dispose();
    _tvHeroPlayFocus.dispose();
    _tvHeroGalleryFocus.dispose();
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
    final fullHero = _isFullCinematicHero(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncHomeScrollOffset();
      _publishHomeHeroHeight(usesShellHome);
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
                  child: FutureBuilder<List<Movie>>(
                    future: _trendingFuture,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return _buildCinematicHeroShimmer(
                          compact: !fullHero,
                        );
                      }
                      return _buildCinematicHeroBlock(
                        snapshot.data!.take(5).toList(),
                        compact: !fullHero,
                      );
                    },
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
                    tvFocusUp: _revealedHeroPlayFocus,
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

  double _snapToDevicePixels(BuildContext context, double value) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return (value * dpr).round() / dpr;
  }

  double _cinematicHeroHeight(BuildContext context, {required bool compact}) {
    if (compact) {
      final screenH = MediaQuery.sizeOf(context).height;
      final target = screenH * ShellTokens.heroHeightFractionCompact;
      return _snapToDevicePixels(
        context,
        math.max(ShellTokens.heroMinHeightCompact, target),
      );
    }
    return _desktopHeroHeight(context);
  }

  double _desktopTopBarBleed(BuildContext context) =>
      MediaQuery.paddingOf(context).top;

  double _desktopHeroHeight(BuildContext context) {
    final screenH = MediaQuery.sizeOf(context).height;
    final topBar = _desktopTopBarBleed(context);
    final firstRowHeight =
        HomeMovieSection.sectionHeight(context, compactTop: true);
    final nextRowPeek = HomeMovieSection.sectionHeight(context) *
        shellHeroNextRowPeekFraction(context);
    final reservedBelow = shellHomeRowSpacing(context) +
        firstRowHeight +
        nextRowPeek;
    final target = screenH * shellHeroHeightFraction(context);
    final maxHero = screenH - topBar - reservedBelow;
    return _snapToDevicePixels(
      context,
      math.min(target, math.max(shellHeroMinHeight(context), maxHero)),
    );
  }

  Widget _buildCinematicHeroShimmer({required bool compact}) {
    final height = _cinematicHeroHeight(context, compact: compact) +
        _desktopTopBarBleed(context);
    return homeHubHeroShimmer(height: height);
  }

  Widget _buildCinematicHeroBlock(List<Movie> movies, {required bool compact}) {
    final heroMovie = movies[_heroIndex];
    final metrics = ShellScope.metricsOf(context);
    final policy = ShellScope.inputPolicyOf(context);
    if (policy.heroPlayAutoFocus && !_tvHeroInitialFocusDone) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _tvHeroInitialFocusDone) return;
        if (_tvHeroPlayFocus.canRequestFocus) {
          _tvHeroPlayFocus.requestFocus();
          _tvHeroInitialFocusDone = true;
        }
      });
    }
    final backdropHeight = _cinematicHeroHeight(context, compact: compact);
    final topBarBleed = _desktopTopBarBleed(context);
    final imageHeight =
        _snapToDevicePixels(context, backdropHeight + topBarBleed);
    final textTop = topBarBleed + _heroTextTopInset(context);
    final compactRightInset =
        compact ? metrics.heroCompactRightInset : 48.0;

    return SizedBox(
      height: imageHeight,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: imageHeight,
            child: _buildDesktopHeroBackdrop(
              movies,
              compact: compact,
            ),
          ),
          Positioned(
            left: shellHomeSectionHorizontalPadding(context),
            top: textTop,
            right: compact
                ? shellScaled(context, compactRightInset).clamp(12.0, compactRightInset)
                : shellScaled(context, 48).clamp(24.0, 48.0),
            bottom: shellScaled(context, 16).clamp(8.0, 16.0),
            child: compact
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      return ClipRect(
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: _buildCompactHeroTextColumn(
                            heroMovie,
                            metrics: metrics,
                            maxHeight: constraints.maxHeight,
                            maxWidth: constraints.maxWidth,
                          ),
                        ),
                      );
                    },
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return ClipRect(
                        child: Align(
                          alignment: Alignment(
                            -1,
                            ShellTokens.heroTextColumnVerticalAlign,
                          ),
                          child: SizedBox(
                            width: math.min(
                              MediaQuery.sizeOf(context).width * 0.34,
                              ShellTokens.heroTextColumnWidthDesktop,
                            ),
                            child: _buildDesktopHeroTextColumn(
                              heroMovie,
                              maxHeight: constraints.maxHeight,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Positioned(
            right: shellScaled(context, 20).clamp(10.0, 20.0),
            bottom: compact ? shellScaled(context, 16).clamp(8.0, 16.0) : null,
            top: compact ? null : 0,
            height: compact ? null : imageHeight,
            child: compact
                ? _buildHeroStepIndicators(movies, axis: Axis.horizontal)
                : Align(
                    alignment: Alignment.centerRight,
                    child: _buildHeroStepIndicators(movies),
                  ),
          ),
          if (policy.useFocusableMoodChips)
            Positioned(
              left: MediaQuery.sizeOf(context).width *
                  (compact
                      ? ShellTokens.heroImageStartFractionCompact
                      : ShellTokens.heroImageStartFraction),
              top: 0,
              right: 0,
              bottom: 0,
              child: _buildTvHeroGalleryFocus(movies),
            ),
        ],
      ),
    );
  }

  Widget _buildTvHeroGalleryFocus(List<Movie> movies) {
    return shellFocusableTap(
      context: context,
      focusNode: _tvHeroGalleryFocus,
      tvTabId: 'home',
      tvZone: ShellTvZone.hero,
      scaleOnFocus: 1,
      ensureVisibleMode: ShellTvEnsureVisibleMode.off,
      onLeftEdge: () => _stepHeroFilm(-1, movies),
      onRightEdge: () => _stepHeroFilm(1, movies),
      onUpEdge: _focusHomeHeroMenu,
      onDownEdge: _revealedHeroPlayFocus,
      onTap: movies.isEmpty ? null : () => _openDetails(movies[_heroIndex]),
      child: const SizedBox.expand(),
    );
  }

  Widget _buildCompactHeroTextColumn(
    Movie heroMovie, {
    required ShellMetrics metrics,
    double? maxHeight,
    double? maxWidth,
  }) {
    if (maxHeight != null && maxWidth != null) {
      final actionGap = shellHeroActionGap(context);
      final metaGap = shellHeroMetaGap(context);
      const actionRowHeight = 40.0;
      const metaRowHeight = 32.0;
      final titleHeight = (maxHeight -
              actionGap -
              metaGap -
              actionRowHeight -
              metaRowHeight)
          .clamp(40.0, ShellTokens.heroTitleSlotHeightCompact);

      return SizedBox(
        width: maxWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: titleHeight,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: _buildHeroTitleBlock(
                  heroMovie,
                  isLandscape: false,
                  desktop: true,
                  compact: true,
                ),
              ),
            ),
            SizedBox(height: metaGap),
            SizedBox(
              height: metaRowHeight,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _buildHeroMetaRow(heroMovie, singleLine: true),
              ),
            ),
            SizedBox(height: actionGap),
            _buildHeroActionRow(heroMovie),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeroTitleBlock(
          heroMovie,
          isLandscape: false,
          desktop: true,
          compact: true,
        ),
        SizedBox(height: shellHeroMetaGap(context)),
        _buildHeroMetaRow(heroMovie, singleLine: true),
        SizedBox(height: shellHeroActionGap(context)),
        _buildHeroActionRow(heroMovie),
      ],
    );
  }

  Widget _buildDesktopHeroImageGradients(
    Color shellBg, {
    required double imageStartFraction,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final fadeEnd = ShellTokens.heroImageGradientFadeEndFraction;
        final solidEnd = ShellTokens.heroImageGradientSolidEndFraction;
        final strip = 1.0 - imageStartFraction;
        final solidEndStop = imageStartFraction + strip * solidEnd;
        final fadeMid1 = imageStartFraction +
            strip * (solidEnd + (fadeEnd - solidEnd) * 0.31);
        final fadeMid2 = imageStartFraction +
            strip * (solidEnd + (fadeEnd - solidEnd) * 0.66);
        final fadeEndStop = imageStartFraction + strip * fadeEnd;

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        shellBg,
                        if (solidEnd > 0) shellBg,
                        shellBg.withValues(alpha: 0.72),
                        shellBg.withValues(alpha: 0.28),
                        Colors.transparent,
                      ],
                      stops: [
                        0.0,
                        imageStartFraction,
                        imageStartFraction,
                        if (solidEnd > 0) solidEndStop,
                        fadeMid1,
                        fadeMid2,
                        fadeEndStop,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: height * 0.55,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        shellBg.withValues(alpha: 0.45),
                        shellBg.withValues(alpha: 0.82),
                        shellBg,
                        shellBg,
                      ],
                      stops: const [0.0, 0.35, 0.68, 0.92, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDesktopHeroTextColumn(
    Movie heroMovie, {
    required double maxHeight,
  }) {
    const overviewStyle = TextStyle(
      fontSize: ShellTokens.heroOverviewFontSizeDesktop,
      height: ShellTokens.heroOverviewLineHeightDesktop,
      letterSpacing: 0.1,
      color: Color(0x99FFFFFF),
    );
    const titleGap = 20.0;
    const actionGap = 16.0;
    final minTitleHeight = ShellScope.metricsOf(context).heroMinTitleHeight;

    final baseWithoutOverview = titleGap +
        ShellTokens.heroMetaSlotHeightDesktop +
        actionGap +
        ShellTokens.shellButtonHeight;
    final overviewBlock = ShellTokens.heroMetaOverviewGapDesktop +
        ShellTokens.heroOverviewSlotHeightDesktop;

    var titleHeight = ShellTokens.heroTitleSlotHeightDesktop;
    final showOverview = heroMovie.overview.isNotEmpty &&
        titleHeight + baseWithoutOverview + overviewBlock <= maxHeight;

    if (!showOverview && titleHeight + baseWithoutOverview > maxHeight) {
      titleHeight = (maxHeight - baseWithoutOverview)
          .clamp(minTitleHeight, ShellTokens.heroTitleSlotHeightDesktop);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: titleHeight,
          child: Align(
            alignment: Alignment.bottomLeft,
            child: _buildHeroTitleBlock(
              heroMovie,
              isLandscape: false,
              desktop: true,
            ),
          ),
        ),
        const SizedBox(height: titleGap),
        SizedBox(
          height: ShellTokens.heroMetaSlotHeightDesktop,
          child: Align(
            alignment: Alignment.centerLeft,
            child: _buildHeroMetaRow(heroMovie, singleLine: true),
          ),
        ),
        if (showOverview) ...[
          SizedBox(height: ShellTokens.heroMetaOverviewGapDesktop),
          SizedBox(
            height: ShellTokens.heroOverviewSlotHeightDesktop,
            child: Align(
              alignment: Alignment.topLeft,
              child: HeroOverviewText(
                overview: heroMovie.overview,
                style: overviewStyle,
                maxLines: ShellTokens.heroOverviewMaxLinesDesktop,
                shrinkWrap: false,
                onReadMore: () => _openDetails(heroMovie),
              ),
            ),
          ),
        ],
        const SizedBox(height: actionGap),
        _buildHeroActionRow(heroMovie),
      ],
    );
  }

  Widget _buildDesktopHeroBackdrop(List<Movie> movies, {bool compact = false}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final shellBg = Theme.of(context).scaffoldBackgroundColor;
        final imageLeft = constraints.maxWidth *
            (compact
                ? ShellTokens.heroImageStartFractionCompact
                : ShellTokens.heroImageStartFraction);

        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: shellBg),
              Positioned(
                left: imageLeft,
                top: 0,
                right: 0,
                bottom: 0,
                child: PageView.builder(
                  clipBehavior: Clip.hardEdge,
                  controller: _heroController,
                  itemCount: _heroLoopLength,
                  onPageChanged: (i) => _onHeroPageChanged(i, movies),
                  itemBuilder: (context, index) {
                    final movie = movies[index % movies.length];
                    return CachedNetworkImage(
                      key: ValueKey(movie.id),
                      imageUrl: movie.backdropPath.isNotEmpty
                          ? TmdbApi.getBackdropUrl(movie.backdropPath)
                          : TmdbApi.getImageUrl(movie.posterPath),
                      fit: BoxFit.cover,
                      alignment: Alignment.centerRight,
                      filterQuality: FilterQuality.medium,
                      placeholder: (c, u) => ColoredBox(color: shellBg),
                      errorWidget: (c, u, e) => ColoredBox(color: shellBg),
                    );
                  },
                ),
              ),
              _buildDesktopHeroImageGradients(
                shellBg,
                imageStartFraction: compact
                    ? ShellTokens.heroImageStartFractionCompact
                    : ShellTokens.heroImageStartFraction,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeroTitleBlock(
    Movie heroMovie, {
    required bool isLandscape,
    bool desktop = false,
    bool compact = false,
  }) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.bottomLeft,
          clipBehavior: Clip.none,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: HeroTitle(
        key: ValueKey(heroMovie.id),
        movie: heroMovie,
        logoUrl: _heroLogos[heroMovie.id],
        style: HeroTitleStyle.home,
        isLandscape: isLandscape,
        desktop: desktop,
        compact: compact,
      ),
    );
  }

  Widget _buildHeroMediaTypeBadge(String label) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: shellScaled(context, 8).clamp(4.0, 8.0),
        vertical: shellScaled(context, 3).clamp(2.0, 3.0),
      ),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(shellScaled(context, 4).clamp(2.0, 4.0)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: shellScaled(context, 10).clamp(7.0, 10.0),
          fontWeight: FontWeight.bold,
          color: Colors.white60,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildHeroMetaRow(Movie heroMovie, {bool singleLine = false}) {
    final metaFont = shellScaled(context, 13).clamp(9.0, 13.0);
    final genreFont = shellScaled(context, 12).clamp(8.0, 12.0);
    final gap = shellScaled(context, 10).clamp(7.0, 10.0);
    final rating = Container(
      padding: EdgeInsets.symmetric(
        horizontal: shellScaled(context, 8).clamp(4.0, 8.0),
        vertical: shellScaled(context, 4).clamp(2.0, 4.0),
      ),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(shellScaled(context, 20).clamp(10.0, 20.0)),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_rounded,
            size: shellScaled(context, 14).clamp(10.0, 14.0),
            color: Colors.amber,
          ),
          SizedBox(width: shellScaled(context, 4).clamp(2.0, 4.0)),
          Text(
            heroMovie.voteAverage.toStringAsFixed(1),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.amber,
              fontSize: metaFont,
            ),
          ),
        ],
      ),
    );

    if (singleLine) {
      return Row(
        children: [
          Flexible(
            fit: FlexFit.loose,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                rating,
                if (heroMovie.releaseDate.isNotEmpty) ...[
                  SizedBox(width: gap),
                  Text(
                    heroMovie.releaseDate.split('-').first,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: metaFont,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (heroMovie.mediaType == 'tv') ...[
                  SizedBox(width: gap),
                  _buildHeroMediaTypeBadge('SERIES'),
                ] else if (heroMovie.mediaType == 'movie') ...[
                  SizedBox(width: gap),
                  _buildHeroMediaTypeBadge('FILM'),
                ],
              ],
            ),
          ),
          if (heroMovie.genres.isNotEmpty) ...[
            SizedBox(width: gap),
            Expanded(
              child: Text(
                heroMovie.genres.take(3).join('  ·  '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: genreFont,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 10,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          rating,
          if (heroMovie.releaseDate.isNotEmpty)
            Text(
              heroMovie.releaseDate.split('-').first,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          if (heroMovie.mediaType == 'tv')
            _buildHeroMediaTypeBadge('SERIES')
          else if (heroMovie.mediaType == 'movie')
            _buildHeroMediaTypeBadge('FILM'),
          if (heroMovie.genres.isNotEmpty)
            Text(
              heroMovie.genres.take(3).join('  ·  '),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeroActionRow(Movie heroMovie) {
    final metrics = ShellScope.metricsOf(context);
    final policy = ShellScope.inputPolicyOf(context);
    final tvNav = policy.useFocusableMoodChips;
    const heroItemCount = 3;
    final play = HeroPillPlayButton(
      label: 'Play',
      focusNode: policy.heroPlayAutoFocus ? _tvHeroPlayFocus : null,
      tvTabId: tvNav ? 'home' : null,
      tvRowId: tvNav ? MediaDetailsTv.heroRowId : null,
      tvItemIndex: tvNav ? 0 : null,
      onUpEdge: tvNav ? _focusHomeHeroGallery : null,
      onKeyEvent: policy.heroPlayAutoFocus
          ? (node, event) {
              if (!shellTvIsNavigationKey(event)) {
                return KeyEventResult.ignored;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                if (ShellTvFocusCoordinator.focusActiveNavTab()) {
                  return KeyEventResult.handled;
                }
              }
              return KeyEventResult.ignored;
            }
          : null,
      onTap: () => _watchNow(heroMovie),
    );
    final row = HeroPillActionRow(
      children: [
        if (tvNav)
          FocusTraversalOrder(order: const NumericFocusOrder(1), child: play)
        else
          play,
        const SizedBox(width: 10),
        HeroPillIconGroup(
          tvFocusOrderStart: tvNav ? 2 : null,
          tvTabId: tvNav ? 'home' : null,
          tvRowId: tvNav ? MediaDetailsTv.heroRowId : null,
          tvItemIndexStart: tvNav ? 1 : null,
          onUpEdge: tvNav ? _focusHomeHeroGallery : null,
          slots: [
            HeroPillIconSlot(
              icon: Icons.info_outline_rounded,
              tooltip: 'Details',
              onTap: () => _openDetails(heroMovie),
            ),
            MyListHeroPillButton.movieSlot(context, movie: heroMovie),
          ],
        ),
      ],
    );
    final body = metrics.heroActionUseFittedBox
        ? FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: row,
          )
        : row;
    if (!tvNav) return body;
    return DetailsHeroTvActionScope(
      tabId: 'home',
      itemCount: heroItemCount,
      onFocusUp: _focusHomeHeroGallery,
      child: body,
    );
  }
}
