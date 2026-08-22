// kisskh.co (Asian Drama) hub - cinematic hero + poster rows (same shell as Home).

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/asian_drama/providers/asian_drama_providers.dart';
import 'package:forja/features/asian_drama/catalog/kisskh_service.dart';
import 'package:forja/features/asian_drama/catalog/kisskh_tmdb_match.dart';
import 'package:forja/features/asian_drama/widgets/asian_drama_continue_watching_section.dart';
import 'package:forja/shared/widgets/hero/cinematic_hero.dart';
import 'package:forja/shared/widgets/hub/hub_catalog_section.dart';
import 'package:forja/shared/widgets/hub/hub_poster_card.dart';
import 'package:forja/shared/services/hub_list_follow.dart';
import 'asian_drama_details_screen.dart';
import 'asian_drama_player_screen.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/widgets/home_loading_skeleton.dart';
import 'package:forja/shell/shell_tab_refresh.dart';
import 'package:forja/shared/widgets/shell_error_retry_panel.dart';
import 'package:rust/rust.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';

class AsianDramaScreen extends ConsumerStatefulWidget {
  const AsianDramaScreen({super.key});

  @override
  ConsumerState<AsianDramaScreen> createState() => _AsianDramaScreenState();
}

class _AsianDramaScreenState extends ConsumerState<AsianDramaScreen>
    with
        AutomaticKeepAliveClientMixin,
        WidgetsBindingObserver,
        ShellTabRefresh<AsianDramaScreen> {
  /// KissKH `/Drama/{id}` hero synopsis - kept but off (burns shared IP).
  static const bool _kissKhHeroSynopsisEnrich = false;

  /// Trial: fill hero overview from TMDB search instead of KissKH details.
  static const bool _tmdbHeroSynopsisEnrich = true;

  final KissKhService _service = KissKhService();
  final ScrollController _scroll = ScrollController();

  /// Cached so [onShellTabShown] / refresh can invalidate without
  /// `dependOnInheritedWidget` on a deactivated [Visibility] child.
  ProviderContainer? _container;

  KdramaHomeFeed? _feed;
  bool _loading = true;
  String? _error;
  int _loadGen = 0;

  List<Map<String, dynamic>> _continueWatching = [];
  int? _resumingDramaId;

  /// TV D-pad order must match visual stack.
  /// Full hero: Latest (bleed) → Continue → catalog.
  /// Narrow/mobile: Continue → Latest → catalog.
  int _continueOrder({required bool latestOnHero}) => latestOnHero ? 1 : 0;

  int _latestOrder({required bool latestOnHero}) {
    if (latestOnHero) return 0;
    return _continueWatching.isNotEmpty ? 1 : 0;
  }

  /// First catalog row after Latest + Continue (excludes hero-bleed Latest).
  int _catalogRowBase({
    required bool latestOnHero,
    required bool latestAsCatalogRow,
  }) {
    var order = 0;
    if (latestOnHero) order += 1;
    if (_continueWatching.isNotEmpty) order += 1;
    if (latestAsCatalogRow) order += 1;
    return order;
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Duration get shellStaleAfter => ShellTokens.tabStaleDefault;

  @override
  Future<void> onShellTabRefresh({required bool force}) async {
    if (_error != null || _feed == null || force) {
      await _load();
    }
  }

  @override
  void onShellTabHidden() {
    super.onShellTabHidden();
    _loadGen++;
  }

  @override
  void onShellTabShown() {
    super.onShellTabShown();
    if (_feed == null || _error != null) {
      unawaited(_load());
    }
  }

  @override
  void initState() {
    super.initState();
    TvHeroActions.bind(
      'asian_drama',
      defaultFocus: () => ShellTvFocus.homeHeroPlay,
      heroReveal: () {
        if (!_scroll.hasClients) return;
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      },
      enterFromNavFocus: () {
        ShellTvFocusCoordinator.revealHeroForTab('asian_drama');
        ShellTvFocus.focusHomeHeroPlay();
      },
    );
    WidgetsBinding.instance.addObserver(this);
    AppTheme.themeNotifier.addListener(_onTheme);
    KissKhService.watchHistoryRevision.addListener(_onHistoryChanged);
    // Initial feed load comes from ref.watch in build — do not invalidate
    // here (didChangeDependencies has not cached ProviderContainer yet).
    unawaited(_refreshHistory());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _container = ProviderScope.containerOf(context, listen: false);
  }

  @override
  void dispose() {
    ShellTvFocusCoordinator.clearTab('asian_drama');
    WidgetsBinding.instance.removeObserver(this);
    AppTheme.themeNotifier.removeListener(_onTheme);
    KissKhService.watchHistoryRevision.removeListener(_onHistoryChanged);
    _scroll.dispose();
    super.dispose();
  }

  void _onTheme() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshHistory();
    }
  }

  void _onHistoryChanged() => _refreshHistory();

  Future<void> _refreshHistory() async {
    try {
      final list = await _service.getWatchHistory();
      if (!mounted) return;
      setState(() => _continueWatching = list.take(10).toList());
    } catch (_) {}
  }

  Future<void> _load() async {
    if (!mounted || !shellTabVisible) return;
    final container = _container;
    // Visibility keep-alive can leave State.mounted true while the element is
    // deactivated — never fall back to ProviderScope.containerOf here.
    if (container == null) return;
    final gen = ++_loadGen;
    unawaited(_refreshHistory());
    final done = Completer<void>();
    // Shell show/refresh runs in a post-frame callback; the keep-alive element
    // may still be inactive in that window. Defer so setState is safe.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        if (!mounted || !shellTabVisible || gen != _loadGen) return;
        setState(() {
          _loading = true;
          _error = null;
        });
        container.invalidate(asianDramaFeedProvider);
      } finally {
        if (!done.isCompleted) done.complete();
      }
    });
    return done.future;
  }

  Future<void> _enrichFeed(KdramaHomeFeed feed, int gen) async {
    if (_tmdbHeroSynopsisEnrich) {
      await _enrichFeedFromTmdb(feed, gen);
      return;
    }
    if (_kissKhHeroSynopsisEnrich) {
      await _enrichFeedFromKissKh(feed, gen);
    }
  }

  /// Kept for later - KissKH list endpoints omit synopsis; this hits
  /// `/Drama/{id}` per hero card and shares the Play rate-limit bucket.
  // ignore: unused_element
  Future<void> _enrichFeedFromKissKh(KdramaHomeFeed feed, int gen) async {
    try {
      final hero = _heroCardsFrom(feed);
      if (hero.any((c) => c.description.trim().isEmpty)) {
        final withSynopsis = await _service.enrichCardDescriptions(hero);
        final working = feed.withCardsReplaced(withSynopsis);
        if (!mounted || !shellTabVisible || gen != _loadGen) return;
        setState(() => _feed = working);
      }
    } catch (_) {}
  }

  Future<void> _enrichFeedFromTmdb(KdramaHomeFeed feed, int gen) async {
    try {
      final hero = _heroCardsFrom(feed);
      if (hero.every((c) => c.description.trim().isNotEmpty)) return;

      final enriched = await Future.wait(
        hero.map((card) async {
          if (card.description.trim().isNotEmpty) return card;
          final overview = await _tmdbOverviewForKissKhTitle(
            card.title,
            year: card.year,
            kissKhType: card.type,
            tmdbId: card.tmdbId,
          );
          if (overview == null || overview.isEmpty) return card;
          return card.copyWith(description: overview);
        }),
      );
      if (!mounted || !shellTabVisible || gen != _loadGen) return;
      setState(() => _feed = feed.withCardsReplaced(enriched));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AsianDrama] TMDB hero synopsis enrich failed: $e');
      }
    }
  }

  /// Best-effort TMDB match for a KissKH title (prefer TV, then year).
  Future<String?> _tmdbOverviewForKissKhTitle(
    String title, {
    String? year,
    String? kissKhType,
    int? tmdbId,
  }) async {
    if (tmdbId != null && tmdbId > 0) {
      final preferMovie = KissKhTmdbMatch.preferMovie(kissKhType);
      final primary = preferMovie ? 'movie' : 'tv';
      final secondary = preferMovie ? 'tv' : 'movie';
      for (final mediaType in [primary, secondary]) {
        try {
          final rich = await TmdbApi().getRichDetails(tmdbId, mediaType);
          final overview = rich.movie.overview.trim();
          if (overview.isNotEmpty) return overview;
        } catch (_) {}
      }
    }
    final match = await KissKhTmdbMatch.resolve(
      title: title,
      year: year,
      kissKhType: kissKhType,
    );
    final overview = match?.overview.trim() ?? '';
    if (overview.isEmpty) return null;
    return overview;
  }

  List<KdramaCard> _heroCardsFrom(KdramaHomeFeed feed) {
    if (feed.spotlight.isNotEmpty) return feed.spotlight.take(8).toList();
    if (feed.latest.isNotEmpty) return feed.latest.take(8).toList();
    return feed.trending.take(8).toList();
  }

  List<KdramaCard> get _spotlight {
    final f = _feed;
    if (f == null) return const [];
    return _heroCardsFrom(f);
  }

  void _openDetails(KdramaCard a) {
    openAsianDramaDetails(context, a).then((_) => _refreshHistory());
  }

  Future<void> _resumeWatch(Map<String, dynamic> entry) async {
    final id = (entry['id'] as num?)?.toInt();
    if (id == null || _resumingDramaId != null) return;

    setState(() => _resumingDramaId = id);
    try {
      final epNum = (entry['episodeNumber'] as num?)?.toDouble() ?? 1.0;
      final epId = (entry['episodeId'] as num?)?.toInt();
      final startPosition = KissKhService.startPositionFromHistory(entry);
      final card = _cardFromHistoryEntry(entry);
      var episodes = KissKhService.episodesFromHistory(entry);

      // Legacy rows: no episode snapshot - fetch live list (details screen path).
      if (episodes.isEmpty) {
        KdramaDetails details;
        try {
          details = await _service.getDetails(id);
        } catch (e) {
          if ('$e'.contains('→ 429')) {
            await Future.delayed(const Duration(milliseconds: 800));
            details = await _service.getDetails(id);
          } else {
            rethrow;
          }
        }
        if (!mounted) return;
        episodes = details.episodes;
        final ep = details.episodeForResume(
          episodeNumber: epNum,
          episodeId: epId,
        );
        if (ep == null) {
          openAsianDramaDetails(context, details.toCard());
          return;
        }
        openAsianDramaPlayer(
          context,
          drama: details.toCard(),
          episode: ep,
          allEpisodes: episodes,
          startPosition: startPosition,
        ).then((_) => _refreshHistory());
        return;
      }

      // Identical launch args to details → Resume.
      final ep = KissKhService.matchResumeEpisode(
        episodes: episodes,
        episodeNumber: epNum,
        episodeId: epId,
      );
      if (ep == null) {
        openAsianDramaDetails(context, card);
        return;
      }

      openAsianDramaPlayer(
        context,
        drama: card,
        episode: ep,
        allEpisodes: episodes,
        startPosition: startPosition,
      ).then((_) => _refreshHistory());
    } catch (e) {
      if (!mounted) return;
      final raw = '$e';
      if (raw.contains('→ 429')) {
        ForjaToast.error(
          'kisskh is busy - wait a moment or open details and Resume.',
        );
      } else {
        ForjaToast.error('Resume failed: $e');
      }
    } finally {
      if (mounted) setState(() => _resumingDramaId = null);
    }
  }

  Future<void> _removeFromHistory(Map<String, dynamic> entry) async {
    final id = (entry['id'] as num?)?.toInt();
    if (id == null) return;
    await _service.removeFromHistory(id);
    if (!mounted) return;
    setState(() {
      _continueWatching.removeWhere((e) => (e['id'] as num?)?.toInt() == id);
    });
  }

  KdramaCard _cardFromHistoryEntry(Map<String, dynamic> entry) {
    return KdramaCard(
      id: (entry['id'] as num).toInt(),
      title: entry['title'] as String? ?? '',
      cover: KissKhService.normalizeCoverUrl(entry['cover'] as String? ?? ''),
    );
  }

  HubPosterCard _dramaPosterCard(
    KdramaCard card, {
    int? rank,
    int? listIndex,
    String? tvRowId,
  }) {
    final subtitle = [
      if (card.year != null) card.year!,
      if (card.cardMediaLabel != null) card.cardMediaLabel!,
    ].join('  •  ');
    return HubPosterCard(
      imageUrl: card.cover,
      title: card.title,
      subtitle: subtitle.isEmpty ? null : subtitle,
      rank: rank,
      listIndex: listIndex,
      tvTabId: 'asian_drama',
      tvRowId: tvRowId,
      // KissKH list thumbs are 16:9 banners (often TMDB w1000_and_h563_face).
      aspect: HubPosterAspect.landscape,
      onTap: () => _openDetails(card),
      listTarget: HubListFollowTarget.drama(
        kisskhId: card.id,
        title: card.title,
        posterPath: card.cover,
        releaseDate: card.year ?? '',
        kissKhType: card.type,
      ),
    );
  }

  List<HubHeroSlide> _heroSlides(List<KdramaCard> spotlight) {
    return spotlight
        .map(
          (a) {
            final label = a.label?.trim();
            final labelLower = label?.toLowerCase() ?? '';
            final isUpcoming = labelLower == 'upcoming';
            String? statusChip;
            String? upcomingReleaseLabel;
            if (isUpcoming) {
              statusChip = 'Upcoming';
              if (a.year != null && a.year!.isNotEmpty) {
                upcomingReleaseLabel = a.year;
              }
            } else if (label != null && label.isNotEmpty) {
              if (label.length >= 10 && label.contains('-')) {
                statusChip = 'Upcoming';
                upcomingReleaseLabel =
                    KissKhService.formatReleaseDateLabel(label);
              } else {
                statusChip = label;
              }
            }
            return HubHeroSlide(
              id: '${a.id}',
              title: a.title,
              imageUrl: a.cover,
              overview: a.description.trim(),
              year: a.year,
              badge: a.heroMediaBadge,
              statusChip: statusChip,
              isUpcoming: isUpcoming ||
                  statusChip == 'Upcoming' ||
                  (upcomingReleaseLabel?.isNotEmpty ?? false),
              upcomingReleaseLabel: upcomingReleaseLabel,
              tmdbId: a.tmdbId,
              tmdbMediaType: KissKhTmdbMatch.preferMovie(a.type) ? 'movie' : 'tv',
              onDetails: () => _openDetails(a),
              listTarget: HubListFollowTarget.drama(
                kisskhId: a.id,
                title: a.title,
                posterPath: a.cover,
                releaseDate: a.year ?? '',
                kissKhType: a.type,
              ),
            );
          },
        )
        .toList();
  }

  // ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    super.build(context);
    ref.listen(asianDramaFeedProvider, (_, next) {
      if (!mounted || !shellTabVisible) return;
      next.when(
        loading: () {
          if (!_loading) setState(() => _loading = true);
        },
        error: (e, _) {
          setState(() {
            _loading = false;
            _error = '$e';
          });
        },
        data: (feed) {
          setState(() {
            _feed = feed;
            _loading = false;
            _error = null;
          });
          markShellTabFresh();
          unawaited(_enrichFeed(feed, _loadGen));
        },
      );
    });
    ref.watch(asianDramaFeedProvider);
    return TvFocusGraph(
      tabId: 'asian_drama',
      child: ValueListenableBuilder<AppThemePreset>(
      valueListenable: AppTheme.themeNotifier,
      builder: (context, _, _) {
        final fullHero = hubIsFullCinematicHero(context);
        final usesShell = hubUsesShellLayout(context);
        final latestList = _feed?.latest ?? const <KdramaCard>[];
        final latestOnHero = usesShell && fullHero && latestList.isNotEmpty;
        final latestAsCatalogRow = !latestOnHero && latestList.isNotEmpty;
        final latestOrder = _latestOrder(latestOnHero: latestOnHero);
        final catalogBase = _catalogRowBase(
          latestOnHero: latestOnHero,
          latestAsCatalogRow: latestAsCatalogRow,
        );
        void focusHeroPlay() {
          ShellTvFocusCoordinator.revealHeroForTab('asian_drama');
          ShellTvFocus.focusHomeHeroPlay();
        }

        final latestSection = latestOnHero
            ? HubCatalogSection<KdramaCard>(
                title: 'Latest Update',
                items: latestList,
                compactTop: true,
                cardAspect: HubPosterAspect.landscape,
                tvTabId: 'asian_drama',
                tvRowId: 'latest',
                tvRowOrder: latestOrder,
                tvFocusUp: focusHeroPlay,
                cardBuilder: (context, card, index) =>
                    _dramaPosterCard(card, listIndex: index, tvRowId: 'latest'),
              )
            : null;

        return _error != null && !_loading
            ? _buildError()
            : RefreshIndicator(
                color: ForjaShellColors.sectionAccent,
                backgroundColor: AppTheme.bgCard,
                onRefresh: _load,
                child: ColoredBox(
                  color: AppTheme.bgDark,
                  child: CustomScrollView(
                    controller: _scroll,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    slivers: [
                      if (_loading)
                        ...homeHubLoadingSlivers(
                          context,
                          heroShimmer: homeCinematicHeroShimmer(
                            context,
                            pageBottomBleed: true,
                          ),
                          rows: kHomeHubAsianDramaLoadingRows,
                          catalogCardWidth: HubPosterCard.cardWidth(
                            context,
                            aspect: HubPosterAspect.landscape,
                          ),
                          catalogCardHeight: HubPosterCard.cardHeight(
                            context,
                            aspect: HubPosterAspect.landscape,
                          ),
                        )
                      else ...[
                        SliverToBoxAdapter(
                          child: HomeCinematicHero.hub(
                            slides: _heroSlides(_spotlight),
                            tvTabId: 'asian_drama',
                            scrollController: _scroll,
                            firstCatalogRowHeight: latestSection == null
                                ? null
                                : HubCatalogSection.sectionHeight(
                                    context,
                                    compactTop: true,
                                    cardAspect: HubPosterAspect.landscape,
                                  ),
                            pageBottomChild: latestSection,
                          ),
                        ),
                        if (_continueWatching.isNotEmpty)
                          hubRowSliver(
                            context,
                            _buildContinueWatching(
                              tvRowOrder: _continueOrder(
                                latestOnHero: latestOnHero,
                              ),
                              // Under bleed Latest: ↑ goes to Latest.
                              // Otherwise Continue is first → hero Play.
                              tvFocusUp: latestOnHero ? null : focusHeroPlay,
                            ),
                            isFirstAfterHero: latestSection == null,
                          ),
                        if (latestAsCatalogRow)
                          hubRowSliver(
                            context,
                            HubCatalogSection<KdramaCard>(
                              title: 'Latest Update',
                              items: latestList,
                              compactTop: _continueWatching.isEmpty,
                              cardAspect: HubPosterAspect.landscape,
                              tvTabId: 'asian_drama',
                              tvRowId: 'latest',
                              tvRowOrder: latestOrder,
                              // Continue sits above - don't skip to hero.
                              cardBuilder: (context, card, index) =>
                                  _dramaPosterCard(
                                    card,
                                    listIndex: index,
                                    tvRowId: 'latest',
                                  ),
                            ),
                            isFirstAfterHero: _continueWatching.isEmpty,
                          ),
                        if ((_feed?.trending ?? const []).isNotEmpty)
                          hubRowSliver(
                            context,
                            HubCatalogSection<KdramaCard>(
                              title: 'Trending',
                              items: _feed!.trending,
                              cardAspect: HubPosterAspect.landscape,
                              tvTabId: 'asian_drama',
                              tvRowId: 'trending',
                              tvRowOrder: catalogBase + 0,
                              cardBuilder: (context, card, index) =>
                                  _dramaPosterCard(
                                    card,
                                    listIndex: index,
                                    tvRowId: 'trending',
                                  ),
                            ),
                            isFirstAfterHero: false,
                          ),
                        if ((_feed?.topRated ?? const []).isNotEmpty)
                          hubRowSliver(
                            context,
                            HubCatalogSection<KdramaCard>(
                              title: 'Top Rated',
                              items: _feed!.topRated,
                              showRank: true,
                              cardAspect: HubPosterAspect.landscape,
                              tvTabId: 'asian_drama',
                              tvRowId: 'top-rated',
                              tvRowOrder: catalogBase + 1,
                              cardBuilder: (context, card, index) =>
                                  _dramaPosterCard(
                                    card,
                                    rank: index + 1,
                                    listIndex: index,
                                    tvRowId: 'top-rated',
                                  ),
                            ),
                            isFirstAfterHero: false,
                          ),
                        if ((_feed?.mostViewed ?? const []).isNotEmpty)
                          hubRowSliver(
                            context,
                            HubCatalogSection<KdramaCard>(
                              title: 'Most Viewed',
                              items: _feed!.mostViewed,
                              cardAspect: HubPosterAspect.landscape,
                              tvTabId: 'asian_drama',
                              tvRowId: 'most-viewed',
                              tvRowOrder: catalogBase + 2,
                              cardBuilder: (context, card, index) =>
                                  _dramaPosterCard(
                                    card,
                                    listIndex: index,
                                    tvRowId: 'most-viewed',
                                  ),
                            ),
                            isFirstAfterHero: false,
                          ),
                        if ((_feed?.anime ?? const []).isNotEmpty)
                          hubRowSliver(
                            context,
                            HubCatalogSection<KdramaCard>(
                              title: 'Anime',
                              items: _feed!.anime,
                              cardAspect: HubPosterAspect.landscape,
                              tvTabId: 'asian_drama',
                              tvRowId: 'anime',
                              tvRowOrder: catalogBase + 3,
                              cardBuilder: (context, card, index) =>
                                  _dramaPosterCard(
                                    card,
                                    listIndex: index,
                                    tvRowId: 'anime',
                                  ),
                            ),
                            isFirstAfterHero: false,
                          ),
                        if ((_feed?.upcoming ?? const []).isNotEmpty)
                          hubRowSliver(
                            context,
                            HubCatalogSection<KdramaCard>(
                              title: 'Upcoming',
                              items: _feed!.upcoming,
                              cardAspect: HubPosterAspect.landscape,
                              tvTabId: 'asian_drama',
                              tvRowId: 'upcoming',
                              tvRowOrder: catalogBase + 4,
                              cardBuilder: (context, card, index) =>
                                  _dramaPosterCard(
                                    card,
                                    listIndex: index,
                                    tvRowId: 'upcoming',
                                  ),
                            ),
                            isFirstAfterHero: false,
                          ),
                      ],
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: shellTvCatalogScrollBottomGap(context),
                        ),
                      ),
                    ],
                  ),
                ),
              );
      },
    ),
    );
  }

  // ─── Error ────────────────────────────────────────────────────
  Widget _buildError() {
    return ShellErrorRetryPanel(
      message: 'Failed to load:\n$_error',
      onRetry: _load,
      statusIconSize: 56,
    );
  }

  // ─── Continue Watching ────────────────────────────────────────
  Widget _buildContinueWatching({
    required int tvRowOrder,
    VoidCallback? tvFocusUp,
  }) {
    return AsianDramaContinueWatchingSection(
      entries: _continueWatching,
      resumingDramaId: _resumingDramaId,
      onResume: _resumeWatch,
      onRemove: _removeFromHistory,
      onOpenDetails: _openDetails,
      cardFromEntry: _cardFromHistoryEntry,
      tvRowOrder: tvRowOrder,
      tvFocusUp: tvFocusUp,
    );
  }
}
