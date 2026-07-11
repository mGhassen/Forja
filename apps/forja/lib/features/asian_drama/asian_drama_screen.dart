// kisskh.co (Asian Drama) hub — cinematic hero + poster rows (same shell as Home).

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:forja/features/asian_drama/catalog/kisskh_service.dart';
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
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
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
      AppRouter.slideRoute((_) => const AsianDramaSearchScreen()),
    );
  }

  Future<void> _resumeWatch(Map<String, dynamic> entry) async {
    try {
      final id = (entry['id'] as num).toInt();
      final epNum = (entry['episodeNumber'] as num?)?.toDouble() ?? 1.0;
      final title = entry['title'] as String? ?? '';
      final cover = entry['cover'] as String? ?? '';
      final posMs = (entry['positionMs'] as num?)?.toInt() ?? 0;
      final durMs = (entry['durationMs'] as num?)?.toInt() ?? 0;
      Duration? startPosition;
      if (posMs > 5000) {
        final clamped = (durMs > 0 && posMs > durMs - 30000)
            ? (durMs - 30000)
            : posMs;
        startPosition =
            Duration(milliseconds: (clamped - 3000).clamp(0, 1 << 31));
      }

      final card = KdramaCard(id: id, title: title, cover: cover);
      final details = await _service.getDetails(id);
      if (!mounted) return;
      KdramaEpisode? ep;
      try {
        ep = details.episodes.firstWhere((e) => e.number == epNum);
      } catch (_) {}
      ep ??= details.episodes.isNotEmpty ? details.episodes.first : null;
      if (ep == null) {
        openAsianDramaDetails(context, card);
        return;
      }
      openAsianDramaPlayer(
        context,
        drama: card,
        episode: ep!,
        allEpisodes: details.episodes,
        startPosition: startPosition,
      ).then((_) => _refreshHistory());
    } catch (e) {
      if (!mounted) return;
      ForjaToast.error('Resume failed: $e');
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                color: ForjaShellColors.sectionAccent, size: 56),
            const SizedBox(height: 14),
            Text(
              'Failed to load:\n$_error',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
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
  // ─── Continue Watching ────────────────────────────────────────
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
        ),
        SizedBox(
          height: _AsianDramaContinueWatchingCard.cardHeight(context),
          child: Builder(
            builder: (context) {
              shellTvRegisterRow(
                tabId: 'asian_drama',
                rowId: 'continue-watching',
                sortOrder: 0,
                itemCount: _continueWatching.length,
                onFocusUp: () => ShellTvFocusCoordinator.focusHero(
                  tabId: 'asian_drama',
                ),
              );
              return FocusTraversalGroup(
                policy: OrderedTraversalPolicy(),
                child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            clipBehavior: Clip.none,
            padding: EdgeInsets.symmetric(horizontal: hPad),
            itemCount: _continueWatching.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (_, i) {
              final entry = _continueWatching[i];
              final card = _cardFromHistoryEntry(entry);
              return _AsianDramaContinueWatchingCard(
                listIndex: i,
                entry: entry,
                onTap: () => _resumeWatch(entry),
                onRemove: () => _removeFromHistory(entry),
                onInfo: () => _openDetails(card),
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
}
class _AsianDramaContinueWatchingCard extends StatefulWidget {
  final Map<String, dynamic> entry;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final VoidCallback onInfo;
  final int listIndex;

  const _AsianDramaContinueWatchingCard({
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
  State<_AsianDramaContinueWatchingCard> createState() =>
      _AsianDramaContinueWatchingCardState();
}

class _AsianDramaContinueWatchingCardState
    extends State<_AsianDramaContinueWatchingCard> {
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
    final cover = widget.entry['cover'] as String?;
    final title = widget.entry['title'] as String? ?? '';
    final epNum = (widget.entry['episodeNumber'] as num?)?.toDouble() ?? 1.0;
    final totalEps = (widget.entry['totalEpisodes'] as num?)?.toInt() ?? 0;
    final position = (widget.entry['positionMs'] as num?)?.toInt() ?? 0;
    final duration = (widget.entry['durationMs'] as num?)?.toInt() ?? 0;
    final progress =
        duration > 0 ? (position / duration).clamp(0.0, 1.0) : 0.0;
    final remaining = duration > 0
        ? Duration(milliseconds: duration - position)
        : Duration.zero;
    final remainingText =
        remaining.inMinutes > 0 ? '${remaining.inMinutes}m left' : '';
    final epLabel = epNum == epNum.truncateToDouble()
        ? epNum.toInt().toString()
        : epNum.toString();
    final subtitle = totalEps > 0
        ? 'Ep $epLabel / $totalEps'
        : 'Ep $epLabel';
    final cardWidth = _AsianDramaContinueWatchingCard.cardWidth(context);
    final cardHeight = _AsianDramaContinueWatchingCard.cardHeight(context);

    return shellFocusableTap(
      context: context,
      onTap: widget.onTap,
      listIndex: widget.listIndex,
      tvTabId: 'asian_drama',
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
                      child: cover != null && cover.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: cover,
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
                                  title,
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
