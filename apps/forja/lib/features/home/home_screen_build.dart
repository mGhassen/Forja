part of 'home_screen.dart';

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

mixin _HomeScreenBuild on ConsumerState<HomeScreen> {
  _HomeScreenState get _s => this as _HomeScreenState;

  static const int _kGenreRowOrderBase = 41;
  static const int _kNewReleasesRowOrder = 40;

  void _listenHomeFeedSideEffects() {
    ref.listen(shellWatchProviderIdProvider, (prev, next) {
      if (prev != next) _s._onWatchProviderChanged();
    });
    ref.listen(shellHomeCategoryProvider, (prev, next) {
      if (prev != next) _s._onHomeCategoryChanged();
    });
    ref.listen(shellHomeGenreIdProvider, (prev, next) {
      if (prev != next) _s._onHomeGenreChanged();
    });
    ref.listen(homeCatalogHourBucketProvider, (prev, next) {
      if (prev != null && prev != next) {
        _s._onCatalogHourBucketChanged();
      }
    });
  }

  Map<String, List<Movie>> _claimHomeRailDisplays({
    required List<Movie> trending,
    required List<Movie> featured,
    required List<Movie> popular,
    required List<Movie> nowPlaying,
  }) {
    // Global Categories filter makes every TMDB rail the same discover soup —
    // exclusive claim starves lower rows. Each rail fills its own slots.
    if (ShellBus.homeSelectedGenreId.value != null) {
      return fillHomeRailsIndependently([
        HomeRailSpec(
          id: 'hero',
          pool: trending,
          cap: kHomeHeroClaimCount,
        ),
        HomeRailSpec(id: 'featured', pool: featured),
        HomeRailSpec(id: 'popular', pool: popular),
        HomeRailSpec(id: 'mood', pool: _s._moodPool ?? const []),
        HomeRailSpec(id: 'because', pool: _s._becausePool ?? const []),
        HomeRailSpec(id: 'trakt-recs', pool: _s._traktRecommendations),
        HomeRailSpec(id: 'trakt-shows', pool: _s._traktUpcomingShows),
        HomeRailSpec(id: 'trakt-movies', pool: _s._traktUpcomingMovies),
        HomeRailSpec(id: 'new-releases', pool: nowPlaying),
        for (final row in _s._randomCategoryRows)
          HomeRailSpec(
            id: 'genre-${row.id}',
            pool: row.pool ?? const [],
          ),
      ]);
    }

    return claimHomeRails([
      // Hero follows top-menu Films/TV/genre via filtered trending — not stripped
      // by Popular claim (Popular stays ranked; hero stays filter-true).
      HomeRailSpec(
        id: 'hero',
        pool: trending,
        cap: kHomeHeroClaimCount,
        mode: HomeRailClaimMode.overlayClaim,
      ),
      // Popular is today's ranked list — never strip / backfill from claim.
      HomeRailSpec(
        id: 'popular',
        pool: popular,
        mode: HomeRailClaimMode.overlayClaim,
      ),
      HomeRailSpec(id: 'featured', pool: featured),
      HomeRailSpec(
        id: 'mood',
        pool: _s._moodPool ?? const [],
        mode: HomeRailClaimMode.overlayClaim,
      ),
      HomeRailSpec(
        id: 'continue',
        keysOnly: homeContinueWatchingKeys(WatchHistoryService().current),
        mode: HomeRailClaimMode.overlayClaim,
      ),
      HomeRailSpec(id: 'because', pool: _s._becausePool ?? const []),
      HomeRailSpec(id: 'trakt-recs', pool: _s._traktRecommendations),
      HomeRailSpec(
        id: 'trakt-shows',
        pool: _s._traktUpcomingShows,
        mode: HomeRailClaimMode.overlayIgnore,
      ),
      HomeRailSpec(
        id: 'trakt-movies',
        pool: _s._traktUpcomingMovies,
        mode: HomeRailClaimMode.overlayIgnore,
      ),
      HomeRailSpec(id: 'new-releases', pool: nowPlaying),
      for (final row in _s._randomCategoryRows)
        HomeRailSpec(
          id: 'genre-${row.id}',
          pool: row.pool ?? const [],
        ),
    ]);
  }

  Widget _claimedRailSection({
    required String title,
    required AsyncValue<List<Movie>> async,
    required List<Movie> movies,
    required Future<List<Movie>> fallbackFuture,
    bool compactTop = false,
    bool showRank = false,
    VoidCallback? tvFocusUp,
    String? tvRowId,
    int tvRowOrder = 0,
  }) {
    final loading = async.isRefreshing || !async.hasValue;
    if (loading) {
      return HomeMovieSection(
        title: title,
        future: fallbackFuture,
        onMovieTap: _s._openDetails,
        compactTop: compactTop,
        showRank: showRank,
        tvFocusUp: tvFocusUp,
        tvRowId: tvRowId,
        tvRowOrder: tvRowOrder,
      );
    }
    if (movies.isEmpty) return const SizedBox.shrink();
    return HomeStaticMovieSection(
      title: title,
      movies: movies,
      onMovieTap: _s._openDetails,
      tvRowId: tvRowId,
      tvRowOrder: tvRowOrder,
      compactTop: compactTop,
      showRank: showRank,
      tvFocusUp: tvFocusUp,
    );
  }

  List<Widget> _randomCategoryRowSlivers(Map<String, List<Movie>> displays) => [
        for (var i = 0; i < _s._randomCategoryRows.length; i++)
          _homeRowSliver(
            () {
              final row = _s._randomCategoryRows[i];
              final claimed = displays['genre-${row.id}'] ?? const <Movie>[];
              if (row.pool == null) {
                return HomeMovieSection(
                  key: ValueKey('${row.id}-${_s._homeFeedEpoch}'),
                  title: row.label,
                  future: row.future,
                  onMovieTap: _s._openDetails,
                  tvRowId: 'genre-${row.id}',
                  tvRowOrder: _kGenreRowOrderBase + i,
                );
              }
              if (claimed.isEmpty) return const SizedBox.shrink();
              return HomeStaticMovieSection(
                key: ValueKey('${row.id}-${_s._homeFeedEpoch}-claimed'),
                title: row.label,
                movies: claimed,
                onMovieTap: _s._openDetails,
                tvRowId: 'genre-${row.id}',
                tvRowOrder: _kGenreRowOrderBase + i,
              );
            }(),
            isFirstAfterHero: false,
          ),
      ];

  @override
  Widget build(BuildContext context) {
    super.build(context);
    _s._syncMainRailFutures();
    _listenHomeFeedSideEffects();

    final trendingAsync = ref.watch(homeTrendingProvider);
    final featuredAsync = ref.watch(homeFeaturedProvider);
    final popularAsync = ref.watch(homePopularProvider);
    final nowPlayingAsync = ref.watch(homeNowPlayingProvider);

    final mediaFilter = ref.watch(shellHomeCategoryProvider);
    final genreId = ref.watch(shellHomeGenreIdProvider);
    final watchProviderId = ref.watch(shellWatchProviderIdProvider);
    final filterSig =
        '${mediaFilter?.name ?? 'all'}|${genreId ?? 'all'}|${watchProviderId ?? 'all'}';

    final displays = _claimHomeRailDisplays(
      trending: trendingAsync.isRefreshing
          ? const []
          : (trendingAsync.valueOrNull ?? const []),
      featured: featuredAsync.isRefreshing
          ? const []
          : (featuredAsync.valueOrNull ?? const []),
      popular: popularAsync.isRefreshing
          ? const []
          : (popularAsync.valueOrNull ?? const []),
      nowPlaying: nowPlayingAsync.isRefreshing
          ? const []
          : (nowPlayingAsync.valueOrNull ?? const []),
    );

    final usesShellHome = _usesShellHomeLayout(context);
    final fullHero = homeIsFullCinematicHero(context);
    final featuredMovies = displays['featured'] ?? const <Movie>[];
    final popularMovies = displays['popular'] ?? const <Movie>[];
    final newReleaseMovies = displays['new-releases'] ?? const <Movie>[];
    final moodMovies = displays['mood'] ?? const <Movie>[];
    final becauseMovies = displays['because'] ?? const <Movie>[];
    final traktRecMovies = displays['trakt-recs'] ?? const <Movie>[];

    // Remount + wait for the post-filter fetch. Never paint the previous
    // filter's trending while AsyncValue is still refreshing.
    // Hero slides must match top-menu Films/TV — filter again client-side.
    List<Movie> heroSlidesFrom(List<Movie> pool) {
      final filtered = switch (mediaFilter) {
        ShellHomeCategory.films =>
          pool.where((m) => m.mediaType == 'movie'),
        ShellHomeCategory.tvShows => pool.where(
            (m) => m.mediaType == 'tv' || m.mediaType == 'series',
          ),
        _ => pool,
      };
      return filtered.take(kHomeHeroClaimCount).toList();
    }

    final Future<List<Movie>> heroMoviesFuture;
    if (trendingAsync.isRefreshing || !trendingAsync.hasValue) {
      heroMoviesFuture = ref.read(homeTrendingProvider.future).then(heroSlidesFrom);
    } else {
      final hero = displays['hero'] ?? const <Movie>[];
      final slides = heroSlidesFrom(
        hero.isNotEmpty ? hero : trendingAsync.requireValue,
      );
      heroMoviesFuture = Future.value(slides);
    }

    final featuredSection = usesShellHome && fullHero
        ? _claimedRailSection(
            title: 'Featured This Month',
            async: featuredAsync,
            movies: featuredMovies,
            fallbackFuture: _s._featuredThisMonthFuture,
            compactTop: true,
            tvFocusUp: _s._homeHeroController.revealPlayFocus,
            tvRowId: 'featured',
            tvRowOrder: 0,
          )
        : null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _s._syncHomeScrollOffset();
    });

    final content = RefreshIndicator(
          onRefresh: () => (this as ShellTabRefresh<HomeScreen>).refreshIfStale(force: true),
          color: ForjaShellColors.sectionAccent,
          child: CustomScrollView(
            controller: _s._homeScrollController,
            scrollCacheExtent: ScrollCacheExtent.pixels(500),
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: RepaintBoundary(
                  child: HomeCinematicHero(
                    key: ValueKey('home-hero-$filterSig-${_s._homeFeedEpoch}'),
                    moviesFuture: heroMoviesFuture,
                    compact: !fullHero,
                    usesShellHomeLayout: usesShellHome,
                    scrollController: _s._homeScrollController,
                    controller: _s._homeHeroController,
                    onOpenDetails: _s._openDetails,
                    pageBottomChild: featuredSection,
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
                  _claimedRailSection(
                    title: 'Featured This Month',
                    async: featuredAsync,
                    movies: featuredMovies,
                    fallbackFuture: _s._featuredThisMonthFuture,
                  ),
                  isFirstAfterHero: false,
                ),

              // Narrow desktop (< full cinematic): Featured as a normal row.
              if (usesShellHome && !fullHero)
                _homeRowSliver(
                  _claimedRailSection(
                    title: 'Featured This Month',
                    async: featuredAsync,
                    movies: featuredMovies,
                    fallbackFuture: _s._featuredThisMonthFuture,
                    compactTop: true,
                    tvFocusUp: _s._homeHeroController.revealPlayFocus,
                    tvRowId: 'featured',
                    tvRowOrder: 0,
                  ),
                  isFirstAfterHero: true,
                ),

              if (usesShellHome)
                _homeRowSliver(
                  _claimedRailSection(
                    title: 'Popular',
                    async: popularAsync,
                    movies: popularMovies,
                    fallbackFuture: _s._popularFuture,
                    showRank: true,
                    // First catalog row under hero when Featured is embedded in
                    // the hero bleed - UP must reach Play, not stop on Featured.
                    tvFocusUp: featuredSection != null
                        ? _s._homeHeroController.revealPlayFocus
                        : null,
                    tvRowId: 'popular',
                    tvRowOrder: 1,
                  ),
                  isFirstAfterHero: featuredSection == null && fullHero,
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

              // Mood / Genre chips - interactive filter
              _homeRowSliver(
                HomeMoodSection(
                  key: ValueKey('mood-${_s._selectedMood}-${_s._moodReloadToken}'),
                  moods: _HomeScreenState._moods,
                  selectedId: _s._selectedMood,
                  onSelect: _s._selectMood,
                  future: _s._moodPool != null
                      ? Future<List<Movie>>.value(moodMovies)
                      : _s._moodFuture,
                  onMovieTap: _s._openDetails,
                  compactTop: false,
                  tvRowOrder: 3,
                ),
                isFirstAfterHero: false,
              ),

              // "Because you watched ___" - BestSimilar.com recommendations
              // (the /recommendations endpoint, not the trash /similar one)
              if (_s._becauseSeed != null && _s._becauseFuture != null)
                _homeRowSliver(
                  HomeBecauseYouWatchedSection(
                    seedTitle: (_s._becauseSeed!['title'] as String?) ?? '',
                    seedPosterPath: (_s._becauseSeed!['posterPath'] as String?) ?? '',
                    future: _s._becausePool != null
                        ? Future<List<Movie>>.value(becauseMovies)
                        : _s._becauseFuture!,
                    onMovieTap: _s._openDetails,
                    // Only allow re-rolling when there's actually more than
                    // one in-progress show to choose between.
                    onShuffle: _s._becausePoolSize > 1 ? _s._shuffleBecauseSeed : null,
                  ),
                  isFirstAfterHero: false,
                ),

              if (!usesShellHome)
                _homeRowSliver(
                  _claimedRailSection(
                    title: 'Popular',
                    async: popularAsync,
                    movies: popularMovies,
                    fallbackFuture: _s._popularFuture,
                    showRank: true,
                  ),
                  isFirstAfterHero: false,
                ),

              // Trakt Recommendations
              if (_s._traktRecsLoading)
                _homeRowSliver(
                  homeLoadingShimmer(
                    homeMovieRowSkeleton(context, titleWidth: 180),
                  ),
                  isFirstAfterHero: false,
                )
              else if (traktRecMovies.isNotEmpty)
                _homeRowSliver(
                  HomeStaticMovieSection(
                    title: 'Recommended for You',
                    movies: traktRecMovies,
                    onMovieTap: _s._openDetails,
                    tvRowId: 'trakt-recs',
                    tvRowOrder: 11,
                  ),
                  isFirstAfterHero: false,
                ),

              // Trakt Calendar
              if (_s._traktShowsLoading)
                _homeRowSliver(
                  homeLoadingShimmer(
                    homeMovieRowSkeleton(context, titleWidth: 170),
                  ),
                  isFirstAfterHero: false,
                )
              else if (_s._traktUpcomingShows.isNotEmpty)
                _homeRowSliver(
                  HomeStaticMovieSection(
                    title: 'Upcoming Schedule',
                    movies: _s._traktUpcomingShows,
                    onMovieTap: _s._openDetails,
                    tvRowId: 'trakt-shows',
                    tvRowOrder: 12,
                  ),
                  isFirstAfterHero: false,
                ),

              if (_s._traktMoviesLoading)
                _homeRowSliver(
                  homeLoadingShimmer(
                    homeMovieRowSkeleton(context, titleWidth: 160),
                  ),
                  isFirstAfterHero: false,
                )
              else if (_s._traktUpcomingMovies.isNotEmpty)
                _homeRowSliver(
                  HomeStaticMovieSection(
                    title: 'Upcoming Movies',
                    movies: _s._traktUpcomingMovies,
                    onMovieTap: _s._openDetails,
                    tvRowId: 'trakt-movies',
                    tvRowOrder: 13,
                  ),
                  isFirstAfterHero: false,
                ),

              // New Releases
              _homeRowSliver(
                _claimedRailSection(
                  title: 'New Releases',
                  async: nowPlayingAsync,
                  movies: newReleaseMovies,
                  fallbackFuture: _s._nowPlayingFuture,
                  tvRowId: 'new-releases',
                  tvRowOrder: _kNewReleasesRowOrder,
                ),
                isFirstAfterHero: false,
              ),

              ..._randomCategoryRowSlivers(displays),

              SliverToBoxAdapter(
                child: SizedBox(height: shellTvCatalogScrollBottomGap(context)),
              ),
            ],
          ),
        );

    if (!usesShellHome) {
      return TvFocusGraph(
        tabId: 'home',
        child: Stack(
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
        ),
      );
    }

    return TvFocusGraph(tabId: 'home', child: content);
  }
}
