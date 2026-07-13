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

mixin _HomeScreenBuild on State<HomeScreen> {
  _HomeScreenState get _s => this as _HomeScreenState;

  static const int _kGenreRowOrderBase = 21;

  List<Widget> _randomCategoryRowSlivers() => [
        for (var i = 0; i < _s._randomCategoryRows.length; i++)
          _homeRowSliver(
            HomeMovieSection(
              key: ValueKey(
                '${_s._randomCategoryRows[i].id}-${_s._homeFeedEpoch}',
              ),
              title: _s._randomCategoryRows[i].label,
              future: _s._randomCategoryRows[i].future,
              onMovieTap: _s._openDetails,
              tvRowId: 'genre-${_s._randomCategoryRows[i].id}',
              tvRowOrder: _kGenreRowOrderBase + i,
            ),
            isFirstAfterHero: false,
          ),
      ];
  @override
  Widget build(BuildContext context) {
    super.build(context);

    final usesShellHome = _usesShellHomeLayout(context);
    final fullHero = homeIsFullCinematicHero(context);
    final featuredSection = usesShellHome && fullHero
        ? HomeMovieSection(
            title: 'Featured This Month',
            future: _s._featuredThisMonthFuture,
            onMovieTap: _s._openDetails,
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
                    key: ValueKey(_s._homeFeedEpoch),
                    moviesFuture: _s._trendingFuture,
                    compact: !fullHero,
                    usesShellHomeLayout: usesShellHome,
                    scrollController: _s._homeScrollController,
                    controller: _s._homeHeroController,
                    onOpenDetails: _s._openDetails,
                    onWatchNow: _s._watchNow,
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
                  HomeMovieSection(
                    title: 'Featured This Month',
                    future: _s._featuredThisMonthFuture,
                    onMovieTap: _s._openDetails,
                  ),
                  isFirstAfterHero: false,
                ),

              if (usesShellHome)
                _homeRowSliver(
                  HomeMovieSection(
                    title: 'Popular',
                    future: _s._popularFuture,
                    onMovieTap: _s._openDetails,
                    showRank: true,
                    tvRowId: 'popular',
                    tvRowOrder: 1,
                  ),
                  isFirstAfterHero: featuredSection == null,
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
                  moods: _HomeScreenState._moods,
                  selectedId: _s._selectedMood,
                  onSelect: _s._selectMood,
                  future: _s._moodFuture,
                  onMovieTap: _s._openDetails,
                  compactTop: false,
                  tvRowOrder: 3,
                ),
                isFirstAfterHero: false,
              ),

              // "Because you watched ___" — BestSimilar.com recommendations
              // (the /recommendations endpoint, not the trash /similar one)
              if (_s._becauseSeed != null && _s._becauseFuture != null)
                _homeRowSliver(
                  HomeBecauseYouWatchedSection(
                    seedTitle: (_s._becauseSeed!['title'] as String?) ?? '',
                    seedPosterPath: (_s._becauseSeed!['posterPath'] as String?) ?? '',
                    future: _s._becauseFuture!,
                    onMovieTap: _s._openDetails,
                    // Only allow re-rolling when there's actually more than
                    // one in-progress show to choose between.
                    onShuffle: _s._becausePoolSize > 1 ? _s._shuffleBecauseSeed : null,
                  ),
                  isFirstAfterHero: false,
                ),

              if (!usesShellHome)
                _homeRowSliver(
                  HomeMovieSection(
                    title: 'Popular',
                    future: _s._popularFuture,
                    onMovieTap: _s._openDetails,
                    showRank: true,
                  ),
                  isFirstAfterHero: false,
                ),

              // Stremio Addon Catalogs
              if (_s._stremioCatalogsLoading && _s._stremioCatalogs.isEmpty)
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

              if (_s._catalogsLoaded || _s._stremioCatalogs.isNotEmpty)
                ..._s._stremioCatalogs.map((cat) {
                  final key = '${cat['addonBaseUrl']}/${cat['catalogType']}/${cat['catalogId']}';
                  final items = _s._catalogItems[key];
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
                      onItemTap: _s._openStremioItem,
                      onShowAll: () => _s._openStremioCatalog(cat),
                    ),
                    isFirstAfterHero: false,
                  );
                }),

              // Trakt Recommendations
              if (_s._traktRecsLoading)
                _homeRowSliver(
                  homeLoadingShimmer(
                    homeMovieRowSkeleton(context, titleWidth: 180),
                  ),
                  isFirstAfterHero: false,
                )
              else if (_s._traktRecommendations.isNotEmpty)
                _homeRowSliver(
                  HomeStaticMovieSection(
                    title: 'Recommended for You',
                    movies: _s._traktRecommendations,
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
                HomeMovieSection(
                  title: 'New Releases',
                  future: _s._nowPlayingFuture,
                  onMovieTap: _s._openDetails,
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
