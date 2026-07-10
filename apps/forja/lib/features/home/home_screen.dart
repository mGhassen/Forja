import 'dart:async';
import 'dart:convert';
import 'package:rust/rust.dart';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:forja/shared/widgets/home_loading_skeleton.dart';
import 'package:forja/shared/catalog/bestsimilar_scraper.dart';
import 'package:forja/shared/extractors/stream_extractor.dart';
import 'package:forja/shared/extractors/amri_extractor.dart';
import 'package:forja/shared/services/tracker/trakt_service.dart';
import 'package:forja/shared/services/tracker/simkl_service.dart';
import 'package:forja/shell/app_router.dart';
import 'package:forja/app/boot_cache.dart';
import 'package:forja/shell/home_top_bar.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shell/shell_tab_refresh.dart';
import 'package:forja/features/home/home_genre_categories.dart';
import 'package:forja/features/home/stremio_catalog_screen.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/widgets/home_movie_card.dart';
import 'package:forja/shared/widgets/my_list_button.dart';
import 'package:forja/shared/widgets/hero/hero_pill_buttons.dart';
import 'package:forja/shared/widgets/hero_overview_text.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';

double _homeSectionTitleTop(BuildContext context, {required bool compactTop}) {
  if (!compactTop) return ShellTokens.homeSectionTitleTop;
  return _usesShellHomeLayout(context)
      ? ShellTokens.homeSectionTitleTopCompactDesktop
      : ShellTokens.homeSectionTitleTopCompactMobile;
}

bool _usesShellHomeLayout(BuildContext context) {
  return ShellScope.profileOf(context) != ShellProfile.mobile;
}

bool _isFullCinematicHero(BuildContext context) {
  return MediaQuery.sizeOf(context).width >= ShellTokens.heroDesktopMinBodyWidth;
}

double _heroTextTopInset(BuildContext context) {
  return ShellTokens.heroTextColumnTopInsetDesktop;
}

SliverToBoxAdapter _homeRowSliver(
  Widget section, {
  required bool isFirstAfterHero,
}) {
  return SliverToBoxAdapter(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isFirstAfterHero)
          const SizedBox(height: ShellTokens.homeRowSpacing),
        RepaintBoundary(child: section),
      ],
    ),
  );
}

Widget _heroTitleText(
  Movie movie,
  bool isLandscape, {
  bool desktop = false,
  bool compact = false,
}) {
  final fontSize = compact
      ? 22.0
      : desktop
          ? 32.0
          : (isLandscape ? 48.0 : 36.0);
  return Text(
    movie.title,
    style: TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      color: Colors.white,
      height: 1.0,
      letterSpacing: -1.0,
      shadows: [
        const Shadow(color: Colors.black, blurRadius: 40),
        Shadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 80),
      ],
    ),
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
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
  bool _tvHeroInitialFocusDone = false;
  late Future<List<Movie>> _trendingFuture;
  late Future<List<Movie>> _popularFuture;
  late Future<List<Movie>> _featuredThisMonthFuture;
  late Future<List<Movie>> _nowPlayingFuture;

  List<({String label, Future<List<Movie>> future})> _randomCategoryRows = [];
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
    List<int> movieGenres,
    List<int> tvGenres,
  })> _moods = [
    (
      id: 'mind',
      label: 'Mind-Bending',
      icon: Icons.psychology_rounded,
      movieGenres: [878, 9648],
      tvGenres: [10765, 9648],
    ),
    (
      id: 'feel',
      label: 'Feel-Good',
      icon: Icons.wb_sunny_rounded,
      movieGenres: [35, 10751],
      tvGenres: [35, 10751],
    ),
    (
      id: 'dark',
      label: 'Dark Thrillers',
      icon: Icons.dark_mode_rounded,
      movieGenres: [53, 80],
      tvGenres: [80, 9648],
    ),
    (
      id: 'romance',
      label: 'Romance',
      icon: Icons.favorite_rounded,
      movieGenres: [10749],
      tvGenres: [18],
    ),
    (
      id: 'horror',
      label: 'Horror',
      icon: Icons.bedtime_rounded,
      movieGenres: [27],
      tvGenres: [10765, 9648],
    ),
    (
      id: 'action',
      label: 'Action',
      icon: Icons.local_fire_department_rounded,
      movieGenres: [28, 12],
      tvGenres: [10759],
    ),
    (
      id: 'animated',
      label: 'Animated',
      icon: Icons.brush_rounded,
      movieGenres: [16],
      tvGenres: [16],
    ),
    (
      id: 'drama',
      label: 'Drama',
      icon: Icons.theaters_rounded,
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
          label: category.label,
          future: _fetchCategoryRow(category),
        ),
    ];
  }

  List<Widget> _randomCategoryRowSlivers() => [
        for (final row in _randomCategoryRows)
          _homeRowSliver(
            _MovieSection(
              key: ValueKey('${row.label}-$_homeFeedEpoch'),
              title: row.label,
              future: row.future,
              onMovieTap: _openDetails,
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

  void _revealedHeroPlayFocus() {
    void focusPlay() {
      if (!mounted) return;
      ShellTvFocus.focusHomeHeroPlay();
    }

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
    final byShow = <int, Map<String, dynamic>>{};
    for (final item in history) {
      final pos = (item['position'] as int?) ?? 0;
      final dur = (item['duration'] as int?) ?? 0;
      if (dur <= 0) continue;
      final progress = pos / dur;
      if (progress < 0.02 || progress >= 0.9) continue;
      final tmdbId = item['tmdbId'] as int?;
      if (tmdbId == null) continue;
      final existing = byShow[tmdbId];
      final ts = (item['updatedAt'] as int?) ?? 0;
      final existingTs = (existing?['updatedAt'] as int?) ?? -1;
      if (ts > existingTs) byShow[tmdbId] = item;
    }
    return byShow.values.toList();
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

  void _goToHeroStep(int stepIndex, List<Movie> movies) {
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

    _heroController.animateToPage(
      currentPage + delta,
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
    _heroTimer?.cancel();
    _heroController.dispose();
    _tvHeroPlayFocus.dispose();
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
                  _ContinueWatchingSection(compactTop: true),
                  isFirstAfterHero: true,
                ),

              if (!usesShellHome)
                _homeRowSliver(
                  _MovieSection(
                    title: 'Featured This Month',
                    future: _featuredThisMonthFuture,
                    onMovieTap: _openDetails,
                  ),
                  isFirstAfterHero: false,
                ),

              if (usesShellHome)
                _homeRowSliver(
                  _MovieSection(
                    title: 'Featured This Month',
                    future: _featuredThisMonthFuture,
                    onMovieTap: _openDetails,
                    compactTop: true,
                    tvFocusUp: _revealedHeroPlayFocus,
                  ),
                  isFirstAfterHero: false,
                ),

              if (usesShellHome)
                _homeRowSliver(
                  _MovieSection(
                    title: 'Popular',
                    future: _popularFuture,
                    onMovieTap: _openDetails,
                    showRank: true,
                  ),
                  isFirstAfterHero: false,
                ),

              if (usesShellHome)
                _homeRowSliver(
                  const _ContinueWatchingSection(compactTop: false),
                  isFirstAfterHero: false,
                ),

              // Mood / Genre chips — interactive filter
              _homeRowSliver(
                _MoodSection(
                  moods: _moods,
                  selectedId: _selectedMood,
                  onSelect: _selectMood,
                  future: _moodFuture,
                  onMovieTap: _openDetails,
                  compactTop: false,
                ),
                isFirstAfterHero: false,
              ),

              // "Because you watched ___" — BestSimilar.com recommendations
              // (the /recommendations endpoint, not the trash /similar one)
              if (_becauseSeed != null && _becauseFuture != null)
                _homeRowSliver(
                  _BecauseYouWatchedSection(
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
                  _MovieSection(
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
                    _StremioCatalogSection(
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
                  _StaticMovieSection(title: 'Recommended for You', movies: _traktRecommendations, onMovieTap: _openDetails),
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
                  _StaticMovieSection(title: 'Upcoming Schedule', movies: _traktUpcomingShows, onMovieTap: _openDetails),
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
                  _StaticMovieSection(title: 'Upcoming Movies', movies: _traktUpcomingMovies, onMovieTap: _openDetails),
                  isFirstAfterHero: false,
                ),

              // New Releases
              _homeRowSliver(
                _MovieSection(title: 'New Releases', future: _nowPlayingFuture, onMovieTap: _openDetails),
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

  double _desktopTopBarBleed(BuildContext context) {
    return MediaQuery.paddingOf(context).top;
  }

  double _desktopHeroHeight(BuildContext context) {
    final screenH = MediaQuery.sizeOf(context).height;
    final topBar = _desktopTopBarBleed(context);
    final metrics = ShellScope.metricsOf(context);
    if (metrics.usesTvDensity) {
      return _snapToDevicePixels(
        context,
        screenH * ShellTokens.heroHeightFractionDesktop,
      );
    }
    final firstRowHeight =
        _MovieSection.sectionHeight(context, compactTop: true);
    final nextRowPeek = _MovieSection.sectionHeight(context) *
        ShellTokens.heroNextRowPeekFraction;
    final reservedBelow = ShellTokens.homeRowSpacing +
        firstRowHeight +
        nextRowPeek;
    final target = screenH * ShellTokens.heroHeightFractionDesktop;
    final maxHero = screenH - topBar - reservedBelow;
    return _snapToDevicePixels(
      context,
      math.min(target, math.max(320.0, maxHero)),
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
            left: ShellTokens.bodyHorizontalPadding,
            top: textTop,
            right: compactRightInset,
            bottom: 16,
            child: compact
                ? metrics.heroActionUseFittedBox
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
                    : _buildCompactHeroTextColumn(
                        heroMovie,
                        metrics: metrics,
                        maxHeight: null,
                        maxWidth: null,
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
            right: 20,
            bottom: compact ? 16 : null,
            top: compact ? null : 0,
            height: compact ? null : imageHeight,
            child: compact
                ? _buildHeroStepIndicators(movies, axis: Axis.horizontal)
                : Center(
                    child: _buildHeroStepIndicators(movies),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactHeroTextColumn(
    Movie heroMovie, {
    required ShellMetrics metrics,
    double? maxHeight,
    double? maxWidth,
  }) {
    if (metrics.heroActionUseFittedBox &&
        maxHeight != null &&
        maxWidth != null) {
      const actionGap = 12.0;
      const metaGap = 10.0;
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
            const SizedBox(height: metaGap),
            SizedBox(
              height: metaRowHeight,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _buildHeroMetaRow(heroMovie, singleLine: true),
              ),
            ),
            const SizedBox(height: actionGap),
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
        const SizedBox(height: 10),
        _buildHeroMetaRow(heroMovie, singleLine: true),
        const SizedBox(height: 12),
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
      child: _HeroTitleSlot(
        key: ValueKey(heroMovie.id),
        movie: heroMovie,
        logoUrl: _heroLogos[heroMovie.id],
        isLandscape: isLandscape,
        desktop: desktop,
        compact: compact,
      ),
    );
  }

  Widget _buildHeroMediaTypeBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white60,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildHeroMetaRow(Movie heroMovie, {bool singleLine = false}) {
    final rating = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
          const SizedBox(width: 4),
          Text(
            heroMovie.voteAverage.toStringAsFixed(1),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.amber,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );

    if (singleLine) {
      return Row(
        children: [
          rating,
          if (heroMovie.releaseDate.isNotEmpty) ...[
            const SizedBox(width: 10),
            Text(
              heroMovie.releaseDate.split('-').first,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (heroMovie.mediaType == 'tv') ...[
            const SizedBox(width: 10),
            _buildHeroMediaTypeBadge('SERIES'),
          ] else if (heroMovie.mediaType == 'movie') ...[
            const SizedBox(width: 10),
            _buildHeroMediaTypeBadge('FILM'),
          ],
          if (heroMovie.genres.isNotEmpty) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                heroMovie.genres.take(3).join('  ·  '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 12,
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
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        HeroPillPlayButton(
          label: 'Play',
          focusNode: policy.heroPlayAutoFocus ? _tvHeroPlayFocus : null,
          onKeyEvent: policy.heroPlayAutoFocus
              ? (node, event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.arrowUp) {
                    if (ShellTvFocus.focusHomeSearch()) {
                      return KeyEventResult.handled;
                    }
                  }
                  return KeyEventResult.ignored;
                }
              : null,
          onTap: () => _watchNow(heroMovie),
        ),
        const SizedBox(width: 10),
        HeroPillIconGroup(
          slots: [
            HeroPillIconSlot(
              icon: Icons.info_outline_rounded,
              tooltip: 'Details',
              onTap: () => _openDetails(heroMovie),
            ),
            HeroPillIconSlot(
              child: MyListButton.movie(
                movie: heroMovie,
                iconColor: Colors.white,
                iconColorActive: Colors.white,
                iconSize: 20,
                heroPillSlot: true,
              ),
              tooltip: 'Add to My List',
            ),
          ],
        ),
      ],
    );
    if (metrics.heroActionUseFittedBox) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: row,
      );
    }
    return row;
  }
}

class _MovieSection extends StatefulWidget {
  final String title;
  final Future<List<Movie>> future;
  final Function(Movie) onMovieTap;
  final bool compactTop;
  final bool showRank;
  final VoidCallback? tvFocusUp;

  const _MovieSection({
    super.key,
    required this.title,
    required this.future,
    required this.onMovieTap,
    this.compactTop = false,
    this.showRank = false,
    this.tvFocusUp,
  });

  static double sectionHeight(
    BuildContext context, {
    bool compactTop = false,
  }) {
    final top = compactTop
        ? ShellTokens.homeSectionTitleTopCompactDesktop
        : ShellTokens.homeSectionTitleTop;
    const headerRow = 28.0;
    const bottomGap = 16.0;
    return top + headerRow + bottomGap + HomeMovieCard.cardHeight(context);
  }

  @override
  State<_MovieSection> createState() => _MovieSectionState();
}

class _MovieSectionState extends State<_MovieSection> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Movie>>(
      future: widget.future,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final movies = snapshot.data ?? const <Movie>[];

        if (loading || movies.isEmpty) {
          if (loading || !snapshot.hasData) {
            return homeLoadingShimmer(
              homeMovieRowSkeleton(
                context,
                compactTop: widget.compactTop,
                titleWidth: widget.title.length > 12
                    ? 180
                    : widget.title.length * 11.0,
              ),
            );
          }
          return const SizedBox.shrink();
        }

        final sectionTop = _homeSectionTitleTop(
          context,
          compactTop: widget.compactTop,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ShellSectionTitle(
              title: widget.title,
              padding: EdgeInsets.fromLTRB(24, sectionTop, 24, 16),
            ),
            SizedBox(
              height: HomeMovieCard.cardHeight(context),
              child: ListView.separated(
                clipBehavior: Clip.none,
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: movies.length,
                separatorBuilder: (_, _) =>
                    SizedBox(width: widget.showRank ? 6 : 14),
                itemBuilder: (context, index) {
                  final policy = ShellScope.inputPolicyOf(context);
                  final tvNav = policy.useFocusableMoodChips;
                  return HomeMovieCard(
                    movie: movies[index],
                    onTap: () => widget.onMovieTap(movies[index]),
                    rank: widget.showRank ? index + 1 : null,
                    listIndex: index,
                    onUpEdge: tvNav && index == 0 ? widget.tvFocusUp : null,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StaticMovieSection extends StatefulWidget {
  final String title;
  final List<Movie> movies;
  final Function(Movie) onMovieTap;

  const _StaticMovieSection({
    required this.title,
    required this.movies,
    required this.onMovieTap,
  });

  @override
  State<_StaticMovieSection> createState() => _StaticMovieSectionState();
}

class _StaticMovieSectionState extends State<_StaticMovieSection> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.movies.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShellSectionTitle(title: widget.title),
        SizedBox(
          height: HomeMovieCard.cardHeight(context),
          child: ListView.separated(
            clipBehavior: Clip.none,
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: widget.movies.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) => HomeMovieCard(
              movie: widget.movies[index],
              onTap: () => widget.onMovieTap(widget.movies[index]),
              listIndex: index,
            ),
          ),
        ),
      ],
    );
  }
}

/// Rating badge for string ratings (Stremio).
Widget _buildRatingBadgeText(String rating) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, color: Colors.amber, size: 11),
        const SizedBox(width: 2),
        Text(rating, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    ),
  );
}

/// Resumes or replays a title from a watch-history entry (Continue Watching, hero Watch Now).
Future<void> resumePlaybackFromHistory(
  BuildContext context,
  Map<String, dynamic> item,
) async {
  try {
    final method = item['method'] as String;
    final tmdbId = item['tmdbId'] as int;
    final season = item['season'] as int?;
    final episode = item['episode'] as int?;
    final title = item['title'] as String;
    final posterPath = item['posterPath'] as String;
    final startPos = Duration(milliseconds: item['position'] as int);

    final isStreamingEntry = method == 'stream' || method == 'amri';
    if (isStreamingEntry) {
      if (context.mounted) {
        final mediaType =
            item['mediaType'] as String? ?? (season != null ? 'tv' : 'movie');
        final movie = Movie(
          id: tmdbId,
          title: title,
          posterPath: posterPath,
          backdropPath: '',
          overview: '',
          releaseDate: '',
          voteAverage: 0,
          mediaType: mediaType,
          genres: [],
          imdbId: item['imdbId'],
        );
        await AppRouter.openDetails(
          context,
          movie: movie,
          initialSeason: season,
          initialEpisode: episode,
          startPosition: startPos,
          autoPlay: true,
        );
      }
      return;
    }

    final savedMagnetLink = item['magnetLink'] as String?;
    final savedFileIndex = item['fileIndex'] as int?;

    String? streamUrl;
    String? activeProvider;
    String? magnetLink;
    int? fileIndex;
    String? stremioItemId;
    String? stremioAddonBase;

    if (method == 'stremio_direct') {
      stremioItemId = item['stremioId'] as String?;
      stremioAddonBase = item['stremioAddonBaseUrl'] as String?;

      if (context.mounted) {
        final mediaType =
            item['mediaType'] as String? ?? (season != null ? 'tv' : 'movie');
        final movie = Movie(
          id: tmdbId,
          title: title,
          posterPath: posterPath,
          backdropPath: '',
          overview: '',
          releaseDate: '',
          voteAverage: 0,
          mediaType: mediaType,
          genres: [],
          imdbId: item['imdbId'],
        );
        Map<String, dynamic>? stremioItem;
        if (stremioItemId != null) {
          stremioItem = {
            'id': stremioItemId,
            '_addonBaseUrl': stremioAddonBase ?? '',
            'type': item['stremioType'] ?? (season != null ? 'series' : 'movie'),
            'name': title,
          };
        }
        await AppRouter.openDetails(
          context,
          movie: movie,
          stremioItem: stremioItem,
          initialSeason: season,
          initialEpisode: episode,
          startPosition: startPos,
        );
      }
      return;
    } else if (method == 'stream') {
      final sourceId = item['sourceId'] as String;
      activeProvider = sourceId;

      if (sourceId == 'webstreamr') {
        debugPrint('[Resume] Using WebStreamrService for $title');
        final webStreamr = WebStreamrService();
        final imdbId = item['imdbId']?.toString() ?? '';
        if (imdbId.isNotEmpty) {
          final webStreamrSources = await webStreamr.getStreams(
            imdbId: imdbId,
            isMovie: season == null,
            season: season,
            episode: episode,
          );
          if (webStreamrSources.isNotEmpty) {
            streamUrl = webStreamrSources.first.url;
            if (context.mounted) {
              await AppRouter.openPlayer(
                context,
                streamUrl: streamUrl!,
                title: title,
                movie: Movie(
                  id: tmdbId,
                  title: title,
                  posterPath: posterPath,
                  backdropPath: '',
                  overview: '',
                  releaseDate: '',
                  voteAverage: 0,
                  mediaType: season != null ? 'tv' : 'movie',
                  genres: [],
                  imdbId: imdbId,
                ),
                selectedSeason: season,
                selectedEpisode: episode,
                activeProvider: 'webstreamr',
                startPosition: startPos,
                sources: webStreamrSources,
              );
              return;
            }
          }
        }
      }

      final provider = StreamProviders.providers[sourceId];
      if (provider == null) {
        throw Exception('Provider $sourceId not available');
      }

      debugPrint(
        '[Resume] Re-extracting stream for $title (TMDB: $tmdbId, S:$season, E:$episode)',
      );
      final url = season != null && episode != null
          ? provider['tv'](tmdbId, season, episode)
          : provider['movie'](tmdbId);

      final extractor = StreamExtractor();
      final result =
          await extractor.extract(url, timeout: const Duration(seconds: 20));
      streamUrl = result?.url;
    } else if (method == 'amri') {
      activeProvider = 'AMRI';
      debugPrint(
        '[Resume] Re-extracting AMRI for $title (TMDB: $tmdbId, S:$season, E:$episode)',
      );
      final amriExtractor = AmriExtractor(
        onLog: (message) => debugPrint('[AMRI Resume] $message'),
      );

      final year = item['year']?.toString() ?? '';

      final sourcesData = await amriExtractor.extractSources(
        tmdbId.toString(),
        title,
        year,
        season: season,
        episode: episode,
      );

      if (sourcesData['sources'] != null &&
          sourcesData['sources'].isNotEmpty) {
        final sources = sourcesData['sources'] as List;
        streamUrl = sources.first['url'] as String?;
      }
    } else if (method == 'torrent') {
      magnetLink = savedMagnetLink;
      fileIndex = savedFileIndex;

      if (magnetLink == null || magnetLink.isEmpty) {
        throw Exception('No magnet link saved for this torrent');
      }

      debugPrint('[Resume] Using saved magnet link: ${magnetLink.substring(0, 60)}...');
      debugPrint('[Resume] Using saved file index: $fileIndex');

      final useDebridSetting = await SettingsService().useDebridForStreams();
      final debridService = await SettingsService().getDebridService();
      final useDebrid = useDebridSetting && debridService != 'None';

      final playback = await resolveMagnetForPlayback(
        magnet: magnetLink,
        useDebrid: useDebrid,
        debridService: debridService,
        localTorrentEngine: PlatformPlayback.capabilities.localTorrentEngine,
        season: season,
        episode: episode,
        fileIdx: fileIndex,
      );
      if (playback != null) {
        streamUrl = playback.url;
        fileIndex = playback.fileIndex ?? fileIndex;
        debugPrint('[Resume] Resolved torrent playback URL');
      }
    } else if (method == 'trakt_import') {
      if (context.mounted) {
        final mediaType =
            item['mediaType'] as String? ?? (season != null ? 'tv' : 'movie');
        final movie = Movie(
          id: tmdbId,
          title: title,
          posterPath: posterPath,
          backdropPath: '',
          overview: '',
          releaseDate: '',
          voteAverage: 0,
          mediaType: mediaType,
          genres: [],
          imdbId: item['imdbId'],
        );
        await AppRouter.openDetails(
          context,
          movie: movie,
          initialSeason: season,
          initialEpisode: episode,
          startPosition: startPos,
        );
      }
      return;
    }

    if (streamUrl != null && context.mounted) {
      await AppRouter.openPlayer(
        context,
        streamUrl: streamUrl!,
        title: title,
        movie: Movie(
          id: tmdbId,
          title: title,
          posterPath: posterPath,
          backdropPath: '',
          overview: '',
          releaseDate: '',
          voteAverage: 0,
          mediaType: season != null ? 'tv' : 'movie',
          genres: [],
          imdbId: item['imdbId'],
        ),
        selectedSeason: season,
        selectedEpisode: episode,
        magnetLink: magnetLink,
        fileIndex: fileIndex,
        activeProvider: activeProvider,
        startPosition: startPos,
        stremioId: stremioItemId,
        stremioAddonBaseUrl: stremioAddonBase,
      );
    } else {
      if (context.mounted) {
        ForjaToast.error('Failed to load video');
      }
    }
  } catch (e) {
    debugPrint('[Resume] Error: $e');
    if (context.mounted) {
      ForjaToast.error('Error: $e');
    }
  }
}

class _ContinueWatchingSection extends StatefulWidget {
  final bool compactTop;

  const _ContinueWatchingSection({this.compactTop = false});

  @override
  State<_ContinueWatchingSection> createState() => _ContinueWatchingSectionState();
}

class _ContinueWatchingSectionState extends State<_ContinueWatchingSection> {
  final ScrollController _scrollController = ScrollController();
  String? _loadingItemId;
  final Map<int, String> _resolvedBackdrops = {};

  @override
  void initState() {
    super.initState();
    _resolveMissingBackdrops(WatchHistoryService().current);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _resolveMissingBackdrops(List<Map<String, dynamic>> items) async {
    for (final item in items) {
      final stored = item['backdropPath'] as String?;
      if (stored != null && stored.isNotEmpty) continue;

      final tmdbId = item['tmdbId'] as int?;
      if (tmdbId == null || _resolvedBackdrops.containsKey(tmdbId)) continue;

      final mediaType = item['mediaType']?.toString() ??
          (item['season'] != null ? 'tv' : 'movie');
      final type = (mediaType == 'tv' || mediaType == 'series') ? 'tv' : 'movie';

      try {
        final raw = await runTmdbGetJson('$type/$tmdbId');
        final data = jsonDecode(raw);
        if (data is Map<String, dynamic> && data['error'] == null) {
          final backdrop = data['backdrop_path']?.toString() ?? '';
          if (backdrop.isNotEmpty && mounted) {
            setState(() => _resolvedBackdrops[tmdbId] = backdrop);
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _resumePlayback(Map<String, dynamic> item) async {
    final uniqueId = item['uniqueId'] as String;
    if (_loadingItemId != null) return;

    setState(() => _loadingItemId = uniqueId);
    try {
      await resumePlaybackFromHistory(context, item);
    } finally {
      if (mounted) setState(() => _loadingItemId = null);
    }
  }

  Future<void> _removeItem(Map<String, dynamic> item) async {
    await WatchHistoryService().removeItem(item['uniqueId']);

    // Also remove from Trakt playback progress if logged in
    final tmdbId = item['tmdbId'] as int?;
    if (tmdbId != null) {
      final mediaType = item['mediaType']?.toString() ?? 'movie';
      final season = item['season'] as int?;
      final episode = item['episode'] as int?;
      await TraktService().removePlaybackProgress(
        tmdbId: tmdbId,
        mediaType: mediaType,
        season: season,
        episode: episode,
      );
    }
  }

  /// Opens the details page for a history item based on streaming mode and item type
  Future<void> _openHistoryItemDetails(Map<String, dynamic> item) async {
    final tmdbId = item['tmdbId'] as int;
    final title = item['title'] as String;
    final posterPath = item['posterPath'] as String;
    final season = item['season'] as int?;
    final episode = item['episode'] as int?;
    final mediaType = item['mediaType'] as String? ?? (season != null ? 'tv' : 'movie');
    
    final movie = Movie(
      id: tmdbId,
      title: title,
      posterPath: posterPath,
      backdropPath: '',
      overview: '',
      releaseDate: '',
      voteAverage: 0,
      mediaType: mediaType,
      genres: [],
      imdbId: item['imdbId'],
    );

    final stremioItemId = item['stremioId'] as String?;
    final stremioAddonBase = item['stremioAddonBaseUrl'] as String?;
    final isCustomId = stremioItemId != null &&
        stremioAddonBase != null &&
        !stremioItemId.startsWith('tt');

    Map<String, dynamic>? stremioItem;
    if (isCustomId) {
      stremioItem = {
        'id': stremioItemId,
        '_addonBaseUrl': stremioAddonBase,
        'type': item['stremioType'] ?? (season != null ? 'series' : 'movie'),
        'name': title,
      };
    }

    if (mounted) {
      await AppRouter.openDetails(
        context,
        movie: movie,
        stremioItem: stremioItem,
        initialSeason: season,
        initialEpisode: episode,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: WatchHistoryService().historyStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return homeContinueWatchingSkeleton(
            context,
            compactTop: widget.compactTop,
          );
        }
        if (snapshot.data!.isEmpty) return const SizedBox.shrink();
        final raw = snapshot.data!;
        if (_resolvedBackdrops.length < raw.length) {
          _resolveMissingBackdrops(raw);
        }
        // Deduplicate by tmdbId for shows — keep only the latest episode per show
        final seen = <dynamic>{};
        final history = <Map<String, dynamic>>[];
        for (final item in raw) {
          final key = (item['mediaType'] == 'tv' || item['season'] != null)
              ? item['tmdbId']
              : item['uniqueId'];
          if (seen.add(key)) history.add(item);
        }

        final titleTop = _homeSectionTitleTop(
          context,
          compactTop: widget.compactTop,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShellSectionTitle(
              title: 'Continue Watching',
              padding: EdgeInsets.fromLTRB(24, titleTop, 24, 16),
            ),
            SizedBox(
              height: _HistoryCard.cardHeight(context),
              child: ListView.separated(
                clipBehavior: Clip.none,
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: history.length,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final historyItem = history[index];
                  final itemId = historyItem['uniqueId'] as String;
                  return _HistoryCard(
                    item: historyItem,
                    resolvedBackdropPath:
                        _resolvedBackdrops[historyItem['tmdbId'] as int?],
                    onTap: () => _resumePlayback(historyItem),
                    onRemove: () => _removeItem(historyItem),
                    onInfo: () => _openHistoryItemDetails(historyItem),
                    isLoading: _loadingItemId == itemId,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HistoryCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final String? resolvedBackdropPath;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final VoidCallback onInfo;
  final bool isLoading;

  const _HistoryCard({
    required this.item,
    this.resolvedBackdropPath,
    required this.onTap,
    required this.onRemove,
    required this.onInfo,
    this.isLoading = false,
  });

  static double cardWidth(BuildContext context) {
    final isDesktop =
        MediaQuery.sizeOf(context).width > ShellTokens.musicDesktopBreakpoint;
    return isDesktop
        ? ShellTokens.shellContinueWatchingCardWidthDesktop
        : ShellTokens.shellContinueWatchingCardWidthCompact;
  }

  static double cardHeight(BuildContext context) {
    final isDesktop =
        MediaQuery.sizeOf(context).width > ShellTokens.musicDesktopBreakpoint;
    return isDesktop
        ? ShellTokens.shellContinueWatchingCardHeightDesktop
        : ShellTokens.shellContinueWatchingCardHeightCompact;
  }

  @override
  State<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<_HistoryCard> {
  bool _hovered = false;
  bool _focused = false;

  bool get _active => _hovered || _focused;

  @override
  Widget build(BuildContext context) {
    final posterPath = widget.item['posterPath'] as String;
    final storedBackdrop = widget.item['backdropPath'] as String?;
    final backdropPath = (storedBackdrop != null && storedBackdrop.isNotEmpty)
        ? storedBackdrop
        : widget.resolvedBackdropPath;
    final title = widget.item['title'] as String;
    final season = widget.item['season'] as int?;
    final episode = widget.item['episode'] as int?;
    final episodeTitle = widget.item['episodeTitle'] as String?;
    final position = widget.item['position'] as int;
    final duration = widget.item['duration'] as int;
    
    final progress = duration > 0 ? (position / duration).clamp(0.0, 1.0) : 0.0;
    final remaining = duration > 0 ? Duration(milliseconds: duration - position) : Duration.zero;
    final remainingText = remaining.inMinutes > 0 ? '${remaining.inMinutes}m left' : '';
    final imageUrl = _historyCardImageUrl(
      backdropPath: backdropPath,
      posterPath: posterPath,
    );
    
    final subtitle = season != null 
        ? 'S$season E$episode${episodeTitle != null && episodeTitle.isNotEmpty ? ' • $episodeTitle' : ''}'
        : '';

    final cardWidth = _HistoryCard.cardWidth(context);
    final cardHeight = _HistoryCard.cardHeight(context);

    return Focus(
      onFocusChange: (focused) => setState(() => _focused = focused),
      onKeyEvent: (node, event) {
        if (!widget.isLoading &&
            event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.select)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.isLoading ? null : widget.onTap,
          child: AnimatedScale(
            scale: _active ? 1.05 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: Container(
              width: cardWidth,
              height: cardHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
              ColoredBox(
                color: AppTheme.bgDark,
                child: imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.medium,
                        placeholder: (c, u) =>
                            ColoredBox(color: AppTheme.bgDark),
                      )
                    : const Icon(Icons.movie, color: Colors.white24, size: 40),
              ),
            
            // Dark overlay gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.3),
                    Colors.black.withValues(alpha: 0.85),
                    Colors.black.withValues(alpha: 0.95),
                  ],
                  stops: const [0.0, 0.3, 0.7, 1.0],
                ),
              ),
            ),

            // Top-right actions
            Positioned(
              top: 6, right: 6,
              child: Column(
                children: [
                  ForjaCloseButton(
                    size: 14,
                    hitSize: 28,
                    color: Colors.white70,
                    onTap: widget.onRemove,
                  ),
                  const SizedBox(height: 4),
                  Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      hoverColor: ForjaShellColors.inkHover,
                      splashColor: ForjaShellColors.inkSplash,
                      highlightColor: ForjaShellColors.inkSplash,
                      onTap: widget.onInfo,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.info_outline_rounded,
                          color: Colors.white70,
                          size: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom content: title + episode + progress
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, height: 1.2),
                        ),
                        if (subtitle.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                            ),
                          ),
                        if (remainingText.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              remainingText,
                              style: TextStyle(color: ForjaShellColors.badgeLabel, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Progress bar
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      color: ForjaShellColors.sectionAccent,
                      minHeight: 3,
                    ),
                  ),
                ],
              ),
            ),
            
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _active && !widget.isLoading ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            if (widget.isLoading)
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: CircularProgressIndicator(
                    color: ForjaShellColors.sectionAccent,
                  ),
                ),
              ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _historyCardImageUrl({
  String? backdropPath,
  required String posterPath,
}) {
  if (backdropPath != null && backdropPath.isNotEmpty) {
    return backdropPath.startsWith('http')
        ? backdropPath
        : TmdbApi.getBackdropUrl(backdropPath);
  }
  if (posterPath.isNotEmpty) {
    return posterPath.startsWith('http')
        ? posterPath
        : TmdbApi.getImageUrl(posterPath);
  }
  return '';
}

// ═══════════════════════════════════════════════════════════════════════════════
//  STREMIO ADDON CATALOG SECTION
// ═══════════════════════════════════════════════════════════════════════════════

class _StremioCatalogSection extends StatefulWidget {
  final Map<String, dynamic> catalog;
  final List<Map<String, dynamic>> items;
  final Function(Map<String, dynamic>) onItemTap;
  final VoidCallback onShowAll;

  const _StremioCatalogSection({
    required this.catalog,
    required this.items,
    required this.onItemTap,
    required this.onShowAll,
  });

  @override
  State<_StremioCatalogSection> createState() => _StremioCatalogSectionState();
}

class _StremioCatalogSectionState extends State<_StremioCatalogSection> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cat = widget.catalog;
    final addonName = cat['addonName'] as String;
    final catalogName = cat['catalogName'] as String;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 36, 24, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      catalogName,
                      style: ShellSectionTitle.titleStyle,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      addonName,
                      style: ShellSectionTitle.subtitleStyle(context),
                    ),
                  ],
                ),
              ),
              FocusableControl(
                onTap: widget.onShowAll,
                borderRadius: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.white.withValues(alpha: 0.08),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Show All', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios, size: 11, color: Colors.white.withValues(alpha: 0.6)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: HomeMovieCard.cardHeight(context),
          child: ListView.separated(
            clipBehavior: Clip.none,
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: widget.items.length.clamp(0, 20),
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final item = widget.items[index];
              return _StremioCatalogCard(
                item: item,
                listIndex: index,
                onTap: () => widget.onItemTap(item),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StremioCatalogCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final int? listIndex;
  final VoidCallback onTap;

  const _StremioCatalogCard({
    required this.item,
    required this.onTap,
    this.listIndex,
  });

  @override
  Widget build(BuildContext context) {
    final poster = item['poster']?.toString() ?? '';
    final name = item['name']?.toString() ?? 'Unknown';
    final rating = item['imdbRating']?.toString() ?? '';
    final cardWidth = HomeMovieCard.cardWidth(context);
    final cardHeight = HomeMovieCard.cardHeight(context);

    return FocusableControl(
      onTap: onTap,
      borderRadius: 14,
      scaleOnFocus: 1.05,
      onLeftEdge: shellTvNavLeftEdge(context, listIndex: listIndex ?? -1),
      child: Container(
        width: cardWidth,
        height: cardHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 16, offset: const Offset(0, 6)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: AppTheme.bgDark,
                child: poster.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: poster,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.medium,
                        placeholder: (_, _) =>
                            ColoredBox(color: AppTheme.bgDark),
                        errorWidget: (_, _, _) => Container(
                          color: AppTheme.bgDark,
                          child: Center(child: Text(name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.white38))),
                        ),
                      )
                    : Center(child: Text(name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.white38))),
              ),

            // Improved gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                    Colors.black.withValues(alpha: 0.95),
                  ],
                  stops: const [0.0, 0.4, 0.75, 1.0],
                ),
              ),
            ),

            // Rating badge — frosted glass
            if (rating.isNotEmpty)
              Positioned(
                top: 8, right: 8,
                child: _buildRatingBadgeText(rating),
              ),

            // Name
            Positioned(
              bottom: 10, left: 10, right: 10,
              child: Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, height: 1.2),
              ),
            ),

            // My List button
            Positioned(
              top: 8, left: 8,
              child: MyListButton.stremio(stremioItem: item),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════════
//  MOOD SECTION — chip filter + result row
// ═══════════════════════════════════════════════════════════════════════════════

class _MoodSection extends StatefulWidget {
  final List<({
    String id,
    String label,
    IconData icon,
    List<int> movieGenres,
    List<int> tvGenres,
  })> moods;
  final String selectedId;
  final ValueChanged<String> onSelect;
  final Future<List<Movie>>? future;
  final Function(Movie) onMovieTap;
  final bool compactTop;

  const _MoodSection({
    required this.moods,
    required this.selectedId,
    required this.onSelect,
    required this.future,
    required this.onMovieTap,
    this.compactTop = false,
  });

  @override
  State<_MoodSection> createState() => _MoodSectionState();
}

class _MoodSectionState extends State<_MoodSection> {
  final ScrollController _resultsCtrl = ScrollController();

  @override
  void dispose() {
    _resultsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final moods = widget.moods;
    final selectedId = widget.selectedId;
    final onSelect = widget.onSelect;
    final future = widget.future;
    final onMovieTap = widget.onMovieTap;
    final titleTop = _homeSectionTitleTop(
      context,
      compactTop: widget.compactTop,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(24, titleTop, 24, 12),
          child: const Text(
            "What's your mood?",
            style: ShellSectionTitle.titleStyle,
          ),
        ),
        // Chip strip
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: moods.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final m = moods[i];
              final isSelected = m.id == selectedId;
              final chip = Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? ForjaShellColors.chipSelectedBg
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isSelected
                        ? ForjaShellColors.chipSelectedBorder
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      m.icon,
                      size: 14,
                      color: isSelected
                          ? ForjaShellColors.chipSelectedIcon
                          : Colors.white.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      m.label,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.75),
                        fontSize: 12.5,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );

              if (ShellScope.inputPolicyOf(context).useFocusableMoodChips) {
                return FocusableControl(
                  onTap: () => onSelect(m.id),
                  borderRadius: 24,
                  onLeftEdge: shellTvNavLeftEdge(context, listIndex: i),
                  child: chip,
                );
              }

              return Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  hoverColor: ForjaShellColors.inkHover,
                  splashColor: ForjaShellColors.inkSplash,
                  highlightColor: ForjaShellColors.inkSplash,
                  onTap: () => onSelect(m.id),
                  child: chip,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        // Results row
        FutureBuilder<List<Movie>>(
          future: future,
          builder: (context, snap) {
            final loading =
                future == null || snap.connectionState == ConnectionState.waiting;
            final movies = snap.data ?? const <Movie>[];

            if (loading) {
              return homeLoadingShimmer(
                Padding(
                  padding: const EdgeInsets.only(top: 0),
                  child: SizedBox(
                    height: HomeMovieCard.cardHeight(context),
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: 5,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (_, _) => homeCardSkeleton(context),
                    ),
                  ),
                ),
              );
            }

            if (movies.isEmpty) {
              return SizedBox(
                height: 80,
                child: Center(
                  child: Text(
                    'No matches for this mood',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 13),
                  ),
                ),
              );
            }
            return SizedBox(
              height: HomeMovieCard.cardHeight(context),
              child: ListView.separated(
                clipBehavior: Clip.none,
                controller: _resultsCtrl,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: movies.length.clamp(0, 20),
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (context, i) => HomeMovieCard(
                  movie: movies[i],
                  onTap: () => onMovieTap(movies[i]),
                  listIndex: i,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  BECAUSE YOU WATCHED — BestSimilar.com recommendations seeded from CW history
// ═══════════════════════════════════════════════════════════════════════════════

class _BecauseYouWatchedSection extends StatefulWidget {
  final String seedTitle;
  final String seedPosterPath;
  final Future<List<Movie>> future;
  final Function(Movie) onMovieTap;
  final VoidCallback? onShuffle;

  const _BecauseYouWatchedSection({
    required this.seedTitle,
    required this.seedPosterPath,
    required this.future,
    required this.onMovieTap,
    required this.onShuffle,
  });

  @override
  State<_BecauseYouWatchedSection> createState() => _BecauseYouWatchedSectionState();
}

class _BecauseYouWatchedSectionState extends State<_BecauseYouWatchedSection> {
  final ScrollController _ctrl = ScrollController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _buildHeader() {
    final posterUrl = widget.seedPosterPath.isNotEmpty
        ? TmdbApi.getImageUrl(widget.seedPosterPath)
        : '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 50,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: AppTheme.bgCard,
              border: Border.all(
                color: ForjaShellColors.borderSubtle,
                width: 1.2,
              ),
            ),
            child: posterUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: posterUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Container(color: AppTheme.bgCard),
                    errorWidget: (_, _, _) => Container(color: AppTheme.bgCard),
                  )
                : const Icon(Icons.movie_outlined,
                    color: Colors.white38, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Because you watched',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.seedTitle.isEmpty ? 'recently' : widget.seedTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          if (widget.onShuffle != null)
            ForjaPlainIcon(
              icon: Icons.shuffle_rounded,
              tooltip: 'Pick a different show',
              onTap: widget.onShuffle,
            ),
        ],
      ),
    );
  }

  Widget _buildCardSkeletonRow() {
    return homeLoadingShimmer(
      Padding(
        padding: const EdgeInsets.only(top: 0),
        child: SizedBox(
          height: HomeMovieCard.cardHeight(context),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: 5,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (_, _) => homeCardSkeleton(context),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Movie>>(
      future: widget.future,
      builder: (context, snap) {
        final loading = snap.connectionState == ConnectionState.waiting;
        final movies = snap.data ?? const <Movie>[];

        if (!loading && movies.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            if (loading)
              _buildCardSkeletonRow()
            else
              SizedBox(
                height: HomeMovieCard.cardHeight(context),
                child: ListView.separated(
                  clipBehavior: Clip.none,
                  controller: _ctrl,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: movies.length.clamp(0, 25),
                  separatorBuilder: (_, _) => const SizedBox(width: 14),
                  itemBuilder: (context, i) => HomeMovieCard(
                    movie: movies[i],
                    onTap: () => widget.onMovieTap(movies[i]),
                    listIndex: i,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _HeroTitleSlot extends StatelessWidget {
  const _HeroTitleSlot({
    super.key,
    required this.movie,
    required this.logoUrl,
    required this.isLandscape,
    this.desktop = false,
    this.compact = false,
  });

  final Movie movie;
  final String? logoUrl;
  final bool isLandscape;
  final bool desktop;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bodyWidth = MediaQuery.sizeOf(context).width;
    final logoMaxHeight = compact
        ? ShellTokens.heroLogoMaxHeightCompact
        : desktop
            ? ShellTokens.heroLogoMaxHeightDesktop
            : (isLandscape ? 140.0 : 110.0);
    final maxWidth = compact
        ? bodyWidth * 0.72
        : desktop
            ? ShellTokens.heroTextColumnWidthDesktop
            : (isLandscape ? 420.0 : bodyWidth * 0.75);
    final slotHeight = compact
        ? ShellTokens.heroTitleSlotHeightCompact
        : desktop
            ? ShellTokens.heroTitleSlotHeightDesktop
            : logoMaxHeight + 14;
    final title = _heroTitleText(
      movie,
      isLandscape,
      desktop: desktop,
      compact: compact,
    );
    final hasLogo = logoUrl != null && logoUrl!.isNotEmpty;

    return SizedBox(
      height: compact ? null : slotHeight,
      width: maxWidth,
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: EdgeInsets.only(bottom: desktop || compact ? 0 : 14),
          child: ShellScope.profileOf(context) == ShellProfile.tv
              ? LayoutBuilder(
                  builder: (context, constraints) {
                    final resolvedWidth = compact && constraints.hasBoundedWidth
                        ? constraints.maxWidth
                        : maxWidth;
                    final resolvedLogoHeight = compact &&
                            constraints.hasBoundedHeight
                        ? math.min(logoMaxHeight, constraints.maxHeight)
                        : logoMaxHeight;
                    return SizedBox(
                      height: resolvedLogoHeight,
                      width: resolvedWidth,
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: hasLogo
                            ? CachedNetworkImage(
                                imageUrl: logoUrl!,
                                height: resolvedLogoHeight,
                                width: resolvedWidth,
                                fit: BoxFit.contain,
                                alignment: Alignment.centerLeft,
                                placeholder: (_, _) => title,
                                errorWidget: (_, _, _) => title,
                                fadeInDuration:
                                    const Duration(milliseconds: 250),
                                fadeOutDuration: Duration.zero,
                              )
                            : title,
                      ),
                    );
                  },
                )
              : SizedBox(
                  height: logoMaxHeight,
                  width: maxWidth,
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: hasLogo
                        ? CachedNetworkImage(
                            imageUrl: logoUrl!,
                            height: logoMaxHeight,
                            width: maxWidth,
                            fit: BoxFit.contain,
                            alignment: Alignment.centerLeft,
                            placeholder: (_, _) => title,
                            errorWidget: (_, _, _) => title,
                            fadeInDuration: const Duration(milliseconds: 250),
                            fadeOutDuration: Duration.zero,
                          )
                        : title,
                  ),
                ),
        ),
      ),
    );
  }
}
