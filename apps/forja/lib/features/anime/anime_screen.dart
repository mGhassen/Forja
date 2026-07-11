// Anime hub — cinematic hero + poster rows (same shell as Home).

import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/widgets/home_loading_skeleton.dart';
import 'package:forja/shared/widgets/hub/hub_catalog_section.dart';
import 'package:forja/shared/widgets/hub/hub_cinematic_hero.dart';
import 'package:forja/shared/widgets/hub/hub_poster_card.dart';

import 'package:forja/features/anime/catalog/anime_service.dart';
import 'anime_details_screen.dart';
import 'anime_player_screen.dart';
import 'anime_search_screen.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shell/app_router.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';

class AnimeScreen extends StatefulWidget {
  const AnimeScreen({super.key});

  @override
  State<AnimeScreen> createState() => _AnimeScreenState();
}

class _AnimeScreenState extends State<AnimeScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final AnimeService _service = AnimeService();
  final ScrollController _cwScrollController = ScrollController();
  final ScrollController _scroll = ScrollController();

  // Section futures
  Future<List<AnimeCard>>? _spotlightFuture;
  Future<List<AnimeCard>>? _trendingFuture;
  Future<List<AnimeCard>>? _topAiringFuture;
  Future<List<AnimeCard>>? _mostPopularFuture;
  Future<List<AnimeCard>>? _mostFavoriteFuture;
  Future<List<AnimeCard>>? _topRatedFuture;
  Future<List<AnimeCard>>? _latestCompletedFuture;
  Future<List<AnimeCard>>? _top10Future;
  Future<List<AnimeCard>>? _recentEpisodesFuture;
  Future<List<Map<String, dynamic>>>? _historyFuture;

  bool _catalogResolved = false;
  String? _error;

  // Continue watching
  List<Map<String, dynamic>> _continueWatching = [];

  int get _moodChipsOrder => _continueWatching.isNotEmpty ? 1 : 0;
  int get _moodResultsOrder => _moodChipsOrder + 1;
  int get _catalogRowBase => _moodResultsOrder + 1;

  // Mood / genre filter
  String _selectedMood = 'shonen';
  Future<List<AnimeCard>>? _moodFuture;

  static const List<({String id, String label, IconData icon, String? genre})>
      _moods = [
    (id: 'shonen',    label: 'Shōnen',       icon: Icons.local_fire_department_rounded, genre: 'Action'),
    (id: 'romance',   label: 'Romance',      icon: Icons.favorite_rounded,              genre: 'Romance'),
    (id: 'comedy',    label: 'Comedy',       icon: Icons.sentiment_very_satisfied_rounded, genre: 'Comedy'),
    (id: 'mystery',   label: 'Mystery',      icon: Icons.psychology_rounded,            genre: 'Mystery'),
    (id: 'thriller',  label: 'Thriller',     icon: Icons.dark_mode_rounded,             genre: 'Thriller'),
    (id: 'fantasy',   label: 'Fantasy',      icon: Icons.auto_awesome_rounded,          genre: 'Fantasy'),
    (id: 'sliceLife', label: 'Slice of Life',icon: Icons.wb_sunny_rounded,              genre: 'Slice of Life'),
    (id: 'scifi',     label: 'Sci-Fi',       icon: Icons.rocket_launch_rounded,         genre: 'Sci-Fi'),
    (id: 'sports',    label: 'Sports',       icon: Icons.sports_baseball_rounded,       genre: 'Sports'),
    (id: 'horror',    label: 'Horror',       icon: Icons.bedtime_rounded,               genre: 'Horror'),
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    ShellTvFocusCoordinator.registerTabDefaults(
      'anime',
      defaultFocus: () => ShellTvFocus.homeHeroPlay,
      heroReveal: () {
        if (!_scroll.hasClients) return;
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      },
    );
    WidgetsBinding.instance.addObserver(this);
    AppTheme.themeNotifier.addListener(_onTheme);
    AnimeService.watchHistoryRevision.addListener(_onHistoryChanged);
    unawaited(_load());
  }

  @override
  void dispose() {
    ShellTvFocusCoordinator.clearTab('anime');
    WidgetsBinding.instance.removeObserver(this);
    AppTheme.themeNotifier.removeListener(_onTheme);
    AnimeService.watchHistoryRevision.removeListener(_onHistoryChanged);
    _cwScrollController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshHistory();
    }
  }

  void _onHistoryChanged() => _refreshHistory();

  /// Reload only the Continue Watching list — cheap, no API hits other
  /// than SharedPreferences. Called on app resume, on history mutation,
  /// and after returning from any screen that may have updated history.
  Future<void> _refreshHistory() async {
    try {
      final list = await _service.getWatchHistory();
      if (!mounted) return;
      setState(() {
        _continueWatching = list.take(10).toList();
      });
    } catch (_) {}
  }

  void _onTheme() {
    if (mounted) setState(() {});
  }

  Future<List<AnimeCard>> _safeSection(
    Future<List<AnimeCard>> future,
    String name,
  ) async {
    try {
      return await future;
    } catch (e) {
      debugPrint('[AnimeScreen] $name load failed: $e');
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> _safeHistory() async {
    try {
      return await _service.getWatchHistory();
    } catch (e) {
      debugPrint('[AnimeScreen] watch history load failed: $e');
      return const [];
    }
  }

  Future<void> _load() async {
    final spotlightFuture = _safeSection(_service.getSpotlight(), 'spotlight');
    final trendingFuture = _safeSection(_service.getTrending(), 'trending');
    final topAiringFuture = _safeSection(_service.getTopAiring(), 'top airing');
    final mostPopularFuture =
        _safeSection(_service.getMostPopular(), 'most popular');
    final mostFavoriteFuture =
        _safeSection(_service.getMostFavorite(), 'most favorite');
    final topRatedFuture = _safeSection(_service.getTopRated(), 'top rated');
    final latestCompletedFuture =
        _safeSection(_service.getLatestCompleted(), 'latest completed');
    final top10Future = _safeSection(_service.getTop10Today(), 'top 10');
    final recentEpisodesFuture =
        _safeSection(_service.getRecentEpisodes(), 'recent episodes');
    final historyFuture = _safeHistory();

    setState(() {
      _error = null;
      _moodFuture = null;
      _catalogResolved = false;
      _spotlightFuture = spotlightFuture;
      _trendingFuture = trendingFuture;
      _topAiringFuture = topAiringFuture;
      _mostPopularFuture = mostPopularFuture;
      _mostFavoriteFuture = mostFavoriteFuture;
      _topRatedFuture = topRatedFuture;
      _latestCompletedFuture = latestCompletedFuture;
      _top10Future = top10Future;
      _recentEpisodesFuture = recentEpisodesFuture;
      _historyFuture = historyFuture;
    });

    final results = await Future.wait([
      spotlightFuture,
      trendingFuture,
      topAiringFuture,
      mostPopularFuture,
      mostFavoriteFuture,
      topRatedFuture,
      latestCompletedFuture,
      top10Future,
      recentEpisodesFuture,
      historyFuture,
    ]);
    if (!mounted) return;

    final hasCatalog = results
        .take(9)
        .cast<List<AnimeCard>>()
        .any((section) => section.isNotEmpty);

    setState(() {
      _continueWatching =
          (results[9] as List<Map<String, dynamic>>).take(10).toList();

      _catalogResolved = true;
      _error = hasCatalog ? null : 'Failed to load anime — check your connection';
      _moodFuture = _loadMood(_selectedMood);
    });
  }

  Future<List<AnimeCard>> _loadMood(String id) async {
    try {
      final mood = _moods.firstWhere((m) => m.id == id, orElse: () => _moods[0]);
      return await _service.browse(
        genre: mood.genre,
        sort: 'TRENDING_DESC',
        perPage: 20,
      );
    } catch (e) {
      debugPrint('[AnimeScreen] mood load failed: $e');
      return const [];
    }
  }

  void _selectMood(String id) {
    if (id == _selectedMood) return;
    setState(() {
      _selectedMood = id;
      _moodFuture = _loadMood(id);
    });
  }

  void _openDetails(AnimeCard a) {
    openAnimeDetails(context, a).then((_) => _refreshHistory());
  }

  void _openSearch() {
    pushShellRoute(
      context,
      AppRouter.slideRoute((_) => const AnimeSearchScreen()),
    );
  }

  Future<void> _resumeWatch(Map<String, dynamic> entry) async {
    try {
      final anime = AnimeCard.fromJson(
          (entry['anime'] as Map).cast<String, dynamic>());
      final epNum = (entry['episodeNumber'] as num?)?.toInt() ?? 1;
      final cat = (entry['category'] as String?) ?? 'sub';
      openAnimePlayer(
        context,
        anime: anime,
        episodeNumber: epNum,
        category: cat,
      ).then((_) => _refreshHistory());
    } catch (_) {}
  }

  Future<void> _removeFromHistory(Map<String, dynamic> entry) async {
    final animeId = entry['animeId'] as int?;
    if (animeId == null) return;
    await _service.removeFromHistory(animeId);
    if (!mounted) return;
    setState(() {
      _continueWatching.removeWhere((e) => e['animeId'] == animeId);
    });
  }

  List<HubHeroSlide> _heroSlides(List<AnimeCard> spotlight) {
    return spotlight
        .map(
          (a) => HubHeroSlide(
            id: '${a.id}',
            title: a.displayTitle,
            imageUrl: a.bannerOrCover,
            overview: a.cleanDescription,
            rating: (a.averageScore ?? 0) > 0 ? (a.averageScore! / 10) : null,
            year: a.seasonYear?.toString(),
            badge: a.format,
            genres: a.genres,
            onPlay: () => _openDetails(a),
            onDetails: () => _openDetails(a),
          ),
        )
        .toList();
  }

  HubPosterCard _animePosterCard(
    AnimeCard anime, {
    int? rank,
    int? listIndex,
    String? tvRowId,
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
      tvRowId: tvRowId,
      onTap: () => _openDetails(anime),
    );
  }

  // ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ValueListenableBuilder<AppThemePreset>(
      valueListenable: AppTheme.themeNotifier,
      builder: (context, _, _) {
        return _error != null && _catalogResolved
              ? _buildError()
              : RefreshIndicator(
                          color: ForjaShellColors.sectionAccent,
                          backgroundColor: AppTheme.bgCard,
                          onRefresh: _load,
                          child: ColoredBox(
                            color: AppTheme.bgDark,
                            child: CustomScrollView(
                            controller: _scroll,
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            slivers: [
                              SliverToBoxAdapter(
                                child: FutureBuilder<List<AnimeCard>>(
                                  future: _spotlightFuture,
                                  builder: (context, snap) {
                                    if (snap.connectionState ==
                                            ConnectionState.waiting ||
                                        !snap.hasData ||
                                        snap.data!.isEmpty) {
                                      return homeCinematicHeroShimmer(context);
                                    }
                                    return HubCinematicHero(
                                      slides: _heroSlides(
                                        snap.data!.take(5).toList(),
                                      ),
                                      onSearch: _openSearch,
                                      tvTabId: 'anime',
                                    );
                                  },
                                ),
                              ),
                              if (_continueWatching.isNotEmpty)
                                hubRowSliver(context,
                                  _buildContinueWatching(),
                                  isFirstAfterHero: true,
                                )
                              else
                                hubRowSliver(context,
                                  FutureBuilder<List<Map<String, dynamic>>>(
                                    future: _historyFuture,
                                    builder: (context, snap) {
                                      if (snap.connectionState ==
                                          ConnectionState.waiting) {
                                        return homeContinueWatchingSkeleton(
                                          context,
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                  isFirstAfterHero: true,
                                ),
                              hubRowSliver(context,_buildMoodChips(), isFirstAfterHero: false),
                              hubRowSliver(context,
                                HubCatalogSection<AnimeCard>(
                                  title: 'Trending Now',
                                  future: _trendingFuture,
                                  tvTabId: 'anime',
                                  tvRowId: 'trending',
                                  tvRowOrder: _catalogRowBase + 0,
                                  tvFocusUp: () => ShellTvFocusCoordinator.focusHero(
                                    tabId: 'anime',
                                  ),
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
                                  future: _topAiringFuture,
                                  tvTabId: 'anime',
                                  tvRowId: 'top-airing',
                                  tvRowOrder: _catalogRowBase + 1,
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
                                  future: _top10Future,
                                  showRank: true,
                                  tvTabId: 'anime',
                                  tvRowId: 'top-10',
                                  tvRowOrder: _catalogRowBase + 2,
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
                                  future: _mostPopularFuture,
                                  tvTabId: 'anime',
                                  tvRowId: 'most-popular',
                                  tvRowOrder: _catalogRowBase + 3,
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
                                  future: _recentEpisodesFuture,
                                  tvTabId: 'anime',
                                  tvRowId: 'latest-eps',
                                  tvRowOrder: _catalogRowBase + 4,
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
                                  future: _topRatedFuture,
                                  tvTabId: 'anime',
                                  tvRowId: 'top-rated',
                                  tvRowOrder: _catalogRowBase + 5,
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
                                  future: _mostFavoriteFuture,
                                  tvTabId: 'anime',
                                  tvRowId: 'most-favorited',
                                  tvRowOrder: _catalogRowBase + 6,
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
                                  future: _latestCompletedFuture,
                                  tvTabId: 'anime',
                                  tvRowId: 'recently-completed',
                                  tvRowOrder: _catalogRowBase + 7,
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
  void _cwScrollLeft() {
    if (_cwScrollController.hasClients) {
      _cwScrollController.animateTo(
        (_cwScrollController.offset - 400).clamp(0.0, _cwScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void _cwScrollRight() {
    if (_cwScrollController.hasClients) {
      _cwScrollController.animateTo(
        (_cwScrollController.offset + 400).clamp(0.0, _cwScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  Widget _cwArrowButton(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Icon(icon, color: Colors.white.withValues(alpha: 0.6), size: 14),
    );
  }

  Widget _buildContinueWatching() {
    final w = MediaQuery.of(context).size.width;
    final hPad = w < 380 ? 14.0 : 24.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShellSectionTitle(
          title: 'Continue Watching',
          padding: EdgeInsets.fromLTRB(
            24,
            homeUsesShellLayout(context)
                ? ShellTokens.homeSectionTitleTopCompactDesktop
                : ShellTokens.homeSectionTitleTopCompactMobile,
            24,
            16,
          ),
          trailing: [
            GestureDetector(
              onTap: _cwScrollLeft,
              child: _cwArrowButton(Icons.arrow_back_ios_new_rounded),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: _cwScrollRight,
              child: _cwArrowButton(Icons.arrow_forward_ios_rounded),
            ),
          ],
        ),
        SizedBox(
          height: _AnimeContinueWatchingCard.cardHeight(context),
          child: Builder(
            builder: (context) {
              shellTvRegisterRow(
                tabId: 'anime',
                rowId: 'continue-watching',
                sortOrder: 0,
                itemCount: _continueWatching.length,
                onFocusUp: () =>
                    ShellTvFocusCoordinator.focusHero(tabId: 'anime'),
              );
              return FocusTraversalGroup(
                policy: OrderedTraversalPolicy(),
                child: ListView.separated(
            controller: _cwScrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            clipBehavior: Clip.none,
            padding: EdgeInsets.symmetric(horizontal: hPad),
            itemCount: _continueWatching.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (_, i) {
              final entry = _continueWatching[i];
              final anime = AnimeCard.fromJson(
                (entry['anime'] as Map).cast<String, dynamic>(),
              );
              return _AnimeContinueWatchingCard(
                listIndex: i,
                entry: entry,
                onTap: () => _resumeWatch(entry),
                onRemove: () => _removeFromHistory(entry),
                onInfo: () => _openDetails(anime),
              );
            },
          ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── Mood chips ────────────────────────────────────────────────
  Widget _buildMoodChips() {
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
                sortOrder: _moodChipsOrder,
                itemCount: _moods.length,
              );
              return FocusTraversalGroup(
                policy: OrderedTraversalPolicy(),
                child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: shellHomeSectionHorizontalPadding(context),
            ),
            itemCount: _moods.length,
            separatorBuilder: (_, _) =>
                SizedBox(width: shellScaled(context, 8).clamp(4.0, 8.0)),
            itemBuilder: (_, i) {
              final m = _moods[i];
              final selected = m.id == _selectedMood;
              return ForjaShellChip(
                label: m.label,
                selected: selected,
                icon: m.icon,
                listIndex: i,
                tvTabId: 'anime',
                tvRowId: 'mood-chips',
                onTap: () {
                  if (m.id != _selectedMood) {
                    _selectMood(m.id);
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
                  itemCount: _moods.length,
                ),
                onDownEdge: shellTvChipDownToRow(
                  tabId: 'anime',
                  chipRowId: 'mood-chips',
                  resultsRowId: 'mood-results',
                ),
              );
            },
          ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        _buildMoodSection(),
      ],
    );
  }

  Widget _buildMoodSection() {
    final future = _moodFuture;
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

        return SizedBox(
          height: HubPosterCard.cardHeight(context),
          child: Builder(
            builder: (context) {
              shellTvRegisterRow(
                tabId: 'anime',
                rowId: 'mood-results',
                sortOrder: _moodResultsOrder,
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
            itemBuilder: (context, index) =>
                _animePosterCard(
              list[index],
              listIndex: index,
              tvRowId: 'mood-results',
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                color: ForjaShellColors.sectionAccent, size: 48),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class _AnimeContinueWatchingCard extends StatefulWidget {
  final Map<String, dynamic> entry;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final VoidCallback onInfo;
  final int listIndex;

  const _AnimeContinueWatchingCard({
    required this.entry,
    required this.onTap,
    required this.onRemove,
    required this.onInfo,
    required this.listIndex,
  });

  static double cardWidth(BuildContext context) =>
      shellContinueWatchingCardWidth(context);

  static double cardHeight(BuildContext context) =>
      shellContinueWatchingCardHeight(context);

  @override
  State<_AnimeContinueWatchingCard> createState() =>
      _AnimeContinueWatchingCardState();
}

class _AnimeContinueWatchingCardState extends State<_AnimeContinueWatchingCard> {
  bool _hovered = false;
  bool _focused = false;

  bool _activeFor(ShellInputPolicy policy) =>
      ShellInputPolicy.interactiveActive(
        policy,
        hovered: _hovered,
        focused: _focused,
      );

  @override
  Widget build(BuildContext context) {
    final policy = ShellScope.inputPolicyOf(context);
    final anime = AnimeCard.fromJson(
      (widget.entry['anime'] as Map).cast<String, dynamic>(),
    );
    final ep = (widget.entry['episodeNumber'] as num?)?.toInt() ?? 1;
    final cat = (widget.entry['category'] as String?) ?? 'sub';
    final position = (widget.entry['positionMs'] as num?)?.toInt() ?? 0;
    final duration = (widget.entry['durationMs'] as num?)?.toInt() ?? 0;
    final progress =
        duration > 0 ? (position / duration).clamp(0.0, 1.0) : 0.0;
    final remaining = duration > 0
        ? Duration(milliseconds: duration - position)
        : Duration.zero;
    final remainingText =
        remaining.inMinutes > 0 ? '${remaining.inMinutes}m left' : '';
    final subtitle = 'Ep $ep · ${cat.toUpperCase()}';
    final cardWidth = _AnimeContinueWatchingCard.cardWidth(context);
    final cardHeight = _AnimeContinueWatchingCard.cardHeight(context);

    return shellFocusableTap(
      context: context,
      onTap: widget.onTap,
      listIndex: widget.listIndex,
      tvTabId: 'anime',
      tvRowId: 'continue-watching',
      tvItemIndex: widget.listIndex,
      borderRadius: 14,
      scaleOnFocus: 1.0,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onHoverChange: (hovered) => setState(() => _hovered = hovered),
      child: AnimatedScale(
        scale: _activeFor(policy) ? 1.05 : 1.0,
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
                      child: anime.bannerOrCover.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: anime.bannerOrCover,
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.medium,
                              placeholder: (c, u) =>
                                  ColoredBox(color: AppTheme.bgDark),
                            )
                          : const Icon(
                              Icons.movie,
                              color: Colors.white24,
                              size: 40,
                            ),
                    ),
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
                    Positioned(
                      top: 6,
                      right: 6,
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
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  anime.displayTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    height: 1.2,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.6),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                if (remainingText.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: Text(
                                      remainingText,
                                      style: TextStyle(
                                        color: ForjaShellColors.badgeLabel,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(14),
                            ),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.1),
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
                          opacity: _activeFor(policy) ? 1.0 : 0.0,
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
                  ],
                ),
              ),
            ),
          ),
    );
  }
}
