part of 'anime_screen.dart';

mixin _AnimeScreenBuild on State<AnimeScreen> {
  _AnimeScreenState get _s => this as _AnimeScreenState;

  /// TV D-pad order must match visual stack.
  /// Full hero: Trending (bleed) → Continue → vibe → catalog.
  /// Narrow/mobile: Continue → vibe → Trending → catalog.
  int _moodChipsOrder({required bool trendingOnHero}) {
    var order = 0;
    if (trendingOnHero) order += 1;
    if (_s._continueWatching.isNotEmpty) order += 1;
    return order;
  }

  int _moodResultsOrder({required bool trendingOnHero}) =>
      _moodChipsOrder(trendingOnHero: trendingOnHero) + 1;

  /// First catalog row after mood results (excludes hero-bleed Trending).
  int _catalogRowBase({required bool trendingOnHero}) =>
      _moodResultsOrder(trendingOnHero: trendingOnHero) + 1;
  List<HubHeroSlide> _heroSlides(List<AnimeCard> spotlight) {
    return spotlight
        .map(
          (a) {
            final useTmdb = a.tmdbBackdropUrl != null;
            final useAniBanner = !useTmdb && a.bannerImage != null;
            return HubHeroSlide(
              id: '${a.id}',
              title: a.displayTitle,
              imageUrl: a.heroBackdrop,
              overview: a.cleanDescription,
              rating: (a.averageScore ?? 0) > 0 ? (a.averageScore! / 10) : null,
              year: a.seasonYear?.toString(),
              badge: a.format,
              genres: a.genres,
              // TMDB backdrops are cinematic 16:9. AniList banners are
              // ultrawide (~1900×400) — fit width so the tall page-bleed
              // hero does not crop to a tight zoom.
              imageFit: useAniBanner ? BoxFit.fitWidth : BoxFit.cover,
              imageAlignment:
                  useAniBanner ? Alignment.center : Alignment.centerRight,
              onPlay: () => _s._openDetails(a),
              onDetails: () => _s._openDetails(a),
            );
          },
        )
        .toList();
  }

  HubPosterCard _animePosterCard(
    AnimeCard anime, {
    int? rank,
    int? listIndex,
    String? tvRowId,
    VoidCallback? onUpEdge,
  }) {
    final subtitle = [
      if (anime.seasonYear != null) '${anime.seasonYear}',
      if (anime.episodes != null) '${anime.episodes} eps',
    ].join(' · ');

    return HubPosterCard(
      imageUrl: anime.coverUrl,
      title: anime.displayTitle,
      subtitle: subtitle.isEmpty ? null : subtitle,
      rating: (anime.averageScore ?? 0) > 0 ? (anime.averageScore! / 10) : null,
      badge: anime.format,
      rank: rank,
      listIndex: listIndex,
      tvTabId: 'anime',
      tvRowId: tvRowId,
      onUpEdge: onUpEdge,
      onTap: () => _s._openDetails(anime),
    );
  }

  // ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ValueListenableBuilder<AppThemePreset>(
      valueListenable: AppTheme.themeNotifier,
      builder: (context, _, _) {
        final fullHero = hubIsFullCinematicHero(context);
        final usesShell = hubUsesShellLayout(context);
        final trendingOnHero = usesShell && fullHero;
        final moodChipsOrder = _moodChipsOrder(trendingOnHero: trendingOnHero);
        final moodResultsOrder =
            _moodResultsOrder(trendingOnHero: trendingOnHero);
        final catalogBase = _catalogRowBase(trendingOnHero: trendingOnHero);
        // Bleed Trending owns 0; otherwise Trending is the first catalog row.
        final trendingOrder = trendingOnHero ? 0 : catalogBase;
        final catalogStart = trendingOnHero ? catalogBase : catalogBase + 1;
        void focusHeroPlay() {
          ShellTvFocusCoordinator.revealHeroForTab('anime');
          ShellTvFocus.focusHomeHeroPlay();
        }

        final trendingSection = trendingOnHero
            ? HubCatalogSection<AnimeCard>(
                title: 'Trending Now',
                future: _s._trendingFuture,
                compactTop: true,
                tvTabId: 'anime',
                tvRowId: 'trending',
                tvRowOrder: trendingOrder,
                tvFocusUp: focusHeroPlay,
                cardBuilder: (context, anime, index) => _animePosterCard(
                  anime,
                  listIndex: index,
                  tvRowId: 'trending',
                ),
              )
            : null;

        return _s._error != null && _s._catalogResolved
              ? _buildError()
              : RefreshIndicator(
                          color: ForjaShellColors.sectionAccent,
                          backgroundColor: AppTheme.bgCard,
                          onRefresh: _s._load,
                          child: ColoredBox(
                            color: AppTheme.bgDark,
                            child: CustomScrollView(
                            controller: _s._scroll,
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            slivers: [
                              SliverToBoxAdapter(
                                child: FutureBuilder<List<AnimeCard>>(
                                  future: _s._spotlightFuture,
                                  builder: (context, snap) {
                                    if (snap.connectionState ==
                                            ConnectionState.waiting ||
                                        !snap.hasData ||
                                        snap.data!.isEmpty) {
                                      return homeCinematicHeroShimmer(
                                        context,
                                        pageBottomBleed: trendingOnHero,
                                      );
                                    }
                                    return HubCinematicHero(
                                      slides: _heroSlides(
                                        snap.data!.take(5).toList(),
                                      ),
                                      onSearch: _s._openSearch,
                                      tvTabId: 'anime',
                                      pageBottomChild: trendingSection,
                                    );
                                  },
                                ),
                              ),
                              if (_s._continueWatching.isNotEmpty)
                                hubRowSliver(context,
                                  _buildContinueWatching(
                                    tvRowOrder: trendingOnHero ? 1 : 0,
                                    // Under bleed Trending: ↑ goes to Trending.
                                    // Otherwise Continue is first → hero Play.
                                    tvFocusUp:
                                        trendingOnHero ? null : focusHeroPlay,
                                  ),
                                  isFirstAfterHero: trendingSection == null,
                                )
                              else if (!_s._historyResolved)
                                hubRowSliver(context,
                                  homeContinueWatchingSkeleton(context),
                                  isFirstAfterHero: trendingSection == null,
                                ),
                              hubRowSliver(
                                context,
                                _buildMoodChips(
                                  chipsOrder: moodChipsOrder,
                                  resultsOrder: moodResultsOrder,
                                ),
                                isFirstAfterHero: false,
                              ),
                              if (trendingSection == null)
                                hubRowSliver(context,
                                  HubCatalogSection<AnimeCard>(
                                    title: 'Trending Now',
                                    future: _s._trendingFuture,
                                    tvTabId: 'anime',
                                    tvRowId: 'trending',
                                    tvRowOrder: trendingOrder,
                                    // Mood/Continue sit above — don't skip to hero.
                                    cardBuilder: (context, anime, index) =>
                                        _animePosterCard(
                                      anime,
                                      listIndex: index,
                                      tvRowId: 'trending',
                                    ),
                                  ),
                                  isFirstAfterHero: false,
                                ),
                              hubRowSliver(context,
                                HubCatalogSection<AnimeCard>(
                                  title: 'Top Airing',
                                  future: _s._topAiringFuture,
                                  tvTabId: 'anime',
                                  tvRowId: 'top-airing',
                                  tvRowOrder: catalogStart + 0,
                                  cardBuilder: (context, anime, index) =>
                                      _animePosterCard(
                                    anime,
                                    listIndex: index,
                                    tvRowId: 'top-airing',
                                  ),
                                ),
                                isFirstAfterHero: false,
                              ),
                              hubRowSliver(context,
                                HubCatalogSection<AnimeCard>(
                                  title: 'Top 10 Today',
                                  future: _s._top10Future,
                                  showRank: true,
                                  tvTabId: 'anime',
                                  tvRowId: 'top-10',
                                  tvRowOrder: catalogStart + 1,
                                  cardBuilder: (context, anime, index) =>
                                      _animePosterCard(
                                    anime,
                                    rank: index + 1,
                                    listIndex: index,
                                    tvRowId: 'top-10',
                                  ),
                                ),
                                isFirstAfterHero: false,
                              ),
                              hubRowSliver(context,
                                HubCatalogSection<AnimeCard>(
                                  title: 'Most Popular',
                                  future: _s._mostPopularFuture,
                                  tvTabId: 'anime',
                                  tvRowId: 'most-popular',
                                  tvRowOrder: catalogStart + 2,
                                  cardBuilder: (context, anime, index) =>
                                      _animePosterCard(
                                    anime,
                                    listIndex: index,
                                    tvRowId: 'most-popular',
                                  ),
                                ),
                                isFirstAfterHero: false,
                              ),
                              hubRowSliver(context,
                                HubCatalogSection<AnimeCard>(
                                  title: 'Latest Episodes',
                                  future: _s._recentEpisodesFuture,
                                  tvTabId: 'anime',
                                  tvRowId: 'latest-eps',
                                  tvRowOrder: catalogStart + 3,
                                  cardBuilder: (context, anime, index) =>
                                      _animePosterCard(
                                    anime,
                                    listIndex: index,
                                    tvRowId: 'latest-eps',
                                  ),
                                ),
                                isFirstAfterHero: false,
                              ),
                              hubRowSliver(context,
                                HubCatalogSection<AnimeCard>(
                                  title: 'Top Rated',
                                  future: _s._topRatedFuture,
                                  tvTabId: 'anime',
                                  tvRowId: 'top-rated',
                                  tvRowOrder: catalogStart + 4,
                                  cardBuilder: (context, anime, index) =>
                                      _animePosterCard(
                                    anime,
                                    listIndex: index,
                                    tvRowId: 'top-rated',
                                  ),
                                ),
                                isFirstAfterHero: false,
                              ),
                              hubRowSliver(context,
                                HubCatalogSection<AnimeCard>(
                                  title: 'Most Favorited',
                                  future: _s._mostFavoriteFuture,
                                  tvTabId: 'anime',
                                  tvRowId: 'most-favorited',
                                  tvRowOrder: catalogStart + 5,
                                  cardBuilder: (context, anime, index) =>
                                      _animePosterCard(
                                    anime,
                                    listIndex: index,
                                    tvRowId: 'most-favorited',
                                  ),
                                ),
                                isFirstAfterHero: false,
                              ),
                              hubRowSliver(context,
                                HubCatalogSection<AnimeCard>(
                                  title: 'Recently Completed',
                                  future: _s._latestCompletedFuture,
                                  tvTabId: 'anime',
                                  tvRowId: 'recently-completed',
                                  tvRowOrder: catalogStart + 6,
                                  cardBuilder: (context, anime, index) =>
                                      _animePosterCard(
                                    anime,
                                    listIndex: index,
                                    tvRowId: 'recently-completed',
                                  ),
                                ),
                                isFirstAfterHero: false,
                              ),
                              const SliverToBoxAdapter(
                                child: SizedBox(height: 80),
                              ),
                            ],
                          ),
                          ),
                        );
      },
    );
  }

  // ─── Continue watching ─────────────────────────────────────────
  Widget _buildContinueWatching({
    required int tvRowOrder,
    VoidCallback? tvFocusUp,
  }) {
    return AnimeContinueWatchingSection(
      entries: _s._continueWatching,
      scrollController: _s._cwScrollController,
      resumingAnimeId: _s._resumingAnimeId,
      onResume: _s._resumeWatch,
      onRemove: _s._removeFromHistory,
      onOpenDetails: _s._openDetails,
      tvRowOrder: tvRowOrder,
      tvFocusUp: tvFocusUp,
    );
  }

  // ─── Mood chips ────────────────────────────────────────────────
  Widget _buildMoodChips({
    required int chipsOrder,
    required int resultsOrder,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShellSectionTitle(
          title: 'Pick your vibe',
          padding: const EdgeInsets.fromLTRB(
            24,
            ShellTokens.homeSectionTitleTop,
            24,
            16,
          ),
        ),
        SizedBox(
          height: 40,
          child: Builder(
            builder: (context) {
              shellTvRegisterRow(
                tabId: 'anime',
                rowId: 'mood-chips',
                sortOrder: chipsOrder,
                itemCount: _AnimeScreenState._moods.length,
              );
              return FocusTraversalGroup(
                policy: OrderedTraversalPolicy(),
                child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: shellHomeSectionHorizontalPadding(context),
            ),
            itemCount: _AnimeScreenState._moods.length,
            separatorBuilder: (_, _) =>
                SizedBox(width: shellScaled(context, 8).clamp(4.0, 8.0)),
            itemBuilder: (_, i) {
              final m = _AnimeScreenState._moods[i];
              final selected = m.id == _s._selectedMood;
              return ForjaShellChip(
                label: m.label,
                selected: selected,
                icon: m.icon,
                listIndex: i,
                tvTabId: 'anime',
                tvRowId: 'mood-chips',
                onTap: () {
                  if (m.id != _s._selectedMood) {
                    _s._selectMood(m.id);
                  } else {
                    ShellTvFocusCoordinator.focusFromChipStripDown(
                      tabId: 'anime',
                      chipRowId: 'mood-chips',
                      resultsRowId: 'mood-results',
                    );
                  }
                },
                onLeftEdge: shellTvChipLeftEdge(
                  context,
                  tabId: 'anime',
                  rowId: 'mood-chips',
                  index: i,
                ),
                onRightEdge: shellTvChipRightEdge(
                  tabId: 'anime',
                  rowId: 'mood-chips',
                  index: i,
                  itemCount: _AnimeScreenState._moods.length,
                ),
                onDownEdge: shellTvChipDownToRow(
                  tabId: 'anime',
                  chipRowId: 'mood-chips',
                  resultsRowId: 'mood-results',
                ),
                onUpEdge: () {
                  ShellTvFocusCoordinator.moveVerticalInTab(
                    tabId: 'anime',
                    rowId: 'mood-chips',
                    currentIndex: i,
                    down: false,
                  );
                },
              );
            },
          ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        _buildMoodSection(resultsOrder: resultsOrder),
      ],
    );
  }

  Widget _buildMoodSection({required int resultsOrder}) {
    final future = _s._moodFuture;
    if (future == null) return const SizedBox.shrink();

    return FutureBuilder<List<AnimeCard>>(
      future: future,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final list = snapshot.data ?? <AnimeCard>[];

        if (loading || list.isEmpty) {
          shellTvUnregisterRow(tabId: 'anime', rowId: 'mood-results');
          if (loading || !snapshot.hasData) {
            return homeLoadingShimmer(
              SizedBox(
                height: HubPosterCard.cardHeight(context),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: shellHomeSectionHorizontalPadding(context),
                  ),
                  itemCount: 5,
                  separatorBuilder: (_, _) =>
                      SizedBox(width: shellMovieCardRowGap(context)),
                  itemBuilder: (_, _) => homeCardSkeleton(context),
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        }

        return SizedBox(
          height: HubPosterCard.cardHeight(context),
          child: Builder(
            builder: (context) {
              shellTvRegisterRow(
                tabId: 'anime',
                rowId: 'mood-results',
                sortOrder: resultsOrder,
                itemCount: list.length,
              );
              return FocusTraversalGroup(
                policy: OrderedTraversalPolicy(),
                child: ListView.separated(
                  clipBehavior: Clip.none,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: shellHomeSectionHorizontalPadding(context),
                  ),
                  itemCount: list.length,
                  separatorBuilder: (_, _) =>
                      SizedBox(width: shellMovieCardRowGap(context)),
                  itemBuilder: (context, index) => _animePosterCard(
                    list[index],
                    listIndex: index,
                    tvRowId: 'mood-results',
                    onUpEdge: shellTvResultsUpToChips(
                      tabId: 'anime',
                      chipRowId: 'mood-chips',
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildError() {
    return ShellErrorRetryPanel(
      message: _s._error ?? 'Something went wrong',
      onRetry: _s._load,
    );
  }
}
