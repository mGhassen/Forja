import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rust/rust.dart';
import 'package:forja/features/home/widgets/home_movie_section.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/tv/media_details_tv_scope.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';
import 'package:forja/shared/widgets/hero/hero_pill_buttons.dart';
import 'package:forja/shared/widgets/hero/hero_title.dart';
import 'package:forja/shared/widgets/hero/rotating_hero_backdrop.dart';
import 'package:forja/shared/widgets/hero_overview_text.dart';
import 'package:forja/shared/widgets/home_loading_skeleton.dart';
import 'package:forja/features/asian_drama/catalog/kisskh_tmdb_match.dart';
import 'package:forja/shared/catalog/hub_tmdb_enrich_cache.dart';
import 'package:forja/shared/services/hub_list_follow.dart';
import 'package:forja/shared/widgets/hub/hub_catalog_section.dart';
import 'package:forja/shared/widgets/hub_details/hub_details_play_row.dart';
import 'package:forja/shared/widgets/hub_list_status_hero.dart';
import 'package:forja/shared/widgets/my_list_button.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:forja/shell/shell_bus.dart';

bool hubIsFullCinematicHero(BuildContext context) =>
    homeIsFullCinematicHero(context);

bool hubUsesShellLayout(BuildContext context) =>
    ShellScope.profileOf(context) != ShellProfile.mobile;

String hubAnimeStatusLabel(String anilistStatus) {
  switch (anilistStatus.trim().toUpperCase()) {
    case 'RELEASING':
      return 'Airing';
    case 'FINISHED':
      return 'Completed';
    case 'NOT_YET_RELEASED':
      return 'Upcoming';
    case 'CANCELLED':
      return 'Cancelled';
    case 'HIATUS':
      return 'Hiatus';
    default:
      return anilistStatus.replaceAll('_', ' ');
  }
}

class HubHeroSlide {
  const HubHeroSlide({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.overview = '',
    this.rating,
    this.year,
    this.badge,
    this.statusChip,
    this.upcomingReleaseLabel,
    this.isUpcoming = false,
    this.genres = const [],
    this.imageFit = BoxFit.cover,
    this.imageAlignment = Alignment.centerRight,
    this.tmdbId,
    this.tmdbMediaType = 'tv',
    this.movie,
    this.listTarget,
    required this.onDetails,
  });

  final String id;
  final String title;
  final String imageUrl;
  final String overview;
  final double? rating;
  final String? year;
  final String? badge;
  /// Human status for the meta row (Upcoming, Airing, …).
  final String? statusChip;
  /// Premiere hint for [HubDetailsUpcomingNotice] when not playable yet.
  final String? upcomingReleaseLabel;
  final bool isUpcoming;
  final List<String> genres;
  final BoxFit imageFit;
  final Alignment imageAlignment;
  final int? tmdbId;
  final String tmdbMediaType;
  /// Home / TMDB hub — drives [MyListHeroStatusPill] (pin).
  final Movie? movie;
  final HubListFollowTarget? listTarget;
  final VoidCallback onDetails;
}

class _HeroItem {
  const _HeroItem({
    required this.id,
    required this.title,
    required this.overview,
    required this.voteAverage,
    required this.releaseDate,
    required this.mediaType,
    this.badgeLabel,
    this.statusChip,
    this.upcomingReleaseLabel,
    this.isUpcoming = false,
    this.imageFit = BoxFit.cover,
    this.imageAlignment = Alignment.centerRight,
    this.genres = const [],
    this.tmdbId,
    this.tmdbMediaType = 'tv',
    required this.backdropUrls,
    required this.onDetails,
    this.movie,
    this.listTarget,
  });

  final String id;
  final String title;
  final String overview;
  final double voteAverage;
  final String releaseDate;
  final String mediaType;
  final String? badgeLabel;
  final String? statusChip;
  final String? upcomingReleaseLabel;
  final bool isUpcoming;
  final BoxFit imageFit;
  final Alignment imageAlignment;
  final List<String> genres;
  final int? tmdbId;
  final String tmdbMediaType;
  final List<String> backdropUrls;
  final VoidCallback onDetails;
  final Movie? movie;
  final HubListFollowTarget? listTarget;

  factory _HeroItem.fromMovie(Movie movie, List<String> backdropUrls) {
    return _HeroItem(
      id: '${movie.id}',
      title: movie.title,
      overview: movie.overview,
      voteAverage: movie.voteAverage,
      releaseDate: movie.releaseDate,
      mediaType: movie.mediaType,
      genres: movie.genres,
      backdropUrls: backdropUrls,
      onDetails: () {},
      movie: movie,
    );
  }

  factory _HeroItem.fromSlide(HubHeroSlide slide) {
    final imageUrl = slide.imageUrl.trim();
    return _HeroItem(
      id: slide.id,
      title: slide.title,
      overview: slide.overview,
      voteAverage: slide.rating ?? 0,
      releaseDate: slide.year ?? '',
      mediaType: slide.movie?.mediaType ?? '',
      badgeLabel: slide.badge,
      statusChip: slide.statusChip,
      upcomingReleaseLabel: slide.upcomingReleaseLabel,
      isUpcoming: slide.isUpcoming,
      imageFit: slide.imageFit,
      imageAlignment: slide.imageAlignment,
      genres: slide.genres,
      tmdbId: slide.tmdbId ?? slide.movie?.id,
      tmdbMediaType: slide.tmdbMediaType,
      backdropUrls: imageUrl.isEmpty ? const [] : [imageUrl],
      onDetails: slide.onDetails,
      movie: slide.movie,
      listTarget: slide.listTarget,
    );
  }
}

bool homeIsFullCinematicHero(BuildContext context) {
  if (ShellScope.metricsOf(context).usesTvDensity) return true;
  return MediaQuery.sizeOf(context).width >= ShellTokens.heroDesktopMinBodyWidth;
}

double homeHeroTextTopInset(BuildContext context) =>
    ShellTokens.heroTextColumnTopInsetDesktop;

/// Bridges TV focus from catalog rows back to the hero details button.
class HomeHeroController {
  VoidCallback? revealPlayFocus;
}

/// Shared cinematic hero — Home, Anime, and Asian Drama use this widget.
class HomeCinematicHero extends StatefulWidget {
  const HomeCinematicHero({
    super.key,
    required this.moviesFuture,
    required this.compact,
    required this.usesShellHomeLayout,
    required this.scrollController,
    required this.controller,
    required this.onOpenDetails,
    this.pageBottomChild,
    this.tvTabId = 'home',
    this.bleedRowId,
    this.firstCatalogRowHeight,
  })  : slides = null;

  const HomeCinematicHero.hub({
    super.key,
    required this.slides,
    this.pageBottomChild,
    this.tvTabId = 'anime',
    this.bleedRowId,
    this.firstCatalogRowHeight,
    this.scrollController,
  })  : moviesFuture = null,
        compact = false,
        usesShellHomeLayout = true,
        controller = null,
        onOpenDetails = null;

  final Future<List<Movie>>? moviesFuture;
  final List<HubHeroSlide>? slides;
  final bool compact;
  final bool usesShellHomeLayout;
  final ScrollController? scrollController;
  final HomeHeroController? controller;
  final Future<void> Function(Movie movie)? onOpenDetails;
  final String tvTabId;
  final String? bleedRowId;
  final double? firstCatalogRowHeight;

  /// First catalog row rendered on the extended page backdrop (desktop/TV).
  final Widget? pageBottomChild;

  @override
  State<HomeCinematicHero> createState() => _HomeCinematicHeroState();
}

class _HomeCinematicHeroState extends State<HomeCinematicHero> {
  static const int _heroLoopLength = 10000;
  static const int _heroLoopStart = 5000;

  /// Home hero - stronger left vignette than hub/details (text column legibility).
  static const double _heroGradientSolidEndFraction = 0.02;
  static const double _heroGradientFadeMid1Alpha = 0.82;
  static const double _heroGradientFadeMid2Alpha = 0.2;

  /// Soft black softener at the carousel seam while swiping.
  static const double _heroSeamScrimWidth = 120;
  static const double _heroSeamTransitionEpsilon = 0.015;
  /// Trailing (right) join fade only - never paint a leading/left edge
  /// (that sits under the hero text fade and looks dirty).
  static const double _heroSlideEdgeGradientFraction = 0.10;
  /// Right-edge opacity vs viewport X of that edge (0 = left, 1 = right).
  /// Fade out while sliding left so the join softener never enters the hero fade.
  static const double _heroRightEdgeFadeEnd = 0.14;
  static const double _heroRightEdgeFadeStart = 0.46;

  bool get _isHub => widget.slides != null;

  bool get _compact {
    if (_isHub) {
      if (ShellScope.metricsOf(context).usesTvDensity) return false;
      return MediaQuery.sizeOf(context).width <
          ShellTokens.heroDesktopMinBodyWidth;
    }
    return widget.compact;
  }

  final TmdbApi _api = TmdbApi();
  final PageController _heroController =
      PageController(initialPage: _heroLoopStart);
  final FocusNode _tvHeroPlayFocus = FocusNode(debugLabel: 'hero-play');
  final FocusNode _tvHeroGalleryFocus = FocusNode(debugLabel: 'hero-gallery');

  Timer? _heroTimer;
  int _heroIndex = 0;
  final Map<String, String> _heroLogos = {};
  final Map<String, String> _heroOverviews = {};
  final Map<String, double> _heroRatings = {};
  final Map<String, List<String>> _heroBackdropUrls = {};
  final Set<String> _hubEnrichInflight = {};
  bool _heroHeightSyncScheduled = false;
  double? _heroPageViewportWidth;
  List<Movie>? _lastHeroMovies;

  void _syncSharedHeroFocusNodes() {
    if (ShellTvFocus.currentNavTabId != widget.tvTabId) return;
    ShellTvFocus.homeHeroPlay = _tvHeroPlayFocus;
    ShellTvFocus.homeHeroGallery = _tvHeroGalleryFocus;
  }

  @override
  void initState() {
    super.initState();
    _syncSharedHeroFocusNodes();
    TvHeroActions.bind(
      widget.tvTabId,
      defaultFocus: () => _tvHeroPlayFocus,
      heroReveal: _scrollHeroIntoView,
    );
    if (!_isHub) {
      widget.controller?.revealPlayFocus = _revealedHeroPlayFocus;
    }
    _startHeroTimer();
  }

  /// Unfocus + defer dispose so FocusManager's microtask notify does not hit
  /// a disposed node (TV D-pad: "FocusNode was used after being disposed").
  void _disposeFocusNode(FocusNode node) {
    if (node.hasFocus) {
      node.unfocus();
      scheduleMicrotask(node.dispose);
    } else {
      node.dispose();
    }
  }

  @override
  void dispose() {
    TvHeroActions.unbind(widget.tvTabId);
    if (ShellTvFocus.homeHeroPlay == _tvHeroPlayFocus) {
      ShellTvFocus.homeHeroPlay = null;
    }
    if (ShellTvFocus.homeHeroGallery == _tvHeroGalleryFocus) {
      ShellTvFocus.homeHeroGallery = null;
    }
    final heightNotifier = _heroHeightNotifier();
    if (heightNotifier.value != 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        heightNotifier.value = 0;
      });
    }
    _heroTimer?.cancel();
    _heroController.dispose();
    _disposeFocusNode(_tvHeroPlayFocus);
    _disposeFocusNode(_tvHeroGalleryFocus);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HomeCinematicHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldCount = oldWidget.slides?.length ?? 0;
    final newCount = widget.slides?.length ?? 0;
    if (_isHub && oldCount != newCount) {
      _startHeroTimer();
    }
    if (_isHub && !identical(oldWidget.slides, widget.slides)) {
      // New pack metas (e.g. after chrome filter) — re-enrich.
      _hubEnrichInflight.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    // KeepAlive tabs all mount - only the active tab owns shared nodes.
    _syncSharedHeroFocusNodes();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _publishHeroHeight();
    });

    if (_isHub) {
      final slides = widget.slides!;
      if (slides.isEmpty) {
        return homeCinematicHeroShimmer(
          context,
          pageBottomBleed: widget.pageBottomChild != null,
        );
      }
      final items = slides.map(_HeroItem.fromSlide).toList();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_enrichHubHeroSlides(slides));
      });
      return _buildCinematicHeroBlock(items, compact: _compact);
    }

    return FutureBuilder<List<Movie>>(
      future: widget.moviesFuture,
      builder: (context, snapshot) {
        // Keep last hero while a new future is resolving — never blank the shell.
        final movies = (snapshot.data != null && snapshot.data!.isNotEmpty)
            ? snapshot.data!
            : (_lastHeroMovies ?? const <Movie>[]);
        if (snapshot.data != null && snapshot.data!.isNotEmpty) {
          _lastHeroMovies = snapshot.data;
        }
        if (movies.isEmpty) {
          return _buildCinematicHeroShimmer(compact: widget.compact);
        }
        final shown = movies.take(5).toList();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _fetchHeroLogos(shown);
            _fetchHeroBackdrops(shown);
          }
        });
        final items = shown
            .map((movie) => _HeroItem.fromMovie(movie, _heroSlideUrls(movie)))
            .toList();
        return _buildCinematicHeroBlock(items, compact: widget.compact);
      },
    );
  }

  double _firstCatalogRowHeight(BuildContext context) {
    return widget.firstCatalogRowHeight ??
        (_isHub
            ? HubCatalogSection.sectionHeight(context, compactTop: true)
            : HomeMovieSection.sectionHeight(context, compactTop: true));
  }

  double _homeBackdropHeight(BuildContext context, {required bool compact}) {
    final topBarBleed = _desktopTopBarBleed(context);
    final pageBleed = widget.pageBottomChild != null && !compact;
    if (pageBleed) {
      return _snapToDevicePixels(
        context,
        MediaQuery.sizeOf(context).height *
                ShellTokens.homeBackdropViewportFraction +
            topBarBleed +
            ShellTokens.homePageBottomSectionDownOffset,
      );
    }
    return _snapToDevicePixels(
      context,
      _cinematicHeroHeight(context, compact: compact) + topBarBleed,
    );
  }

  double _homeHeroTextBottomInset(
    BuildContext context, {
    required bool compact,
    required double defaultBottom,
  }) {
    if (widget.pageBottomChild == null || compact) return defaultBottom;
    return _firstCatalogRowHeight(context) +
        ShellTokens.homePageBottomSectionTopPadding +
        ShellTokens.homePageBottomSectionDownOffset +
        defaultBottom;
  }

  /// Scroll-hide anchor for catalog top bars - cinematic chrome only.
  ///
  /// Must not use the extended page-bleed backdrop height (Featured row), or
  /// the top bar stays visible until nearly a full viewport of scroll.
  double _topBarHideAnchorHeight(
    BuildContext context, {
    required bool compact,
  }) {
    return _snapToDevicePixels(
      context,
      _cinematicHeroHeight(context, compact: compact) +
          _desktopTopBarBleed(context),
    );
  }

  ValueNotifier<double> _heroHeightNotifier() {
    return switch (widget.tvTabId) {
      'anime' => ShellBus.animeHeroHeight,
      'asian_drama' => ShellBus.asianDramaHeroHeight,
      'arabic' => ShellBus.arabicHeroHeight,
      'home' => ShellBus.homeHeroHeight,
      final id => ShellBus.hubHeroHeightFor(id),
    };
  }

  void _publishHeroHeight() {
    if (_heroHeightSyncScheduled) return;
    _heroHeightSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _heroHeightSyncScheduled = false;
      if (!mounted) return;
      final height = _topBarHideAnchorHeight(
        context,
        compact: _isHub ? _compact : widget.compact,
      );
      final notifier = _heroHeightNotifier();
      if (notifier.value != height) {
        notifier.value = height;
      }
    });
  }

  void _scrollHeroIntoView() {
    final controller = widget.scrollController;
    if (controller == null || !controller.hasClients) return;
    controller.animateTo(
      0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _focusHomeHeroGallery() {
    ShellTvFocusCoordinator.revealHeroForTab(widget.tvTabId);
    ShellTvFocus.focusHomeHeroGallery();
  }

  void _focusHomeHeroMenu() {
    ShellTvFocusCoordinator.revealHeroForTab(widget.tvTabId);
    ShellTvFocus.focusHomeMenu();
  }

  void _focusBleedCatalogRow() {
    final rowId = widget.bleedRowId?.trim();
    if (rowId != null &&
        rowId.isNotEmpty &&
        ShellTvFocusCoordinator.focusRowItem(widget.tvTabId, rowId, 0)) {
      return;
    }
    ShellTvFocusCoordinator.focusFirstContentRow(widget.tvTabId);
  }

  void _stepHeroFilm(int delta, List<_HeroItem> items) {
    if (items.isEmpty) return;
    final count = items.length;
    var next = (_heroIndex + delta) % count;
    if (next < 0) next += count;
    final instant = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    _goToHeroStep(next, items, instant: instant);
  }

  void _revealedHeroPlayFocus() {
    void focusPlay() {
      if (!mounted) return;
      ShellTvFocus.focusHomeHeroPlay();
    }

    _scrollHeroIntoView();
    final controller = widget.scrollController;
    if (controller == null || !controller.hasClients) {
      focusPlay();
      return;
    }
    controller
        .animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        )
        .whenComplete(focusPlay);
  }

  void _startHeroTimer() {
    _heroTimer?.cancel();
    final count = _isHub ? (widget.slides?.length ?? 0) : 5;
    if (_isHub && count < 2) return;
    _heroTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
      if (!_heroController.hasClients) return;
      _heroController.nextPage(
        duration: const Duration(milliseconds: 1000),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _jumpHeroToReal(int realIndex, int count) {
    if (!mounted || !_heroController.hasClients || count <= 0) return;
    final target = _heroLoopStart + (realIndex % count);
    if ((_heroController.page?.round() ?? target) == target) return;
    _heroController.jumpToPage(target);
  }

  void _onHeroPageChanged(int pageIndex, List<_HeroItem> items) {
    if (items.isEmpty) return;
    final count = items.length;
    final realIndex = pageIndex % count;
    if (_heroIndex != realIndex) {
      setState(() => _heroIndex = realIndex);
    }

    final target = _heroLoopStart + realIndex;
    final drifted = (pageIndex - target).abs() > count * 8;
    if (drifted || pageIndex <= 2 || pageIndex >= _heroLoopLength - 3) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _jumpHeroToReal(realIndex, count),
      );
    }
  }

  void _goToHeroStep(
    int stepIndex,
    List<_HeroItem> items, {
    bool instant = false,
  }) {
    if (!_heroController.hasClients || items.isEmpty) return;
    final count = items.length;
    final currentPage = _heroController.page?.round() ?? _heroLoopStart;
    final currentReal = currentPage % count;
    if (currentReal == stepIndex) return;

    var delta = stepIndex - currentReal;
    if (delta > count ~/ 2) {
      delta -= count;
    } else if (delta < -count ~/ 2) {
      delta += count;
    }

    final targetPage = currentPage + delta;
    if (instant) {
      _heroController.jumpToPage(targetPage);
      return;
    }

    _heroController.animateToPage(
      targetPage,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildHeroStepIndicators(
    List<_HeroItem> items, {
    Axis axis = Axis.vertical,
  }) {
    const selectedColor = Colors.white;
    final unselectedColor = Colors.white.withValues(alpha: 0.25);

    final dots = List.generate(items.length, (i) {
      final selected = i == _heroIndex;
      final isVertical = axis == Axis.vertical;
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => _goToHeroStep(i, items),
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
  Future<void> _fetchHeroLogos(List<Movie> movies) async {
    for (final movie in movies) {
      final id = '${movie.id}';
      if (_heroLogos.containsKey(id)) continue;
      try {
        final logoPath = await _api.getLogoPath(movie.id, mediaType: movie.mediaType);
        if (!mounted) return;
        setState(() {
          _heroLogos[id] = logoPath.isNotEmpty
              ? TmdbApi.getImageUrl(logoPath)
              : '';
        });
      } catch (_) {}
    }
  }

  Future<void> _enrichHubHeroSlides(List<HubHeroSlide> slides) async {
    for (final slide in slides) {
      final id = slide.id;
      if (_hubEnrichInflight.contains(id)) continue;
      final needsLogo = !_heroLogos.containsKey(id);
      final needsOverview =
          slide.overview.trim().isEmpty && !_heroOverviews.containsKey(id);
      final needsBackdrop = !_heroBackdropUrls.containsKey(id) &&
          (slide.imageUrl.trim().isEmpty ||
              !slide.imageUrl.contains('image.tmdb.org/t/p/w1280'));
      if (!needsLogo && !needsOverview && !needsBackdrop) continue;
      _hubEnrichInflight.add(id);
      try {
        final kisskhId = slide.id.startsWith('kisskh:')
            ? int.tryParse(slide.id.split(':').last)
            : null;
        final cachedHero = kisskhId != null
            ? KissKhTmdbMatch.peekCachedHeroMovie(kisskhId)
            : null;

        var tmdbId = slide.tmdbId ?? cachedHero?.id;
        var mediaType = slide.tmdbMediaType.trim().isEmpty
            ? (cachedHero?.mediaType ?? 'tv')
            : slide.tmdbMediaType.trim();
        if (cachedHero != null && cachedHero.id > 0) {
          tmdbId = cachedHero.id;
          if (cachedHero.mediaType == 'movie' ||
              cachedHero.mediaType == 'tv') {
            mediaType = cachedHero.mediaType;
          }
        }
        final kissKhType = KissKhTmdbMatch.kissKhTypeFromBadge(slide.badge);
        if (tmdbId == null || tmdbId <= 0) {
          final year = (slide.year ?? '').trim();
          final preferMovie = kissKhType != null
              ? KissKhTmdbMatch.preferMovie(kissKhType)
              : mediaType == 'movie';
          final matchKey =
              'hubHeroMatch:${slide.title.trim().toLowerCase()}|$mediaType|$year';
          ({int id, String mediaType})? hit;
          if (HubTmdbEnrichCache.contains(matchKey)) {
            final c = HubTmdbEnrichCache.get<(int, String)?>(matchKey);
            hit = c == null ? null : (id: c.$1, mediaType: c.$2);
          } else {
            hit = await _matchHubTitle(
              slide.title,
              year: year.isEmpty ? null : year,
              kissKhType: kissKhType,
              preferMovie: preferMovie,
            );
            HubTmdbEnrichCache.put(
              matchKey,
              hit == null ? null : (hit.id, hit.mediaType),
            );
          }
          if (hit == null) {
            if (!mounted) return;
            setState(() {
              if (needsLogo) _heroLogos[id] = '';
              if (needsOverview) _heroOverviews[id] = '';
              // Mark attempted so we don't re-fetch every frame.
              if (needsBackdrop) _heroBackdropUrls[id] = const [];
            });
            continue;
          }
          tmdbId = hit.id;
          mediaType = hit.mediaType;
        }
        final detailsKey = 'hubHeroDetails:$tmdbId:$mediaType';
        Movie? details = cachedHero;
        if (HubTmdbEnrichCache.contains(detailsKey)) {
          details = HubTmdbEnrichCache.get<Movie>(detailsKey) ?? details;
        } else if (needsOverview || needsBackdrop) {
          details ??= await _hubHeroDetails(tmdbId, mediaType);
          if (details != null) {
            mediaType = details.mediaType == 'movie' || details.mediaType == 'tv'
                ? details.mediaType
                : mediaType;
            HubTmdbEnrichCache.put('hubHeroDetails:$tmdbId:$mediaType', details);
          }
        }
        if (needsLogo) {
          final cachedLogoKey = 'hubHeroLogo:$tmdbId:$mediaType';
          String? logoUrl;
          if (HubTmdbEnrichCache.contains(cachedLogoKey)) {
            logoUrl = HubTmdbEnrichCache.get<String>(cachedLogoKey) ?? '';
          } else {
            try {
              final logoPath =
                  await _api.getLogoPath(tmdbId, mediaType: mediaType);
              logoUrl = logoPath.isNotEmpty
                  ? TmdbApi.getImageUrl(logoPath)
                  : '';
              HubTmdbEnrichCache.put(cachedLogoKey, logoUrl);
            } catch (_) {
              logoUrl = '';
            }
          }
          if (!mounted) return;
          setState(() => _heroLogos[id] = logoUrl ?? '');
        }
        if ((needsOverview || needsBackdrop) && details != null) {
          if (!mounted) return;
          setState(() {
            if (needsOverview) {
              final o = details!.overview.trim();
              if (o.isNotEmpty) _heroOverviews[id] = o;
              if (details.voteAverage > 0) {
                _heroRatings[id] = details.voteAverage;
              }
            }
            if (needsBackdrop) {
              final path = details!.backdropPath.trim();
              if (path.isNotEmpty) {
                final url = path.startsWith('http')
                    ? path
                    : TmdbApi.getBackdropUrl(path);
                if (url.isNotEmpty) {
                  _heroBackdropUrls[id] = [url];
                } else {
                  _heroBackdropUrls[id] = const [];
                }
              } else {
                _heroBackdropUrls[id] = const [];
              }
            }
          });
        } else if (needsBackdrop && details == null) {
          if (!mounted) return;
          setState(() => _heroBackdropUrls[id] = const []);
        }
      } finally {
        _hubEnrichInflight.remove(id);
      }
    }
  }

  /// Same scorer as Asian Drama details — not first-with-backdrop.
  Future<({int id, String mediaType})?> _matchHubTitle(
    String title, {
    String? kissKhType,
    required bool preferMovie,
    String? year,
  }) async {
    final match = await KissKhTmdbMatch.resolve(
      title: title,
      year: year,
      kissKhType: kissKhType ?? (preferMovie ? 'movie' : 'tvseries'),
      tmdb: _api,
    );
    if (match == null || match.id <= 0) return null;
    final mt = match.mediaType == 'movie' || match.mediaType == 'tv'
        ? match.mediaType
        : (preferMovie ? 'movie' : 'tv');
    return (id: match.id, mediaType: mt);
  }

  Future<Movie?> _hubHeroDetails(int tmdbId, String preferType) async {
    final primary = preferType == 'movie' ? 'movie' : 'tv';
    final secondary = primary == 'movie' ? 'tv' : 'movie';
    for (final media in [primary, secondary]) {
      try {
        final m = media == 'movie'
            ? await _api.getMovieDetails(tmdbId)
            : await _api.getTvDetails(tmdbId);
        if (m.id > 0) return m;
      } catch (_) {}
    }
    return null;
  }

  String _overviewFor(_HeroItem item) {
    final o = _heroOverviews[item.id];
    if (o != null && o.isNotEmpty) return o;
    return item.overview;
  }

  double _ratingFor(_HeroItem item) {
    final r = _heroRatings[item.id];
    if (r != null && r > 0) return r;
    return item.voteAverage;
  }

  Movie _heroItemAsMovie(_HeroItem item) {
    return Movie(
      id: item.tmdbId ?? 0,
      title: item.title,
      posterPath: '',
      backdropPath: '',
      voteAverage: _ratingFor(item),
      releaseDate: item.releaseDate,
      overview: _overviewFor(item),
      genres: item.genres,
      mediaType: item.mediaType.isNotEmpty ? item.mediaType : item.tmdbMediaType,
    );
  }

  Future<void> _fetchHeroBackdrops(List<Movie> movies) async {
    for (final movie in movies) {
      final id = '${movie.id}';
      if (_heroBackdropUrls.containsKey(id)) continue;
      final primary = _heroBackdropUrl(movie);
      final urls = <String>[if (primary.isNotEmpty) primary];
      try {
        final paths = await _api.getBackdrops(
          movie.id,
          mediaType: movie.mediaType,
        );
        for (final p in paths) {
          final u = TmdbApi.getBackdropUrl(p);
          if (u.isNotEmpty) urls.add(u);
        }
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _heroBackdropUrls[id] =
            RotatingHeroBackdrop.normalizeUrls(urls);
      });
    }
  }

  String _heroBackdropUrl(Movie movie) {
    return movie.backdropPath.isNotEmpty
        ? TmdbApi.getBackdropUrl(movie.backdropPath)
        : TmdbApi.getImageUrl(movie.posterPath);
  }

  List<String> _heroSlideUrls(Movie movie) {
    final id = '${movie.id}';
    final cached = _heroBackdropUrls[id];
    if (cached != null && cached.isNotEmpty) return cached;
    final primary = _heroBackdropUrl(movie);
    return primary.isEmpty ? const [] : [primary];
  }

  List<String> _itemSlideUrls(_HeroItem item) {
    final cached = _heroBackdropUrls[item.id];
    if (cached != null && cached.isNotEmpty) return cached;
    if (_isHub) return item.backdropUrls;
    final movie = item.movie;
    if (movie == null) return item.backdropUrls;
    return _heroSlideUrls(movie);
  }

  Widget _buildHeroPagesCarousel({
    required List<_HeroItem> items,
    required Color shellBg,
    required double solidLeftWidth,
    required double imageStartFraction,
    required bool pageBleed,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pageW = constraints.maxWidth.clamp(1.0, double.infinity);
        final prevW = _heroPageViewportWidth;
        if (prevW != null && (prevW - pageW).abs() > 0.5 && items.isNotEmpty) {
          final real = _heroIndex;
          final count = items.length;
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _jumpHeroToReal(real, count),
          );
        }
        _heroPageViewportWidth = pageW;

        // Backdrop + gradients only — title / meta / actions stay fixed outside.
        return PageView.builder(
          clipBehavior: Clip.hardEdge,
          controller: _heroController,
          itemCount: _heroLoopLength,
          onPageChanged: (i) => _onHeroPageChanged(i, items),
          itemBuilder: (context, index) {
            final item = items[index % items.length];
            return Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.hardEdge,
              children: [
                ColoredBox(color: shellBg),
                Positioned(
                  left: solidLeftWidth,
                  top: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildHeroSlideBackdrop(item, index),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: _buildDesktopHeroImageGradients(
                      shellBg,
                      imageStartFraction: imageStartFraction,
                      softBottomFade: pageBleed,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Opacity of a slide's trailing (right) edge softener from where that
  /// edge sits in the carousel viewport. Settled → 1; as the edge drifts
  /// left (either swipe direction) → ease to 0 before the hero fade zone.
  double _rightEdgeJoinOpacity(double rightEdgeViewportFraction) {
    if (rightEdgeViewportFraction >= _heroRightEdgeFadeStart) return 1.0;
    if (rightEdgeViewportFraction <= _heroRightEdgeFadeEnd) return 0.0;
    return (rightEdgeViewportFraction - _heroRightEdgeFadeEnd) /
        (_heroRightEdgeFadeStart - _heroRightEdgeFadeEnd);
  }

  Widget _buildHeroSlideTrailingEdge({required double opacity}) {
    if (opacity <= 0.001) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final edgeWidth =
            constraints.maxWidth * _heroSlideEdgeGradientFraction;
        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: edgeWidth,
              child: IgnorePointer(
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                        // Full black at the join → 0; soft so the seam stays quiet.
                        colors: [
                          Color(0xFF000000),
                          Color(0x6B000000), // ~0.42
                          Color(0x1F000000), // ~0.12
                          Color(0x00000000),
                        ],
                        stops: [0.0, 0.32, 0.68, 1.0],
                      ),
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

  Widget _buildHeroSeamScrim() {
    if (!_heroController.hasClients) return const SizedBox.shrink();

    final page = _heroController.page ?? _heroLoopStart.toDouble();
    final t = page - page.floor();
    if (t < _heroSeamTransitionEpsilon || t > 1 - _heroSeamTransitionEpsilon) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final seamX = width * (1 - t);
        final seamLeft = (seamX - _heroSeamScrimWidth / 2)
            .clamp(0.0, math.max(0.0, width - _heroSeamScrimWidth))
            .toDouble();
        // Match trailing-edge rule: hide the seam softener once it enters
        // the left hero-fade zone (same fractions, viewport X of seam).
        final seamOpacity = _rightEdgeJoinOpacity(seamX / width);
        if (seamOpacity <= 0.001) return const SizedBox.shrink();

        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: seamLeft,
              width: _heroSeamScrimWidth,
              top: 0,
              bottom: 0,
              child: Opacity(
                opacity: seamOpacity,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color(0x00000000),
                        Color(0x59000000), // ~0.35
                        Color(0xFF000000),
                        Color(0x59000000),
                        Color(0x00000000),
                      ],
                      stops: [0.0, 0.28, 0.5, 0.72, 1.0],
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

  double _desktopTopBarBleed(BuildContext context) =>
      MediaQuery.paddingOf(context).top;

  double _desktopHeroHeight(BuildContext context) {
    final screenH = MediaQuery.sizeOf(context).height;
    final topBar = _desktopTopBarBleed(context);
    final firstRowHeight = _firstCatalogRowHeight(context);
    final nextRowPeek = (_isHub
            ? HubCatalogSection.sectionHeight(context)
            : HomeMovieSection.sectionHeight(context)) *
        shellHeroNextRowPeekFraction(context);
    final reservedBelow = shellHomeRowSpacing(context) +
        firstRowHeight +
        nextRowPeek;
    final target = screenH * shellHeroHeightFraction(context);
    final maxHero = screenH - topBar - reservedBelow;
    return _snapToDevicePixels(
      context,
      math.min(target, math.max(shellHeroMinHeight(context), maxHero)),
    );
  }

  Widget _buildCinematicHeroShimmer({required bool compact}) {
    return homeHubHeroShimmer(
      height: _homeBackdropHeight(context, compact: compact),
    );
  }

  Widget _buildCinematicHeroBlock(List<_HeroItem> items, {required bool compact}) {
    final metrics = ShellScope.metricsOf(context);
    final policy = ShellScope.inputPolicyOf(context);
    final pageBleed = widget.pageBottomChild != null && !compact;
    final imageHeight = _homeBackdropHeight(context, compact: compact);
    final topBarBleed = _desktopTopBarBleed(context);
    final textTop = topBarBleed + homeHeroTextTopInset(context);
    final compactRightInset =
        compact ? metrics.heroCompactRightInset : 48.0;
    final textRight = compact
        ? shellScaled(context, compactRightInset).clamp(12.0, compactRightInset)
        : shellScaled(context, 48).clamp(24.0, 48.0);
    final textBottom = shellScaled(context, 16).clamp(8.0, 16.0);
    final textBottomInset = _homeHeroTextBottomInset(
      context,
      compact: compact,
      defaultBottom: textBottom,
    );
    final textLeft = shellHomeSectionHorizontalPadding(context);
    final desktopTextWidth = math.min(
      MediaQuery.sizeOf(context).width * 0.34,
      ShellTokens.heroTextColumnWidthDesktop,
    );
    final shellBg = Theme.of(context).scaffoldBackgroundColor;
    final imageStartFraction = compact
        ? ShellTokens.heroImageStartFractionCompact
        : ShellTokens.heroImageStartFraction;
    final solidLeftWidth =
        MediaQuery.sizeOf(context).width * imageStartFraction;
    final textColumnWidth = compact
        ? MediaQuery.sizeOf(context).width - textLeft - textRight
        : desktopTextWidth;
    final heroTextItem = items[_heroIndex];

    return SizedBox(
      height: imageHeight,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: _buildHeroPagesCarousel(
              items: items,
              shellBg: shellBg,
              solidLeftWidth: solidLeftWidth,
              imageStartFraction: imageStartFraction,
              pageBleed: pageBleed,
            ),
          ),
          Positioned(
            left: solidLeftWidth,
            top: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _heroController,
                builder: (context, _) => _buildHeroSeamScrim(),
              ),
            ),
          ),
          Positioned(
            left: textLeft,
            top: textTop,
            bottom: textBottomInset,
            width: textColumnWidth,
            child: _buildHeroTextSlide(
              item: heroTextItem,
              isActive: true,
              compact: compact,
              metrics: metrics,
              desktopTextWidth: desktopTextWidth,
            ),
          ),
          Positioned(
            right: shellScaled(context, 20).clamp(10.0, 20.0),
            bottom: compact ? shellScaled(context, 16).clamp(8.0, 16.0) : null,
            top: compact ? null : 0,
            height: compact ? null : imageHeight,
            child: compact
                ? _buildHeroStepIndicators(items, axis: Axis.horizontal)
                : Align(
                    alignment: Alignment.centerRight,
                    child: _buildHeroStepIndicators(items),
                  ),
          ),
          if (policy.useFocusableMoodChips)
            Positioned(
              left: MediaQuery.sizeOf(context).width *
                  (compact
                      ? ShellTokens.heroImageStartFractionCompact
                      : ShellTokens.heroImageStartFraction),
              top: 0,
              right: 0,
              bottom: 0,
              // Desktop shares the TV focus graph but still needs mouse/trackpad
              // swipes on the PageView — opaque gallery hit target blocks them.
              child: IgnorePointer(
                ignoring: policy.scaleOnHover,
                child: _buildTvHeroGalleryFocus(items),
              ),
            ),
          if (pageBleed)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: widget.pageBottomChild!,
            ),
        ],
      ),
    );
  }

  Widget _buildHeroTextSlide({
    required _HeroItem item,
    required bool isActive,
    required bool compact,
    required ShellMetrics metrics,
    required double desktopTextWidth,
  }) {
    return compact
        ? LayoutBuilder(
            builder: (context, constraints) {
              return Align(
                alignment: Alignment.bottomLeft,
                child: _buildCompactHeroTextColumn(
                  item,
                  metrics: metrics,
                  maxHeight: constraints.maxHeight,
                  maxWidth: constraints.maxWidth,
                  isActive: isActive,
                ),
              );
            },
          )
        : LayoutBuilder(
            builder: (context, constraints) {
              return Align(
                alignment: Alignment(
                  -1,
                  ShellTokens.heroTextColumnVerticalAlign,
                ),
                child: SizedBox(
                  width: desktopTextWidth,
                  child: _buildDesktopHeroTextColumn(
                    item,
                    maxHeight: constraints.maxHeight,
                    isActive: isActive,
                  ),
                ),
              );
            },
          );
  }

  Widget _buildTvHeroGalleryFocus(List<_HeroItem> items) {
    return shellFocusableTap(
      context: context,
      focusNode: _tvHeroGalleryFocus,
      tvTabId: widget.tvTabId,
      tvZone: ShellTvZone.hero,
      scaleOnFocus: 1,
      ensureVisibleMode: ShellTvEnsureVisibleMode.off,
      onLeftEdge: () => _stepHeroFilm(-1, items),
      onRightEdge: () => _stepHeroFilm(1, items),
      onUpEdge: _focusHomeHeroMenu,
      onDownEdge: _revealedHeroPlayFocus,
      onTap: items.isEmpty
          ? null
          : () {
              final item = items[_heroIndex];
              if (item.movie != null && widget.onOpenDetails != null) {
                widget.onOpenDetails!(item.movie!);
              } else {
                item.onDetails();
              }
            },
      child: const SizedBox.expand(),
    );
  }

  Widget _buildCompactHeroTextColumn(
    _HeroItem heroItem, {
    required ShellMetrics metrics,
    double? maxHeight,
    double? maxWidth,
    bool isActive = true,
  }) {
    if (maxHeight != null && maxWidth != null) {
      final actionGap = shellHeroActionGap(context);
      final metaGap = shellHeroMetaGap(context);
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
            ClipRect(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: titleHeight,
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: _buildHeroTitleBlock(
                        heroItem,
                        isLandscape: false,
                        desktop: true,
                        compact: true,
                        slotHeight: titleHeight,
                      ),
                    ),
                  ),
                  SizedBox(height: metaGap),
                  SizedBox(
                    height: metaRowHeight,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _buildHeroMetaRow(heroItem, singleLine: true),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: actionGap),
            _buildHeroUpcomingNotice(heroItem),
            _buildHeroActionRow(heroItem, isActive: isActive),
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
          heroItem,
          isLandscape: false,
          desktop: true,
          compact: true,
        ),
        SizedBox(height: shellHeroMetaGap(context)),
        _buildHeroMetaRow(heroItem, singleLine: true),
        SizedBox(height: shellHeroActionGap(context)),
        _buildHeroUpcomingNotice(heroItem),
        _buildHeroActionRow(heroItem, isActive: isActive),
      ],
    );
  }

  Widget _buildDesktopHeroImageGradients(
    Color shellBg, {
    required double imageStartFraction,
    bool softBottomFade = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final fadeEnd = ShellTokens.heroImageGradientFadeEndFraction;
        final solidEnd = _heroGradientSolidEndFraction;
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
                        shellBg,
                        shellBg,
                        shellBg,
                        if (solidEnd > 0) shellBg,
                        shellBg.withValues(alpha: _heroGradientFadeMid1Alpha),
                        shellBg.withValues(alpha: _heroGradientFadeMid2Alpha),
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
              height: height * (softBottomFade ? 0.42 : 0.55),
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: softBottomFade
                          ? [
                              Colors.transparent,
                              shellBg.withValues(alpha: 0.18),
                              shellBg.withValues(alpha: 0.48),
                              shellBg.withValues(alpha: 0.78),
                              shellBg,
                            ]
                          : [
                              Colors.transparent,
                              shellBg.withValues(alpha: 0.45),
                              shellBg.withValues(alpha: 0.82),
                              shellBg,
                              shellBg,
                            ],
                      stops: softBottomFade
                          ? const [0.0, 0.42, 0.68, 0.9, 1.0]
                          : const [0.0, 0.35, 0.68, 0.92, 1.0],
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
    _HeroItem heroItem, {
    required double maxHeight,
    bool isActive = true,
  }) {
    const overviewStyle = TextStyle(
      fontSize: ShellTokens.heroOverviewFontSizeDesktop,
      height: ShellTokens.heroOverviewLineHeightDesktop,
      letterSpacing: 0.1,
      color: Color(0x99FFFFFF),
    );
    const titleGap = 20.0;
    const actionGap = 16.0;
    final overview = _overviewFor(heroItem);
    final layout = shellHeroDesktopTextLayout(
      maxHeight: maxHeight,
      hasOverview: overview.isNotEmpty,
      minTitleHeight: ShellScope.metricsOf(context).heroMinTitleHeight,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRect(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: layout.titleHeight,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: _buildHeroTitleBlock(
                    heroItem,
                    isLandscape: false,
                    desktop: true,
                    slotHeight: layout.titleHeight,
                  ),
                ),
              ),
              const SizedBox(height: titleGap),
              SizedBox(
                height: ShellTokens.heroMetaSlotHeightDesktop,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _buildHeroMetaRow(heroItem, singleLine: true),
                ),
              ),
              if (layout.showOverview) ...[
                SizedBox(height: ShellTokens.heroMetaOverviewGapDesktop),
                SizedBox(
                  height: layout.overviewSlotHeight,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: HeroOverviewText(
                      overview: overview,
                      style: overviewStyle,
                      maxLines: layout.overviewMaxLines,
                      shrinkWrap: false,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: actionGap),
        _buildHeroUpcomingNotice(heroItem),
        _buildHeroActionRow(heroItem, isActive: isActive),
      ],
    );
  }

  Widget _buildHeroSlideBackdrop(_HeroItem item, int index) {
    final shellBg = Theme.of(context).scaffoldBackgroundColor;
    final urls = _itemSlideUrls(item);
    return Stack(
      fit: StackFit.expand,
      children: [
        if (urls.isEmpty)
          ColoredBox(color: shellBg)
        else
          RotatingHeroBackdrop(
            key: ValueKey('hero-bg-${item.id}'),
            imageUrls: urls,
            showColorTint: false,
            fit: item.imageFit,
            imageAlignment: item.imageAlignment,
          ),
        // Trailing join only - opacity tracks scroll so it fades out while
        // sliding left (never parks under the hero text fade). Reverse swipe
        // uses the same rule: previous slide's right edge ramps in as it
        // leaves the left zone.
        AnimatedBuilder(
          animation: _heroController,
          builder: (context, _) {
            final page = _heroController.hasClients
                ? (_heroController.page ?? index.toDouble())
                : index.toDouble();
            // Viewport X of this slide's right edge, in page-widths (1 = right).
            final rightEdgeViewportFraction = index - page + 1.0;
            final opacity = _rightEdgeJoinOpacity(rightEdgeViewportFraction);
            return _buildHeroSlideTrailingEdge(opacity: opacity);
          },
        ),
      ],
    );
  }

  Widget _buildHeroTitleBlock(
    _HeroItem heroItem, {
    required bool isLandscape,
    bool desktop = false,
    bool compact = false,
    double? slotHeight,
  }) {
    final movie = heroItem.movie;
    final tmdbId = heroItem.tmdbId;
    if (movie != null || (tmdbId != null && tmdbId > 0)) {
      return HeroTitle(
        key: ValueKey(heroItem.id),
        movie: movie ?? _heroItemAsMovie(heroItem),
        logoUrl: _heroLogos[heroItem.id],
        style: HeroTitleStyle.home,
        isLandscape: isLandscape,
        desktop: desktop,
        compact: compact,
        slotHeight: slotHeight,
      );
    }
    return _buildHubHeroTitle(
      heroItem,
      desktop: desktop,
      compact: compact,
      slotHeight: slotHeight,
    );
  }

  Widget _buildHubHeroTitle(
    _HeroItem heroItem, {
    bool desktop = false,
    bool compact = false,
    double? slotHeight,
  }) {
    final maxLines = compact ? 2 : 3;
    final preferred = compact
        ? shellScaled(context, 28).clamp(18.0, 28.0).toDouble()
        : 32.0;
    final resolvedSlotHeight = slotHeight ??
        (compact
            ? ShellTokens.heroTitleSlotHeightCompact
            : ShellTokens.heroTitleSlotHeightDesktop);
    return SizedBox(
      height: compact && slotHeight == null ? null : resolvedSlotHeight,
      child: Align(
        alignment: Alignment.bottomLeft,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxW = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width;
            final maxH = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : resolvedSlotHeight;
            final fontSize = fitHeroTitleFontSize(
              title: heroItem.title,
              maxWidth: maxW,
              maxHeight: maxH,
              maxLines: maxLines,
              preferredSize: preferred,
              minSize: compact ? 16 : 20,
              height: 1.05,
              letterSpacing: -1.0,
              pad: EdgeInsets.zero,
            );
            return ChromaticHeroTitleText(
              title: heroItem.title,
              maxLines: maxLines,
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                height: 1.05,
                letterSpacing: -1.0,
                shadows: compact
                    ? null
                    : [
                        const Shadow(color: Colors.black, blurRadius: 40),
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 80,
                        ),
                      ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeroMediaTypeBadge(String label) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: shellScaled(context, 8).clamp(4.0, 8.0),
        vertical: shellScaled(context, 3).clamp(2.0, 3.0),
      ),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(shellScaled(context, 4).clamp(2.0, 4.0)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: shellScaled(context, 10).clamp(7.0, 10.0),
          fontWeight: FontWeight.bold,
          color: Colors.white60,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildHeroMetaRow(_HeroItem heroItem, {bool singleLine = false}) {
    final metaFont = shellScaled(context, 13).clamp(9.0, 13.0);
    final genreFont = shellScaled(context, 12).clamp(8.0, 12.0);
    final gap = shellScaled(context, 10).clamp(7.0, 10.0);
    final vote = _ratingFor(heroItem);
    final rating = vote > 0
        ? Container(
      padding: EdgeInsets.symmetric(
        horizontal: shellScaled(context, 8).clamp(4.0, 8.0),
        vertical: shellScaled(context, 4).clamp(2.0, 4.0),
      ),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(shellScaled(context, 20).clamp(10.0, 20.0)),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_rounded,
            size: shellScaled(context, 14).clamp(10.0, 14.0),
            color: Colors.amber,
          ),
          SizedBox(width: shellScaled(context, 4).clamp(2.0, 4.0)),
          Text(
            vote.toStringAsFixed(1),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.amber,
              fontSize: metaFont,
            ),
          ),
        ],
      ),
    )
        : null;

    String? year;
    if (heroItem.releaseDate.isNotEmpty) {
      year = heroItem.releaseDate.contains('-')
          ? heroItem.releaseDate.split('-').first
          : heroItem.releaseDate;
    }

    Widget? typeBadge;
    if (heroItem.badgeLabel != null && heroItem.badgeLabel!.isNotEmpty) {
      typeBadge = _buildHeroMediaTypeBadge(heroItem.badgeLabel!);
    } else if (heroItem.mediaType == 'tv') {
      typeBadge = _buildHeroMediaTypeBadge('SERIES');
    } else if (heroItem.mediaType == 'movie') {
      typeBadge = _buildHeroMediaTypeBadge('FILM');
    }

    if (singleLine) {
      return Row(
        children: [
          Flexible(
            fit: FlexFit.loose,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ?rating,
                  if (year != null) ...[
                    if (rating != null) SizedBox(width: gap),
                    Text(
                      year,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: metaFont,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  if (typeBadge != null) ...[
                    SizedBox(width: gap),
                    typeBadge,
                  ],
                  if (heroItem.statusChip != null &&
                      heroItem.statusChip!.isNotEmpty &&
                      heroItem.statusChip != heroItem.badgeLabel) ...[
                    SizedBox(width: gap),
                    _buildHeroMediaTypeBadge(heroItem.statusChip!),
                  ],
                ],
              ),
            ),
          ),
          if (heroItem.genres.isNotEmpty) ...[
            SizedBox(width: gap),
            Expanded(
              child: Text(
                heroItem.genres.take(3).join('  ·  '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: genreFont,
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
          ?rating,
          if (year != null)
            Text(
              year,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ?typeBadge,
          if (heroItem.statusChip != null &&
              heroItem.statusChip!.isNotEmpty &&
              heroItem.statusChip != heroItem.badgeLabel)
            _buildHeroMediaTypeBadge(heroItem.statusChip!),
          if (heroItem.genres.isNotEmpty)
            Text(
              heroItem.genres.take(3).join('  ·  '),
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

  Widget _buildHeroUpcomingNotice(_HeroItem heroItem) {
    if (!heroItem.isUpcoming &&
        (heroItem.upcomingReleaseLabel == null ||
            heroItem.upcomingReleaseLabel!.trim().isEmpty)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: HubDetailsUpcomingNotice(
        releaseDateLabel: heroItem.upcomingReleaseLabel,
      ),
    );
  }

  Widget _buildHeroActionRow(_HeroItem heroItem, {bool isActive = true}) {
    final metrics = ShellScope.metricsOf(context);
    final policy = ShellScope.inputPolicyOf(context);
    final tvNav = policy.useFocusableMoodChips;
    // Inactive PageView slides must not mount focusable controls. Passing
    // focusNode:null with onTap set makes ForjaInteractive own+dispose a
    // forja-interactive node on every carousel step → FocusManager crash.
    final focusable = isActive;
    final tabId = widget.tvTabId;
    final details = HeroPillPlayButton(
      label: 'View details',
      icon: Icons.info_outline_rounded,
      primary: false,
      alwaysShowLabel: true,
      focusNode:
          focusable && policy.heroPlayAutoFocus ? _tvHeroPlayFocus : null,
      tvTabId: focusable && tvNav ? tabId : null,
      tvRowId: focusable && tvNav ? MediaDetailsTv.heroRowId : null,
      tvItemIndex: focusable && tvNav ? 0 : null,
      onUpEdge: focusable && tvNav ? _focusHomeHeroGallery : null,
      onKeyEvent: focusable && policy.heroPlayAutoFocus
          ? (node, event) {
              if (!shellTvIsNavigationKey(event)) {
                return KeyEventResult.ignored;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                if (ShellTvFocusCoordinator.focusActiveNavTab()) {
                  return KeyEventResult.handled;
                }
              }
              return KeyEventResult.ignored;
            }
          : null,
      onTap: focusable
          ? () {
              if (heroItem.movie != null && widget.onOpenDetails != null) {
                widget.onOpenDetails!(heroItem.movie!);
              } else {
                heroItem.onDetails();
              }
            }
          : null,
    );
    final listAction = heroItem.movie != null
        ? MyListHeroStatusPill(
            movie: heroItem.movie!,
            tvTabId: focusable && tvNav ? tabId : null,
            tvItemIndexStart: focusable && tvNav ? 1 : 0,
            onUpEdge: focusable && tvNav ? _focusHomeHeroGallery : null,
            enabled: focusable,
          )
        : heroItem.listTarget != null
            ? HubListStatusHero(
                target: heroItem.listTarget!,
                tvTabId: focusable && tvNav ? tabId : null,
                tvItemIndexStart: focusable && tvNav ? 1 : 0,
                onUpEdge: focusable && tvNav ? _focusHomeHeroGallery : null,
                enabled: focusable,
              )
            : null;
    final row = HeroPillActionRow(
      children: [
        if (tvNav)
          FocusTraversalOrder(order: const NumericFocusOrder(1), child: details)
        else
          details,
        if (listAction != null) ...[
          const SizedBox(width: 10),
          listAction,
        ],
      ],
    );
    final body = metrics.heroActionUseFittedBox
        ? FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: row,
          )
        : row;
    if (!tvNav || !focusable) return body;
    return DetailsHeroTvActionScope(
      tabId: tabId,
      itemCount: listAction != null ? 2 : 1,
      onFocusUp: _focusHomeHeroGallery,
      onFocusDown:
          widget.pageBottomChild != null ? _focusBleedCatalogRow : null,
      child: body,
    );
  }
}

typedef HubCinematicHero = HomeCinematicHero;
