// kisskh.co (Asian Drama) hub — cinematic hero + poster rows (same shell as Home).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/features/asian_drama/catalog/kisskh_service.dart';
import 'package:forja/features/asian_drama/widgets/asian_drama_continue_watching_section.dart';
import 'package:forja/shared/widgets/hub/hub_catalog_section.dart';
import 'package:forja/shared/widgets/hub/hub_cinematic_hero.dart';
import 'package:forja/shared/widgets/hub/hub_poster_card.dart';
import 'asian_drama_details_screen.dart';
import 'asian_drama_player_screen.dart';
import 'asian_drama_search_screen.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/widgets/home_loading_skeleton.dart';
import 'package:forja/shell/app_router.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';
import 'package:forja/shared/widgets/shell_error_retry_panel.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';

class AsianDramaScreen extends StatefulWidget {
  const AsianDramaScreen({super.key});

  @override
  State<AsianDramaScreen> createState() => _AsianDramaScreenState();
}

class _AsianDramaScreenState extends State<AsianDramaScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final KissKhService _service = KissKhService();
  final ScrollController _scroll = ScrollController();

  KdramaHomeFeed? _feed;
  bool _loading = true;
  String? _error;
  int _loadGen = 0;

  List<Map<String, dynamic>> _continueWatching = [];
  int? _resumingDramaId;

  int get _catalogRowBase => _continueWatching.isNotEmpty ? 1 : 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    ShellTvFocusCoordinator.registerTabDefaults(
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
    );
    WidgetsBinding.instance.addObserver(this);
    AppTheme.themeNotifier.addListener(_onTheme);
    KissKhService.watchHistoryRevision.addListener(_onHistoryChanged);
    _load();
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
    final gen = ++_loadGen;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _service.getHome(),
        _service.getWatchHistory(),
      ]);
      if (!mounted || gen != _loadGen) return;
      final feed = results[0] as KdramaHomeFeed;
      setState(() {
        _feed = feed;
        _continueWatching =
            (results[1] as List<Map<String, dynamic>>).take(10).toList();
        _loading = false;
      });
      // List endpoints omit year/type — fill from details in the background.
      unawaited(_enrichFeed(feed, gen));
    } catch (e) {
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _enrichFeed(KdramaHomeFeed feed, int gen) async {
    try {
      final enriched = await _service.enrichHomeFeed(feed);
      if (!mounted || gen != _loadGen) return;
      setState(() => _feed = enriched);
    } catch (_) {}
  }

  List<KdramaCard> get _spotlight {
    final f = _feed;
    if (f == null) return const [];
    if (f.spotlight.isNotEmpty) return f.spotlight.take(8).toList();
    if (f.latest.isNotEmpty) return f.latest.take(8).toList();
    return f.trending.take(8).toList();
  }

  void _openDetails(KdramaCard a) {
    openAsianDramaDetails(context, a).then((_) => _refreshHistory());
  }

  void _openSearch() {
    pushShellRoute(
      context,
      AppRouter.slideShellRoute((_) => const AsianDramaSearchScreen()),
    );
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

      // Legacy rows: no episode snapshot — fetch live list (details screen path).
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
        ForjaToast.error('kisskh is busy — wait a moment or open details and Resume.');
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
      cover: entry['cover'] as String? ?? '',
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
      badge: card.label,
      rank: rank,
      listIndex: listIndex,
      tvRowId: tvRowId,
      onTap: () => _openDetails(card),
    );
  }

  List<HubHeroSlide> _heroSlides(List<KdramaCard> spotlight) {
    return spotlight
        .map(
          (a) => HubHeroSlide(
            id: '${a.id}',
            title: a.title,
            imageUrl: a.cover,
            year: a.year,
            badge: a.heroMediaBadge,
            onPlay: () => _openDetails(a),
            onDetails: () => _openDetails(a),
          ),
        )
        .toList();
  }

  // ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ValueListenableBuilder<AppThemePreset>(
      valueListenable: AppTheme.themeNotifier,
      builder: (context, _, _) {
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
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            slivers: [
                              if (_loading)
                                ...homeHubLoadingSlivers(
                                  context,
                                  heroShimmer: homeCinematicHeroShimmer(context),
                                  rows: kHomeHubAsianDramaLoadingRows,
                                )
                              else ...[
                                SliverToBoxAdapter(
                                  child: HubCinematicHero(
                                    slides: _heroSlides(_spotlight),
                                    onSearch: _openSearch,
                                    tvTabId: 'asian_drama',
                                  ),
                                ),
                                if (_continueWatching.isNotEmpty)
                                  hubRowSliver(context,
                                    _buildContinueWatching(),
                                    isFirstAfterHero: true,
                                  ),
                                if ((_feed?.latest ?? const []).isNotEmpty)
                                  hubRowSliver(context,
                                    HubCatalogSection<KdramaCard>(
                                      title: 'Latest Update',
                                      items: _feed!.latest,
                                      compactTop: _continueWatching.isEmpty,
                                      tvTabId: 'asian_drama',
                                      tvRowId: 'latest',
                                      tvRowOrder: _catalogRowBase + 0,
                                      tvFocusUp: () =>
                                          ShellTvFocusCoordinator.focusHero(
                                        tabId: 'asian_drama',
                                      ),
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
                                  hubRowSliver(context,
                                    HubCatalogSection<KdramaCard>(
                                      title: 'Trending',
                                      items: _feed!.trending,
                                      tvTabId: 'asian_drama',
                                      tvRowId: 'trending',
                                      tvRowOrder: _catalogRowBase + 1,
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
                                  hubRowSliver(context,
                                    HubCatalogSection<KdramaCard>(
                                      title: 'Top Rated',
                                      items: _feed!.topRated,
                                      showRank: true,
                                      tvTabId: 'asian_drama',
                                      tvRowId: 'top-rated',
                                      tvRowOrder: _catalogRowBase + 2,
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
                                  hubRowSliver(context,
                                    HubCatalogSection<KdramaCard>(
                                      title: 'Most Viewed',
                                      items: _feed!.mostViewed,
                                      tvTabId: 'asian_drama',
                                      tvRowId: 'most-viewed',
                                      tvRowOrder: _catalogRowBase + 3,
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
                                  hubRowSliver(context,
                                    HubCatalogSection<KdramaCard>(
                                      title: 'Anime',
                                      items: _feed!.anime,
                                      tvTabId: 'asian_drama',
                                      tvRowId: 'anime',
                                      tvRowOrder: _catalogRowBase + 4,
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
                                  hubRowSliver(context,
                                    HubCatalogSection<KdramaCard>(
                                      title: 'Upcoming',
                                      items: _feed!.upcoming,
                                      tvTabId: 'asian_drama',
                                      tvRowId: 'upcoming',
                                      tvRowOrder: _catalogRowBase + 5,
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

  // ─── Error ────────────────────────────────────────────────────
  Widget _buildError() {
    return ShellErrorRetryPanel(
      message: 'Failed to load:\n$_error',
      onRetry: _load,
      statusIconSize: 56,
    );
  }
  // ─── Continue Watching ────────────────────────────────────────
  Widget _buildContinueWatching() {
    return AsianDramaContinueWatchingSection(
      entries: _continueWatching,
      resumingDramaId: _resumingDramaId,
      onResume: _resumeWatch,
      onRemove: _removeFromHistory,
      onOpenDetails: _openDetails,
      cardFromEntry: _cardFromHistoryEntry,
    );
  }
}
