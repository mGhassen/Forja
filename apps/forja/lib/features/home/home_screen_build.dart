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
    // Hourly catalog remount disabled for now.
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
    Future<List<Movie>> Function()? loadMore;
    final id = tvRowId;
    if (id != null &&
        (id == 'popular' || id == 'featured' || id == 'new-releases')) {
      loadMore = () => _s._loadMoreHomeRail(id);
    }
    // Cold start only — never skeleton on top-menu filter flips (keep cards).
    if (movies.isEmpty && !async.hasValue) {
      return HomeMovieSection(
        title: title,
        future: fallbackFuture,
        onMovieTap: _s._openDetails,
        compactTop: compactTop,
        showRank: showRank,
        tvFocusUp: tvFocusUp,
        tvRowId: tvRowId,
        tvRowOrder: tvRowOrder,
        loadMore: loadMore,
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
      loadMore: loadMore,
    );
  }

  List<Widget> _randomCategoryRowSlivers(Map<String, List<Movie>> displays) => [
        for (var i = 0; i < _s._randomCategoryRows.length; i++)
          _homeRowSliver(
            () {
              final row = _s._randomCategoryRows[i];
              final claimed = displays['genre-${row.id}'] ?? const <Movie>[];
              final railId = 'genre-${row.id}';
              if (row.pool == null) {
                return HomeMovieSection(
                  key: ValueKey(row.id),
                  title: row.label,
                  future: row.future,
                  onMovieTap: _s._openDetails,
                  tvRowId: railId,
                  tvRowOrder: _kGenreRowOrderBase + i,
                  loadMore: () => _s._loadMoreHomeRail(railId),
                );
              }
              if (claimed.isEmpty) return const SizedBox.shrink();
              return HomeStaticMovieSection(
                key: ValueKey('${row.id}-claimed'),
                title: row.label,
                movies: claimed,
                onMovieTap: _s._openDetails,
                tvRowId: railId,
                tvRowOrder: _kGenreRowOrderBase + i,
                loadMore: () => _s._loadMoreHomeRail(railId),
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

    // Watch filters so rails rebuild when top menu changes (providers refetch).
    ref.watch(shellHomeCategoryProvider);
    ref.watch(shellHomeGenreIdProvider);
    ref.watch(shellWatchProviderIdProvider);

    void remember(AsyncValue<List<Movie>> async, void Function(List<Movie>) save) {
      final v = async.valueOrNull;
      // Only commit settled data for the active filter — never while refreshing.
      if (v != null && v.isNotEmpty && !async.isLoading && !async.isRefreshing) {
        save(v);
      }
    }

    remember(trendingAsync, (v) => _s._railCacheTrending = v);
    remember(featuredAsync, (v) => _s._railCacheFeatured = v);
    remember(popularAsync, (v) => _s._railCachePopular = v);
    remember(nowPlayingAsync, (v) => _s._railCacheNowPlaying = v);

    List<Movie> poolOf(AsyncValue<List<Movie>> async, List<Movie> cache) {
      final v = async.valueOrNull;
      // Settled fetch for current filter — paint it.
      if (v != null &&
          v.isNotEmpty &&
          !async.isLoading &&
          !async.isRefreshing) {
        return v;
      }
      // Keep last painted row as-is while the new Films/TV/genre fetch runs.
      // Do NOT client-strip by the new filter (movie cache → TV = empty skeleton).
      if (cache.isNotEmpty) return cache;
      return v ?? const [];
    }

    // Keep last-good posters while providers reload for a new top-menu filter.
    final displays = _claimHomeRailDisplays(
      trending: poolOf(trendingAsync, _s._railCacheTrending),
      featured: poolOf(featuredAsync, _s._railCacheFeatured),
      popular: poolOf(popularAsync, _s._railCachePopular),
      nowPlaying: poolOf(nowPlayingAsync, _s._railCacheNowPlaying),
    );

    final usesShellHome = _usesShellHomeLayout(context);
    final fullHero = homeIsFullCinematicHero(context);
    final featuredMovies = displays['featured'] ?? const <Movie>[];
    final popularMovies = displays['popular'] ?? const <Movie>[];
    final newReleaseMovies = displays['new-releases'] ?? const <Movie>[];
    final moodMovies = displays['mood'] ?? const <Movie>[];
    final becauseMovies = displays['because'] ?? const <Movie>[];
    final traktRecMovies = displays['trakt-recs'] ?? const <Movie>[];

    // Hero: keep shell mounted (stable key). Only swap slide data when the
    // settled list actually changes — a new Future.value every build flashes shimmer.
    List<Movie> heroSlidesFrom(List<Movie> pool) {
      return pool.take(kHomeHeroClaimCount).toList();
    }

    final hero = displays['hero'] ?? const <Movie>[];
    final heroSource = poolOf(trendingAsync, _s._railCacheTrending);
    final heroSlides = heroSlidesFrom(
      hero.isNotEmpty ? hero : heroSource,
    );
    if (heroSlides.isNotEmpty) {
      final sig = heroSlides.map((m) => '${m.mediaType}:${m.id}').join(',');
      if (sig != _s._heroSlideSig) {
        _s._heroSlideSig = sig;
        _s._heroMoviesFuture = Future<List<Movie>>.value(List.of(heroSlides));
      }
    }
    final heroMoviesFuture = _s._heroMoviesFuture;

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
                    key: const ValueKey('home-hero'),
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
                    tvRowId: 'featured',
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
                  key: ValueKey('mood-${_s._selectedMood}'),
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
                    tvRowId: 'popular',
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
