part of 'anime_screen.dart';

mixin _AnimeScreenBuild on ConsumerState<AnimeScreen> {
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
            final status = a.status?.trim();
            final isUpcoming = status == 'NOT_YET_RELEASED';
            return HubHeroSlide(
              id: '${a.id}',
              title: a.displayTitle,
              imageUrl: a.heroBackdrop,
              overview: a.cleanDescription,
              rating: (a.averageScore ?? 0) > 0 ? (a.averageScore! / 10) : null,
              year: a.seasonYear?.toString(),
              badge: a.format,
              statusChip: status != null && status.isNotEmpty
                  ? hubAnimeStatusLabel(status)
                  : null,
              isUpcoming: isUpcoming,
              upcomingReleaseLabel:
                  isUpcoming && a.seasonYear != null ? '${a.seasonYear}' : null,
              genres: a.genres,
              imageFit: useAniBanner ? BoxFit.fitWidth : BoxFit.cover,
              imageAlignment:
                  useAniBanner ? Alignment.center : Alignment.centerRight,
              tmdbId: a.tmdbId,
              tmdbMediaType: a.tmdbMediaType ??
                  ((a.format ?? '').toUpperCase() == 'MOVIE' ? 'movie' : 'tv'),
              onDetails: () => _s._openDetails(a),
              listTarget: HubListFollowTarget.anime(
                anilistId: a.id,
                title: a.displayTitle,
                posterPath: a.coverUrl,
                voteAverage:
                    (a.averageScore ?? 0) > 0 ? (a.averageScore! / 10) : 0,
                releaseDate: a.seasonYear?.toString() ?? '',
              ),
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
    return HubPosterCard(
      imageUrl: anime.coverUrl,
      title: anime.displayTitle,
      subtitle: _animeCardMeta(anime),
      rating: (anime.averageScore ?? 0) > 0 ? (anime.averageScore! / 10) : null,
      rank: rank,
      listIndex: listIndex,
      tvTabId: 'anime',
      tvRowId: tvRowId,
      onUpEdge: onUpEdge,
      onTap: () => _s._openDetails(anime),
      listTarget: HubListFollowTarget.anime(
        anilistId: anime.id,
        title: anime.displayTitle,
        posterPath: anime.coverUrl,
        voteAverage:
            (anime.averageScore ?? 0) > 0 ? (anime.averageScore! / 10) : 0,
        releaseDate: anime.seasonYear?.toString() ?? '',
      ),
    );
  }

  /// Bottom meta like Home (`year • FILM` / `year • TV`).
  /// Series keep episode count — no TV / TV Shows label.
  String? _animeCardMeta(AnimeCard anime) {
    final parts = <String>[];
    if (anime.seasonYear != null) parts.add('${anime.seasonYear}');
    final fmt = (anime.format ?? '').toUpperCase();
    if (fmt == 'TV' || fmt == 'TV_SHORT') {
      if (anime.episodes != null) parts.add('${anime.episodes} eps');
    } else if (fmt == 'MOVIE') {
      parts.add('FILM');
    } else if (fmt.isNotEmpty) {
      parts.add(fmt.replaceAll('_', ' '));
    } else if (anime.episodes != null) {
      parts.add('${anime.episodes} eps');
    }
    if (parts.isEmpty) return null;
    return parts.join(' • ');
  }

  // ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    super.build(context);
    ref.listen(animeCatalogFuturesProvider, (_, next) {
      if (!mounted || !_s.shellTabVisible) return;
      _s._applyCatalogFutures(next);
    });
    ref.listen(animeMoodCatalogProvider(_s._selectedMood), (_, next) {
      if (!mounted) return;
      next.whenData((cards) {
        setState(() => _s._moodFuture = Future.value(cards));
      });
    });
    final catalogLoad = ref.watch(animeCatalogFuturesProvider);
    ref.watch(animeMoodCatalogProvider(_s._selectedMood));
    // Bridge current value (listen skips it) without waiting a frame for apply.
    if (!identical(_s._appliedCatalog, catalogLoad) && _s.shellTabVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_s.shellTabVisible) return;
        _s._applyCatalogFutures(catalogLoad);
      });
    }
    // Prefer applied state; fall back to live provider futures for this frame.
    final rawSpotlight = _s._spotlightFuture ?? catalogLoad.spotlight;
    final rawTrending = _s._trendingFuture ?? catalogLoad.trending;
    final rawTopAiring = _s._topAiringFuture ?? catalogLoad.topAiring;
    final rawMostPopular = _s._mostPopularFuture ?? catalogLoad.mostPopular;
    final rawMostFavorite =
        _s._mostFavoriteFuture ?? catalogLoad.mostFavorite;
    final rawTopRated = _s._topRatedFuture ?? catalogLoad.topRated;
    final rawLatestCompleted =
        _s._latestCompletedFuture ?? catalogLoad.latestCompleted;
    final rawTop10 = _s._top10Future ?? catalogLoad.top10;
    final rawRecentEpisodes =
        _s._recentEpisodesFuture ?? catalogLoad.recentEpisodes;
    // Server-filtered via animeCatalogFuturesProvider (Films/Series/Categories).
    final spotlightFuture = rawSpotlight;
    final trendingFuture = rawTrending;
    final topAiringFuture = rawTopAiring;
    final mostPopularFuture = rawMostPopular;
    final mostFavoriteFuture = rawMostFavorite;
    final topRatedFuture = rawTopRated;
    final latestCompletedFuture = rawLatestCompleted;
    final top10Future = rawTop10;
    final recentEpisodesFuture = rawRecentEpisodes;
    return TvFocusGraph(
      tabId: 'anime',
      child: ValueListenableBuilder<AppThemePreset>(
      valueListenable: AppTheme.themeNotifier,
      builder: (context, _, _) {
        final fullHero = hubIsFullCinematicHero(context);
        final usesShell = hubUsesShellLayout(context);
        // Under Films/Series/Categories, Trending duplicates Top Rated — hide it.
        final showTrending = !animeHubFilterActive();
        final trendingOnHero = usesShell && fullHero && showTrending;
        final moodChipsOrder = _moodChipsOrder(trendingOnHero: trendingOnHero);
        final moodResultsOrder =
            _moodResultsOrder(trendingOnHero: trendingOnHero);
        final catalogBase = _catalogRowBase(trendingOnHero: trendingOnHero);
        // Bleed Trending owns 0; otherwise Trending is the first catalog row
        // (when shown). When Trending is hidden, catalog starts at catalogBase.
        final trendingOrder = trendingOnHero ? 0 : catalogBase;
        final catalogStart = trendingOnHero
            ? catalogBase
            : (showTrending ? catalogBase + 1 : catalogBase);
        void focusHeroPlay() {
          ShellTvFocusCoordinator.revealHeroForTab('anime');
          ShellTvFocus.focusHomeHeroPlay();
        }

        final trendingSection = trendingOnHero
            ? HubCatalogSection<AnimeCard>(
                title: 'Trending Now',
                future: trendingFuture,
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

        final body = _s._error != null && _s._catalogResolved
              ? _buildError()
              : RefreshIndicator(
                          color: ForjaShellColors.sectionAccent,
                          backgroundColor: AppTheme.bgCard,
                          onRefresh: _s._load,
                          child: ColoredBox(
                            color: AppTheme.bgDark,
                            child: CustomScrollView(
                            controller: _s._scroll,
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            slivers: [
                              SliverToBoxAdapter(
                                child: _AnimeHubHeroSection(
                                  spotlightFuture: spotlightFuture,
                                  service: _s._service,
                                  buildSlides: _heroSlides,
                                  tvTabId: 'anime',
                                  scrollController: _s._scroll,
                                  trendingOnHero: trendingOnHero,
                                  pageBottomChild: trendingSection,
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
                              if (trendingSection == null && showTrending)
                                hubRowSliver(context,
                                  HubCatalogSection<AnimeCard>(
                                    title: 'Trending Now',
                                    future: trendingFuture,
                                    tvTabId: 'anime',
                                    tvRowId: 'trending',
                                    tvRowOrder: trendingOrder,
                                    // Mood/Continue sit above - don't skip to hero.
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
                                  future: topAiringFuture,
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
                                  future: top10Future,
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
                                  future: mostPopularFuture,
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
                                  future: recentEpisodesFuture,
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
                                  future: topRatedFuture,
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
                                  future: mostFavoriteFuture,
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
                                  future: latestCompletedFuture,
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
                              SliverToBoxAdapter(
                                child: SizedBox(
                                  height: shellTvCatalogScrollBottomGap(context),
                                ),
                              ),
                            ],
                          ),
                          ),
                        );

        if (!usesShell) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              body,
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AnimeCatalogTopBar(),
              ),
            ],
          );
        }
        return body;
      },
    ),
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

  // ─── Mood chips (home-style circles) ───────────────────────────
  Widget _moodCircleItem({
    required BuildContext context,
    required ShellMoodCircleLayout layout,
    required int i,
    TvChipEdges? edges,
  }) {
    final moods = _AnimeScreenState._moods;
    final m = moods[i];
    final selected = m.id == _s._selectedMood;
    return ShellMoodCircleItem(
      layout: layout,
      label: m.label,
      icon: m.icon,
      accent: m.accent,
      selected: selected,
      listIndex: i,
      tvTabId: 'anime',
      tvRowId: 'mood-chips',
      onTap: () {
        if (m.id != _s._selectedMood) {
          _s._selectMood(m.id);
        } else if (edges != null) {
          edges.onSelectAlreadySelected();
        }
      },
      onLeftEdge: edges?.onLeft,
      onRightEdge: edges?.onRight,
      onDownEdge: edges?.onDown,
      onUpEdge: edges?.onUp,
    );
  }

  Widget _centeredMoodRow({
    required BuildContext context,
    required ShellMoodCircleLayout layout,
    bool scaleToFit = false,
    TvChipEdges Function(int index)? edgesFor,
  }) {
    final moods = _AnimeScreenState._moods;
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < moods.length; i++) ...[
          if (i > 0) SizedBox(width: layout.horizontalGap),
          _moodCircleItem(
            context: context,
            layout: layout,
            i: i,
            edges: edgesFor?.call(i),
          ),
        ],
      ],
    );

    return SizedBox(
      height: layout.rowHeight,
      width: double.infinity,
      child: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: scaleToFit
            ? FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: row,
              )
            : Center(child: row),
      ),
    );
  }

  Widget _buildMoodChips({
    required int chipsOrder,
    required int resultsOrder,
  }) {
    final moods = _AnimeScreenState._moods;
    final titleTop = shellHomeSectionTitleTop(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: shellHomeSectionTitlePadding(
            context,
            top: titleTop,
            bottom: shellScaled(context, 12).clamp(4.0, 12.0),
          ),
          child: const Text(
            'Pick your vibe',
            style: ShellSectionTitle.titleStyle,
          ),
        ),
        Builder(
          builder: (context) {
            final tvNav =
                ShellScope.inputPolicyOf(context).useFocusableMoodChips;
            return LayoutBuilder(
              builder: (context, constraints) {
                final layout = ShellMoodCircleLayout.resolve(
                  context,
                  itemCount: moods.length,
                  maxWidth: constraints.maxWidth,
                );

                if (tvNav) {
                  return TvChipStrip(
                    tabId: 'anime',
                    rowId: 'mood-chips',
                    sortOrder: chipsOrder,
                    itemCount: moods.length,
                    resultsRowId: 'mood-results',
                    builder: (context, edgesFor) => _centeredMoodRow(
                      context: context,
                      layout: layout,
                      scaleToFit: true,
                      edgesFor: edgesFor,
                    ),
                  );
                }

                final fitsCentered =
                    layout.contentWidth(moods.length) <= constraints.maxWidth;
                if (fitsCentered) {
                  return _centeredMoodRow(
                    context: context,
                    layout: layout,
                  );
                }

                return FocusTraversalGroup(
                  policy: ReadingOrderTraversalPolicy(),
                  child: HorizontalScroller(
                    height: layout.rowHeight,
                    padding: EdgeInsets.symmetric(
                      horizontal: shellHomeSectionHorizontalPadding(context),
                    ),
                    itemCount: moods.length,
                    separatorBuilder: (_, _) =>
                        SizedBox(width: layout.horizontalGap),
                    itemBuilder: (context, i) => _moodCircleItem(
                      context: context,
                      layout: layout,
                      i: i,
                    ),
                  ),
                );
              },
            );
          },
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

        return TvCatalogRow(
          tabId: 'anime',
          rowId: 'mood-results',
          sortOrder: resultsOrder,
          itemCount: list.length,
          child: SizedBox(
            height: HubPosterCard.cardHeight(context),
            child: FocusTraversalGroup(
              policy: ReadingOrderTraversalPolicy(),
              child: ListView.separated(
                clipBehavior: Clip.none,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                scrollCacheExtent: ScrollCacheExtent.pixels(2000),
                padding: EdgeInsets.symmetric(
                  horizontal: shellHomeSectionHorizontalPadding(context),
                ),
                itemCount: list.length,
                separatorBuilder: (_, _) =>
                    SizedBox(width: shellMovieCardRowGap(context)),
                itemBuilder: (context, index) => FocusTraversalOrder(
                  order: NumericFocusOrder(index.toDouble()),
                  child: _animePosterCard(
                    list[index],
                    listIndex: index,
                    tvRowId: 'mood-results',
                    onUpEdge: tvResultsUpToChips(
                      context,
                      chipRowId: 'mood-chips',
                    ),
                  ),
                ),
              ),
            ),
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

/// Hero + TMDB backdrop enrich isolated from the hub scroll view so catalog
/// D-pad focus is not dropped when backdrops swap in.
class _AnimeHubHeroSection extends StatefulWidget {
  const _AnimeHubHeroSection({
    required this.spotlightFuture,
    required this.service,
    required this.buildSlides,
    required this.tvTabId,
    required this.scrollController,
    required this.trendingOnHero,
    this.pageBottomChild,
  });

  final Future<List<AnimeCard>> spotlightFuture;
  final AnimeService service;
  final List<HubHeroSlide> Function(List<AnimeCard>) buildSlides;
  final String tvTabId;
  final ScrollController scrollController;
  final bool trendingOnHero;
  final Widget? pageBottomChild;

  @override
  State<_AnimeHubHeroSection> createState() => _AnimeHubHeroSectionState();
}

class _AnimeHubHeroSectionState extends State<_AnimeHubHeroSection> {
  List<AnimeCard>? _cards;
  int _loadGen = 0;
  int _enrichGen = 0;

  @override
  void initState() {
    super.initState();
    _subscribeSpotlight(widget.spotlightFuture);
  }

  @override
  void didUpdateWidget(covariant _AnimeHubHeroSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.spotlightFuture, widget.spotlightFuture)) {
      _subscribeSpotlight(widget.spotlightFuture);
    }
  }

  void _subscribeSpotlight(Future<List<AnimeCard>> future) {
    final gen = ++_loadGen;
    _cards = null;
    future.then((list) {
      if (!mounted || gen != _loadGen || list.isEmpty) return;
      setState(() => _cards = list);
      unawaited(_enrichTmdb(list, gen));
    }).catchError((_) {});
  }

  Future<void> _enrichTmdb(List<AnimeCard> list, int loadGen) async {
    final enrichGen = ++_enrichGen;
    try {
      final head = list.take(5).toList();
      final enrichedHead = await widget.service.attachTmdbBackdrops(head);
      if (!mounted || loadGen != _loadGen || enrichGen != _enrichGen) return;
      final byId = {for (final c in enrichedHead) c.id: c};
      final merged = [for (final c in list) byId[c.id] ?? c];
      setState(() => _cards = merged);
    } catch (e) {
      debugPrint('[AnimeHubHero] TMDB enrich failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cards = _cards;
    if (cards == null || cards.isEmpty) {
      return homeCinematicHeroShimmer(
        context,
        pageBottomBleed: widget.trendingOnHero,
      );
    }
    return HomeCinematicHero.hub(
      slides: widget.buildSlides(cards.take(5).toList()),
      tvTabId: widget.tvTabId,
      scrollController: widget.scrollController,
      pageBottomChild: widget.pageBottomChild,
    );
  }
}
