import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rust/rust.dart';
import 'package:forja/features/home/widgets/home_movie_section.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/tv/media_details_tv_scope.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:forja/shared/widgets/hero/hero_pill_buttons.dart';
import 'package:forja/shared/widgets/hero/hero_title.dart';
import 'package:forja/shared/widgets/hero_overview_text.dart';
import 'package:forja/shared/widgets/home_loading_skeleton.dart';
import 'package:forja/shared/widgets/hub_details/hub_details_play_row.dart';
import 'package:forja/shared/widgets/my_list_button.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:forja/shell/shell_bus.dart';

bool homeIsFullCinematicHero(BuildContext context) {
  if (ShellScope.metricsOf(context).usesTvDensity) return true;
  return MediaQuery.sizeOf(context).width >= ShellTokens.heroDesktopMinBodyWidth;
}

double homeHeroTextTopInset(BuildContext context) =>
    ShellTokens.heroTextColumnTopInsetDesktop;

/// Bridges TV focus from catalog rows back to the hero play button.
class HomeHeroController {
  VoidCallback? revealPlayFocus;
}

/// Cinematic home hero - carousel, metadata, play/details actions.
class HomeCinematicHero extends StatefulWidget {
  const HomeCinematicHero({
    super.key,
    required this.moviesFuture,
    required this.compact,
    required this.usesShellHomeLayout,
    required this.scrollController,
    required this.controller,
    required this.onOpenDetails,
    required this.onWatchNow,
    this.pageBottomChild,
  });

  final Future<List<Movie>> moviesFuture;
  final bool compact;
  final bool usesShellHomeLayout;
  final ScrollController scrollController;
  final HomeHeroController controller;
  final Future<void> Function(Movie movie) onOpenDetails;
  final Future<void> Function(Movie movie) onWatchNow;

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

  final TmdbApi _api = TmdbApi();
  final PageController _heroController =
      PageController(initialPage: _heroLoopStart);
  final FocusNode _tvHeroPlayFocus = FocusNode(debugLabel: 'hero-play');
  final FocusNode _tvHeroGalleryFocus = FocusNode(debugLabel: 'hero-gallery');

  Timer? _heroTimer;
  int _heroIndex = 0;
  final Map<int, String> _heroLogos = {};
  bool _heroHeightSyncScheduled = false;
  double? _heroPageViewportWidth;

  @override
  void initState() {
    super.initState();
    ShellTvFocus.homeHeroPlay = _tvHeroPlayFocus;
    ShellTvFocus.homeHeroGallery = _tvHeroGalleryFocus;
    ShellTvFocusCoordinator.registerTabDefaults(
      'home',
      defaultFocus: () => _tvHeroPlayFocus,
      heroReveal: _scrollHeroIntoView,
    );
    widget.controller.revealPlayFocus = _revealedHeroPlayFocus;
    _startHeroTimer();
  }

  @override
  void dispose() {
    if (ShellTvFocus.homeHeroPlay == _tvHeroPlayFocus) {
      ShellTvFocus.homeHeroPlay = null;
    }
    if (ShellTvFocus.homeHeroGallery == _tvHeroGalleryFocus) {
      ShellTvFocus.homeHeroGallery = null;
    }
    if (ShellBus.homeHeroHeight.value != 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ShellBus.homeHeroHeight.value = 0;
      });
    }
    _heroTimer?.cancel();
    _heroController.dispose();
    _tvHeroPlayFocus.dispose();
    _tvHeroGalleryFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // KeepAlive tabs all mount - only Home owns shared nodes while selected.
    if (ShellTvFocus.currentNavTabId == 'home') {
      ShellTvFocus.homeHeroPlay = _tvHeroPlayFocus;
      ShellTvFocus.homeHeroGallery = _tvHeroGalleryFocus;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _publishHomeHeroHeight();
    });

    return FutureBuilder<List<Movie>>(
      future: widget.moviesFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildCinematicHeroShimmer(compact: widget.compact);
        }
        final movies = snapshot.data!.take(5).toList();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _fetchHeroLogos(movies);
        });
        return _buildCinematicHeroBlock(movies, compact: widget.compact);
      },
    );
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
    return HomeMovieSection.sectionHeight(context, compactTop: true) +
        ShellTokens.homePageBottomSectionTopPadding +
        ShellTokens.homePageBottomSectionDownOffset +
        defaultBottom;
  }

  /// Scroll-hide anchor for [HomeTopBar] - cinematic chrome only.
  ///
  /// Must not use the extended page-bleed backdrop height (Featured row), or
  /// the top bar stays visible until nearly a full viewport of scroll.
  double _homeTopBarHideAnchorHeight(
    BuildContext context, {
    required bool compact,
  }) {
    return _snapToDevicePixels(
      context,
      _cinematicHeroHeight(context, compact: compact) +
          _desktopTopBarBleed(context),
    );
  }

  void _publishHomeHeroHeight() {
    if (_heroHeightSyncScheduled) return;
    _heroHeightSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _heroHeightSyncScheduled = false;
      if (!mounted) return;
      final height = _homeTopBarHideAnchorHeight(
        context,
        compact: widget.compact,
      );
      if (ShellBus.homeHeroHeight.value != height) {
        ShellBus.homeHeroHeight.value = height;
      }
    });
  }

  void _scrollHeroIntoView() {
    if (!widget.scrollController.hasClients) return;
    widget.scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _focusHomeHeroGallery() {
    ShellTvFocusCoordinator.revealHeroForTab('home');
    ShellTvFocus.focusHomeHeroGallery();
  }

  void _focusHomeHeroMenu() {
    ShellTvFocusCoordinator.revealHeroForTab('home');
    ShellTvFocus.focusHomeMenu();
  }

  void _stepHeroFilm(int delta, List<Movie> movies) {
    if (movies.isEmpty) return;
    final count = movies.length;
    var next = (_heroIndex + delta) % count;
    if (next < 0) next += count;
    final instant = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    _goToHeroStep(next, movies, instant: instant);
  }

  void _revealedHeroPlayFocus() {
    void focusPlay() {
      if (!mounted) return;
      ShellTvFocus.focusHomeHeroPlay();
    }

    _scrollHeroIntoView();
    if (!widget.scrollController.hasClients) {
      focusPlay();
      return;
    }
    widget.scrollController
        .animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        )
        .whenComplete(focusPlay);
  }

  void _startHeroTimer() {
    _heroTimer?.cancel();
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

  void _onHeroPageChanged(int pageIndex, List<Movie> movies) {
    if (movies.isEmpty) return;
    final count = movies.length;
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
    List<Movie> movies, {
    bool instant = false,
  }) {
    if (!_heroController.hasClients || movies.isEmpty) return;
    final count = movies.length;
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
    List<Movie> movies, {
    Axis axis = Axis.vertical,
  }) {
    const selectedColor = Colors.white;
    final unselectedColor = Colors.white.withValues(alpha: 0.25);

    final dots = List.generate(movies.length, (i) {
      final selected = i == _heroIndex;
      final isVertical = axis == Axis.vertical;
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => _goToHeroStep(i, movies),
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
      if (_heroLogos.containsKey(movie.id)) continue;
      try {
        final logoPath = await _api.getLogoPath(movie.id, mediaType: movie.mediaType);
        if (!mounted) return;
        setState(() {
          _heroLogos[movie.id] = logoPath.isNotEmpty
              ? TmdbApi.getImageUrl(logoPath)
              : '';
        });
      } catch (_) {}
    }
  }

  String _heroBackdropUrl(Movie movie) {
    return movie.backdropPath.isNotEmpty
        ? TmdbApi.getBackdropUrl(movie.backdropPath)
        : TmdbApi.getImageUrl(movie.posterPath);
  }

  Widget _buildHeroBackdropCarousel(List<Movie> movies) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pageW = constraints.maxWidth.clamp(1.0, double.infinity);
        final prevW = _heroPageViewportWidth;
        if (prevW != null && (prevW - pageW).abs() > 0.5 && movies.isNotEmpty) {
          final real = _heroIndex;
          final count = movies.length;
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _jumpHeroToReal(real, count),
          );
        }
        _heroPageViewportWidth = pageW;

        return PageView.builder(
          clipBehavior: Clip.hardEdge,
          controller: _heroController,
          itemCount: _heroLoopLength,
          onPageChanged: (i) => _onHeroPageChanged(i, movies),
          itemBuilder: (context, index) {
            final movie = movies[index % movies.length];
            return _buildHeroSlideBackdrop(movie, index);
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
    final firstRowHeight =
        HomeMovieSection.sectionHeight(context, compactTop: true);
    final nextRowPeek = HomeMovieSection.sectionHeight(context) *
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

  Widget _buildCinematicHeroBlock(List<Movie> movies, {required bool compact}) {
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
    final heroTextMovie = movies[_heroIndex];

    return SizedBox(
      height: imageHeight,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ColoredBox(color: shellBg),
          Positioned(
            left: solidLeftWidth,
            top: 0,
            right: 0,
            bottom: 0,
            child: _buildHeroBackdropCarousel(movies),
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
          Positioned(
            left: solidLeftWidth,
            top: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _heroController,
                builder: (context, _) =>
                    _buildHeroSeamScrim(),
              ),
            ),
          ),
          Positioned(
            left: textLeft,
            top: textTop,
            bottom: textBottomInset,
            width: textColumnWidth,
            child: _buildHeroTextSlide(
              movie: heroTextMovie,
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
                ? _buildHeroStepIndicators(movies, axis: Axis.horizontal)
                : Align(
                    alignment: Alignment.centerRight,
                    child: _buildHeroStepIndicators(movies),
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
              child: _buildTvHeroGalleryFocus(movies),
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
    required Movie movie,
    required bool isActive,
    required bool compact,
    required ShellMetrics metrics,
    required double desktopTextWidth,
  }) {
    return compact
        ? LayoutBuilder(
            builder: (context, constraints) {
              return ClipRect(
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: _buildCompactHeroTextColumn(
                    movie,
                    metrics: metrics,
                    maxHeight: constraints.maxHeight,
                    maxWidth: constraints.maxWidth,
                    isActive: isActive,
                  ),
                ),
              );
            },
          )
        : LayoutBuilder(
            builder: (context, constraints) {
              return ClipRect(
                child: Align(
                  alignment: Alignment(
                    -1,
                    ShellTokens.heroTextColumnVerticalAlign,
                  ),
                  child: SizedBox(
                    width: desktopTextWidth,
                    child: _buildDesktopHeroTextColumn(
                      movie,
                      maxHeight: constraints.maxHeight,
                      isActive: isActive,
                    ),
                  ),
                ),
              );
            },
          );
  }

  Widget _buildTvHeroGalleryFocus(List<Movie> movies) {
    return shellFocusableTap(
      context: context,
      focusNode: _tvHeroGalleryFocus,
      tvTabId: 'home',
      tvZone: ShellTvZone.hero,
      scaleOnFocus: 1,
      ensureVisibleMode: ShellTvEnsureVisibleMode.off,
      onLeftEdge: () => _stepHeroFilm(-1, movies),
      onRightEdge: () => _stepHeroFilm(1, movies),
      onUpEdge: _focusHomeHeroMenu,
      onDownEdge: _revealedHeroPlayFocus,
      onTap: movies.isEmpty ? null : () => widget.onOpenDetails(movies[_heroIndex]),
      child: const SizedBox.expand(),
    );
  }

  Widget _buildCompactHeroTextColumn(
    Movie heroMovie, {
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
            SizedBox(
              height: titleHeight,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: _buildHeroTitleBlock(
                  heroMovie,
                  isLandscape: false,
                  desktop: true,
                  compact: true,
                ),
              ),
            ),
            SizedBox(height: metaGap),
            SizedBox(
              height: metaRowHeight,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _buildHeroMetaRow(heroMovie, singleLine: true),
              ),
            ),
            SizedBox(height: actionGap),
            _buildHeroActionRow(heroMovie, isActive: isActive),
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
          heroMovie,
          isLandscape: false,
          desktop: true,
          compact: true,
        ),
        SizedBox(height: shellHeroMetaGap(context)),
        _buildHeroMetaRow(heroMovie, singleLine: true),
        SizedBox(height: shellHeroActionGap(context)),
        _buildHeroActionRow(heroMovie, isActive: isActive),
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
    Movie heroMovie, {
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
    final layout = shellHeroDesktopTextLayout(
      maxHeight: maxHeight,
      hasOverview: heroMovie.overview.isNotEmpty,
      minTitleHeight: ShellScope.metricsOf(context).heroMinTitleHeight,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: layout.titleHeight,
          child: Align(
            alignment: Alignment.bottomLeft,
            child: _buildHeroTitleBlock(
              heroMovie,
              isLandscape: false,
              desktop: true,
            ),
          ),
        ),
        const SizedBox(height: titleGap),
        SizedBox(
          height: ShellTokens.heroMetaSlotHeightDesktop,
          child: Align(
            alignment: Alignment.centerLeft,
            child: _buildHeroMetaRow(heroMovie, singleLine: true),
          ),
        ),
        if (layout.showOverview) ...[
          SizedBox(height: ShellTokens.heroMetaOverviewGapDesktop),
          SizedBox(
            height: layout.overviewSlotHeight,
            child: Align(
              alignment: Alignment.topLeft,
              child: HeroOverviewText(
                overview: heroMovie.overview,
                style: overviewStyle,
                maxLines: layout.overviewMaxLines,
                shrinkWrap: false,
                onReadMore: () => widget.onOpenDetails(heroMovie),
              ),
            ),
          ),
        ],
        const SizedBox(height: actionGap),
        _buildHeroActionRow(heroMovie, isActive: isActive),
      ],
    );
  }

  Widget _buildHeroSlideBackdrop(Movie movie, int index) {
    final shellBg = Theme.of(context).scaffoldBackgroundColor;
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          key: ValueKey(movie.id),
          imageUrl: _heroBackdropUrl(movie),
          fit: BoxFit.cover,
          alignment: Alignment.centerRight,
          filterQuality: FilterQuality.medium,
          placeholder: (c, u) => ColoredBox(color: shellBg),
          errorWidget: (c, u, e) => ColoredBox(color: shellBg),
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
    Movie heroMovie, {
    required bool isLandscape,
    bool desktop = false,
    bool compact = false,
  }) {
    return HeroTitle(
      key: ValueKey(heroMovie.id),
      movie: heroMovie,
      logoUrl: _heroLogos[heroMovie.id],
      style: HeroTitleStyle.home,
      isLandscape: isLandscape,
      desktop: desktop,
      compact: compact,
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

  Widget _buildHeroMetaRow(Movie heroMovie, {bool singleLine = false}) {
    final metaFont = shellScaled(context, 13).clamp(9.0, 13.0);
    final genreFont = shellScaled(context, 12).clamp(8.0, 12.0);
    final gap = shellScaled(context, 10).clamp(7.0, 10.0);
    final rating = Container(
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
            heroMovie.voteAverage.toStringAsFixed(1),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.amber,
              fontSize: metaFont,
            ),
          ),
        ],
      ),
    );

    if (singleLine) {
      return Row(
        children: [
          Flexible(
            fit: FlexFit.loose,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                rating,
                if (heroMovie.releaseDate.isNotEmpty) ...[
                  SizedBox(width: gap),
                  Text(
                    heroMovie.releaseDate.split('-').first,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: metaFont,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (heroMovie.mediaType == 'tv') ...[
                  SizedBox(width: gap),
                  _buildHeroMediaTypeBadge('SERIES'),
                ] else if (heroMovie.mediaType == 'movie') ...[
                  SizedBox(width: gap),
                  _buildHeroMediaTypeBadge('FILM'),
                ],
              ],
            ),
          ),
          if (heroMovie.genres.isNotEmpty) ...[
            SizedBox(width: gap),
            Expanded(
              child: Text(
                heroMovie.genres.take(3).join('  ·  '),
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
          rating,
          if (heroMovie.releaseDate.isNotEmpty)
            Text(
              heroMovie.releaseDate.split('-').first,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          if (heroMovie.mediaType == 'tv')
            _buildHeroMediaTypeBadge('SERIES')
          else if (heroMovie.mediaType == 'movie')
            _buildHeroMediaTypeBadge('FILM'),
          if (heroMovie.genres.isNotEmpty)
            Text(
              heroMovie.genres.take(3).join('  ·  '),
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

  Widget _buildHeroActionRow(Movie heroMovie, {bool isActive = true}) {
    final metrics = ShellScope.metricsOf(context);
    final policy = ShellScope.inputPolicyOf(context);
    final tvNav = policy.useFocusableMoodChips;
    const heroItemCount = 3;
    final play = HeroPillPlayButton(
      label: 'Play',
      focusNode: isActive && policy.heroPlayAutoFocus ? _tvHeroPlayFocus : null,
      tvTabId: tvNav ? 'home' : null,
      tvRowId: tvNav ? MediaDetailsTv.heroRowId : null,
      tvItemIndex: tvNav ? 0 : null,
      onUpEdge: tvNav ? _focusHomeHeroGallery : null,
      onKeyEvent: isActive && policy.heroPlayAutoFocus
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
      onTap: () => widget.onWatchNow(heroMovie),
    );
    final row = HeroPillActionRow(
      children: [
        if (tvNav)
          FocusTraversalOrder(order: const NumericFocusOrder(1), child: play)
        else
          play,
        const SizedBox(width: 10),
        HeroPillIconGroup(
          tvFocusOrderStart: tvNav ? 2 : null,
          tvTabId: tvNav ? 'home' : null,
          tvRowId: tvNav ? MediaDetailsTv.heroRowId : null,
          tvItemIndexStart: tvNav ? 1 : null,
          onUpEdge: tvNav ? _focusHomeHeroGallery : null,
          slots: [
            HeroPillIconSlot(
              icon: Icons.info_outline_rounded,
              tooltip: 'Details',
              onTap: () => widget.onOpenDetails(heroMovie),
            ),
            MyListHeroPillButton.movieSlot(context, movie: heroMovie),
          ],
        ),
      ],
    );
    final body = metrics.heroActionUseFittedBox
        ? FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: row,
          )
        : row;
    if (!tvNav) return body;
    return DetailsHeroTvActionScope(
      tabId: 'home',
      itemCount: heroItemCount,
      onFocusUp: isActive ? _focusHomeHeroGallery : null,
      child: body,
    );
  }
}
