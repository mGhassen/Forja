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

/// Cinematic home hero — carousel, metadata, play/details actions.
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
  });

  final Future<List<Movie>> moviesFuture;
  final bool compact;
  final bool usesShellHomeLayout;
  final ScrollController scrollController;
  final HomeHeroController controller;
  final Future<void> Function(Movie movie) onOpenDetails;
  final Future<void> Function(Movie movie) onWatchNow;

  @override
  State<HomeCinematicHero> createState() => _HomeCinematicHeroState();
}

class _HomeCinematicHeroState extends State<HomeCinematicHero> {
  static const int _heroLoopLength = 10000;
  static const int _heroLoopStart = 5000;

  final TmdbApi _api = TmdbApi();
  final PageController _heroController =
      PageController(initialPage: _heroLoopStart);
  final FocusNode _tvHeroPlayFocus = FocusNode(debugLabel: 'hero-play');
  final FocusNode _tvHeroGalleryFocus = FocusNode(debugLabel: 'hero-gallery');
  bool _tvHeroInitialFocusDone = false;

  Timer? _heroTimer;
  int _heroIndex = 0;
  final Map<int, String> _heroLogos = {};
  bool _heroHeightSyncScheduled = false;

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
    ShellBus.homeHeroHeight.value = 0;
    _heroTimer?.cancel();
    _heroController.dispose();
    _tvHeroPlayFocus.dispose();
    _tvHeroGalleryFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

  void _publishHomeHeroHeight() {
    if (_heroHeightSyncScheduled) return;
    _heroHeightSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _heroHeightSyncScheduled = false;
      if (!mounted) return;
      final height = _cinematicHeroHeight(context, compact: widget.compact) +
          (widget.usesShellHomeLayout ? _desktopTopBarBleed(context) : 0);
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

  void _onHeroPageChanged(int pageIndex, List<Movie> movies) {
    if (movies.isEmpty) return;
    final count = movies.length;
    final realIndex = pageIndex % count;
    if (_heroIndex != realIndex) {
      setState(() => _heroIndex = realIndex);
    }

    if (pageIndex <= 2 || pageIndex >= _heroLoopLength - 3) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_heroController.hasClients) return;
        _heroController.jumpToPage(_heroLoopStart + realIndex);
      });
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
    final height = _cinematicHeroHeight(context, compact: compact) +
        _desktopTopBarBleed(context);
    return homeHubHeroShimmer(height: height);
  }

  Widget _buildCinematicHeroBlock(List<Movie> movies, {required bool compact}) {
    final heroMovie = movies[_heroIndex];
    final metrics = ShellScope.metricsOf(context);
    final policy = ShellScope.inputPolicyOf(context);
    if (policy.heroPlayAutoFocus && !_tvHeroInitialFocusDone) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _tvHeroInitialFocusDone) return;
        if (_tvHeroPlayFocus.canRequestFocus) {
          _tvHeroPlayFocus.requestFocus();
          _tvHeroInitialFocusDone = true;
        }
      });
    }
    final backdropHeight = _cinematicHeroHeight(context, compact: compact);
    final topBarBleed = _desktopTopBarBleed(context);
    final imageHeight =
        _snapToDevicePixels(context, backdropHeight + topBarBleed);
    final textTop = topBarBleed + homeHeroTextTopInset(context);
    final compactRightInset =
        compact ? metrics.heroCompactRightInset : 48.0;

    return SizedBox(
      height: imageHeight,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: imageHeight,
            child: _buildDesktopHeroBackdrop(
              movies,
              compact: compact,
            ),
          ),
          Positioned(
            left: shellHomeSectionHorizontalPadding(context),
            top: textTop,
            right: compact
                ? shellScaled(context, compactRightInset).clamp(12.0, compactRightInset)
                : shellScaled(context, 48).clamp(24.0, 48.0),
            bottom: shellScaled(context, 16).clamp(8.0, 16.0),
            child: compact
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      return ClipRect(
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: _buildCompactHeroTextColumn(
                            heroMovie,
                            metrics: metrics,
                            maxHeight: constraints.maxHeight,
                            maxWidth: constraints.maxWidth,
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
                            width: math.min(
                              MediaQuery.sizeOf(context).width * 0.34,
                              ShellTokens.heroTextColumnWidthDesktop,
                            ),
                            child: _buildDesktopHeroTextColumn(
                              heroMovie,
                              maxHeight: constraints.maxHeight,
                            ),
                          ),
                        ),
                      );
                    },
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
        ],
      ),
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
            _buildHeroActionRow(heroMovie),
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
        _buildHeroActionRow(heroMovie),
      ],
    );
  }

  Widget _buildDesktopHeroImageGradients(
    Color shellBg, {
    required double imageStartFraction,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final fadeEnd = ShellTokens.heroImageGradientFadeEndFraction;
        final solidEnd = ShellTokens.heroImageGradientSolidEndFraction;
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
                        Colors.transparent,
                        Colors.transparent,
                        shellBg,
                        if (solidEnd > 0) shellBg,
                        shellBg.withValues(alpha: 0.72),
                        shellBg.withValues(alpha: 0.28),
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
              height: height * 0.55,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        shellBg.withValues(alpha: 0.45),
                        shellBg.withValues(alpha: 0.82),
                        shellBg,
                        shellBg,
                      ],
                      stops: const [0.0, 0.35, 0.68, 0.92, 1.0],
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
  }) {
    const overviewStyle = TextStyle(
      fontSize: ShellTokens.heroOverviewFontSizeDesktop,
      height: ShellTokens.heroOverviewLineHeightDesktop,
      letterSpacing: 0.1,
      color: Color(0x99FFFFFF),
    );
    const titleGap = 20.0;
    const actionGap = 16.0;
    final minTitleHeight = ShellScope.metricsOf(context).heroMinTitleHeight;

    final baseWithoutOverview = titleGap +
        ShellTokens.heroMetaSlotHeightDesktop +
        actionGap +
        ShellTokens.shellButtonHeight;
    final overviewBlock = ShellTokens.heroMetaOverviewGapDesktop +
        ShellTokens.heroOverviewSlotHeightDesktop;

    var titleHeight = ShellTokens.heroTitleSlotHeightDesktop;
    final showOverview = heroMovie.overview.isNotEmpty &&
        titleHeight + baseWithoutOverview + overviewBlock <= maxHeight;

    if (!showOverview && titleHeight + baseWithoutOverview > maxHeight) {
      titleHeight = (maxHeight - baseWithoutOverview)
          .clamp(minTitleHeight, ShellTokens.heroTitleSlotHeightDesktop);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
        if (showOverview) ...[
          SizedBox(height: ShellTokens.heroMetaOverviewGapDesktop),
          SizedBox(
            height: ShellTokens.heroOverviewSlotHeightDesktop,
            child: Align(
              alignment: Alignment.topLeft,
              child: HeroOverviewText(
                overview: heroMovie.overview,
                style: overviewStyle,
                maxLines: ShellTokens.heroOverviewMaxLinesDesktop,
                shrinkWrap: false,
                onReadMore: () => widget.onOpenDetails(heroMovie),
              ),
            ),
          ),
        ],
        const SizedBox(height: actionGap),
        _buildHeroActionRow(heroMovie),
      ],
    );
  }

  Widget _buildDesktopHeroBackdrop(List<Movie> movies, {bool compact = false}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final shellBg = Theme.of(context).scaffoldBackgroundColor;
        final imageLeft = constraints.maxWidth *
            (compact
                ? ShellTokens.heroImageStartFractionCompact
                : ShellTokens.heroImageStartFraction);

        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: shellBg),
              Positioned(
                left: imageLeft,
                top: 0,
                right: 0,
                bottom: 0,
                child: PageView.builder(
                  clipBehavior: Clip.hardEdge,
                  controller: _heroController,
                  itemCount: _heroLoopLength,
                  onPageChanged: (i) => _onHeroPageChanged(i, movies),
                  itemBuilder: (context, index) {
                    final movie = movies[index % movies.length];
                    return CachedNetworkImage(
                      key: ValueKey(movie.id),
                      imageUrl: movie.backdropPath.isNotEmpty
                          ? TmdbApi.getBackdropUrl(movie.backdropPath)
                          : TmdbApi.getImageUrl(movie.posterPath),
                      fit: BoxFit.cover,
                      alignment: Alignment.centerRight,
                      filterQuality: FilterQuality.medium,
                      placeholder: (c, u) => ColoredBox(color: shellBg),
                      errorWidget: (c, u, e) => ColoredBox(color: shellBg),
                    );
                  },
                ),
              ),
              _buildDesktopHeroImageGradients(
                shellBg,
                imageStartFraction: compact
                    ? ShellTokens.heroImageStartFractionCompact
                    : ShellTokens.heroImageStartFraction,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeroTitleBlock(
    Movie heroMovie, {
    required bool isLandscape,
    bool desktop = false,
    bool compact = false,
  }) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.bottomLeft,
          clipBehavior: Clip.none,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: HeroTitle(
        key: ValueKey(heroMovie.id),
        movie: heroMovie,
        logoUrl: _heroLogos[heroMovie.id],
        style: HeroTitleStyle.home,
        isLandscape: isLandscape,
        desktop: desktop,
        compact: compact,
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

  Widget _buildHeroActionRow(Movie heroMovie) {
    final metrics = ShellScope.metricsOf(context);
    final policy = ShellScope.inputPolicyOf(context);
    final tvNav = policy.useFocusableMoodChips;
    const heroItemCount = 3;
    final play = HeroPillPlayButton(
      label: 'Play',
      focusNode: policy.heroPlayAutoFocus ? _tvHeroPlayFocus : null,
      tvTabId: tvNav ? 'home' : null,
      tvRowId: tvNav ? MediaDetailsTv.heroRowId : null,
      tvItemIndex: tvNav ? 0 : null,
      onUpEdge: tvNav ? _focusHomeHeroGallery : null,
      onKeyEvent: policy.heroPlayAutoFocus
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
      onFocusUp: _focusHomeHeroGallery,
      child: body,
    );
  }
}
