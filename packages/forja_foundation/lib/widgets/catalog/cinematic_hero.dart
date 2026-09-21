import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:forja_foundation/components/crossfade_swap.dart';
import 'package:forja_foundation/tokens/forja_motion_theme.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/utils/hero_desktop_layout.dart';
import 'package:forja_foundation/widgets/catalog/rotating_hero_backdrop.dart';
import 'package:forja_foundation/widgets/details/hero_overview_text.dart';
import 'package:forja_foundation/widgets/details/hero_title.dart';

/// Absolute-URL slide for [CinematicHero] — pack meta props only (no TmdbApi).
class CinematicHeroSlide {
  const CinematicHeroSlide({
    required this.id,
    required this.title,
    required this.backdropUrl,
    this.posterUrl,
    this.logoUrl,
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
    this.mediaType = '',
    this.onDetails,
  });

  final String id;
  final String title;
  /// Absolute backdrop URL from pack meta.
  final String backdropUrl;
  /// Absolute poster fallback when backdrop empty.
  final String? posterUrl;
  /// Absolute logo URL from pack meta.
  final String? logoUrl;
  final String overview;
  final double? rating;
  final String? year;
  final String? badge;
  final String? statusChip;
  final String? upcomingReleaseLabel;
  final bool isUpcoming;
  final List<String> genres;
  final BoxFit imageFit;
  final Alignment imageAlignment;
  final String mediaType;
  final VoidCallback? onDetails;

  String get primaryImageUrl {
    final b = backdropUrl.trim();
    if (b.isNotEmpty) return b;
    return (posterUrl ?? '').trim();
  }
}

/// Layout flags — host maps [ShellScope] into these (Zone A has no ShellScope).
///
/// Nullable visual fields are pack overrides; omit / null → [ShellTokens].
class CinematicHeroLayout {
  const CinematicHeroLayout({
    this.compact = false,
    this.tvDensity = false,
    this.kenBurns = true,
    this.plainTitle = false,
    this.selectableTitle = false,
    this.heroMinTitleHeight = 72,
    this.heroActionUseFittedBox = false,
    this.heroCompactRightInset = 24,
    this.sectionHorizontalPadding = 48,
    this.heroHeightFraction = 0.62,
    this.heroMinHeight = 320,
    this.nextRowPeekFraction = 0.12,
    this.rowSpacing = 24,
    this.topBarBleed = 0,
    this.firstCatalogRowHeight = 0,
    this.bleedDownOffset,
    this.scale = 1.0,
    this.imageStartFraction,
    this.textColumnWidth,
    this.textColumnTopInset,
    this.textColumnVerticalAlign,
    this.titleSlotHeight,
    this.logoMaxHeight,
    this.metaSlotHeight,
    this.titleMetaGap,
    this.metaOverviewGap,
    this.metaActionsGap,
    this.overviewMaxLines,
    this.overviewFontSize,
    this.overviewLineHeight,
    this.upcomingNoticeReserve,
  });

  final bool compact;
  final bool tvDensity;
  final bool kenBurns;
  final bool plainTitle;
  final bool selectableTitle;
  final double heroMinTitleHeight;
  final bool heroActionUseFittedBox;
  final double heroCompactRightInset;
  final double sectionHorizontalPadding;
  final double heroHeightFraction;
  final double heroMinHeight;
  final double nextRowPeekFraction;
  final double rowSpacing;
  final double topBarBleed;
  final double firstCatalogRowHeight;

  /// Extra backdrop under the bleed rail. Null → [ShellTokens.homePageBottomSectionDownOffset].
  final double? bleedDownOffset;
  final double scale;

  /// Pack `imageStartFraction`. Null → compact/desktop ShellTokens.
  final double? imageStartFraction;
  final double? textColumnWidth;
  final double? textColumnTopInset;
  final double? textColumnVerticalAlign;
  final double? titleSlotHeight;
  final double? logoMaxHeight;
  final double? metaSlotHeight;
  final double? titleMetaGap;
  final double? metaOverviewGap;
  final double? metaActionsGap;
  final int? overviewMaxLines;
  final double? overviewFontSize;
  final double? overviewLineHeight;
  final double? upcomingNoticeReserve;

  double scaled(double value) => value * scale;

  /// Layout chrome (padding, gaps, column width). Never snap to type sizes —
  /// that crushed [resolvedTextColumnWidth] to ~17 on TV and overflowed CTAs.
  double scaledChrome(double value, {double? floor, double? ceil}) {
    final s = scaled(value);
    if (tvDensity) {
      if (ceil != null) return math.min(s, ceil);
      return s;
    }
    final lo = floor ?? s;
    final hi = ceil ?? s;
    return s.clamp(lo, hi);
  }

  /// Desktop font → TV type token ([ShellTokens.tvTypeSize]); else [scaled].
  double scaledType(double desktopFontSize) {
    if (tvDensity) return ShellTokens.tvTypeSize(desktopFontSize);
    return scaled(desktopFontSize);
  }

  double get resolvedBleedDownOffset {
    final base = bleedDownOffset ?? ShellTokens.homePageBottomSectionDownOffset;
    return tvDensity ? base * scale : base;
  }

  double get resolvedImageStartFraction =>
      imageStartFraction ??
      (compact
          ? ShellTokens.heroImageStartFractionCompact
          : ShellTokens.heroImageStartFraction);

  double get resolvedTextColumnWidth =>
      textColumnWidth ?? ShellTokens.heroTextColumnWidthDesktop;

  double get resolvedTextColumnTopInset =>
      textColumnTopInset ?? ShellTokens.heroTextColumnTopInsetDesktop;

  double get resolvedTextColumnVerticalAlign =>
      textColumnVerticalAlign ?? ShellTokens.heroTextColumnVerticalAlign;

  double get resolvedTitleSlotHeight =>
      titleSlotHeight ?? ShellTokens.heroTitleSlotHeightDesktop;

  double get resolvedMetaSlotHeight =>
      metaSlotHeight ?? ShellTokens.heroMetaSlotHeightDesktop;

  double get resolvedTitleMetaGap =>
      titleMetaGap ?? ShellTokens.heroTitleMetaGapDesktop;

  double get resolvedMetaOverviewGap =>
      metaOverviewGap ?? ShellTokens.heroMetaOverviewGapDesktop;

  double get resolvedMetaActionsGap =>
      metaActionsGap ?? ShellTokens.heroMetaActionsGapDesktop;

  int get resolvedOverviewMaxLines =>
      overviewMaxLines ?? ShellTokens.heroOverviewMaxLinesDesktop;

  double get resolvedOverviewFontSize =>
      overviewFontSize ?? ShellTokens.heroOverviewFontSizeDesktop;

  double get resolvedOverviewLineHeight =>
      overviewLineHeight ?? ShellTokens.heroOverviewLineHeightDesktop;

  double get resolvedUpcomingNoticeReserve =>
      upcomingNoticeReserve ?? ShellTokens.heroUpcomingNoticeReserveDesktop;

  double get resolvedLogoMaxHeight {
    if (logoMaxHeight != null) return logoMaxHeight!;
    if (tvDensity) return ShellTokens.heroLogoMaxHeightTv;
    if (compact) return ShellTokens.heroLogoMaxHeightCompact;
    return ShellTokens.heroLogoMaxHeightDesktop;
  }
}

bool cinematicHeroIsFullBleed({
  required double width,
  required bool tvDensity,
}) {
  if (tvDensity) return true;
  return width >= ShellTokens.heroDesktopMinBodyWidth;
}

/// Full-bleed cinematic hero carousel — props + slots only (RFC-106 Zone A).
///
/// Host owns TV focus / Interactive / list-status via [actionRowBuilder] and
/// [galleryOverlayBuilder]. PageController stays here for paint carousel.
class CinematicHero extends StatefulWidget {
  const CinematicHero({
    super.key,
    required this.slides,
    required this.layout,
    this.pageBottomChild,
    this.height,
    this.actionRowBuilder,
    this.upcomingNoticeBuilder,
    this.galleryOverlayBuilder,
    this.shimmer,
    this.onIndexChanged,
    this.onHeight,
    this.pageController,
  });

  final List<CinematicHeroSlide> slides;
  final CinematicHeroLayout layout;
  final Widget? pageBottomChild;
  final double? height;
  final Widget Function(
    BuildContext context,
    CinematicHeroSlide slide, {
    required bool isActive,
  })? actionRowBuilder;
  final Widget Function(BuildContext context, CinematicHeroSlide slide)?
      upcomingNoticeBuilder;
  final Widget Function(BuildContext context)? galleryOverlayBuilder;
  final Widget? shimmer;
  final ValueChanged<int>? onIndexChanged;
  /// Reports computed backdrop height for shell chrome fade.
  final ValueChanged<double>? onHeight;
  /// Host interactive may own the controller; otherwise one is created.
  final PageController? pageController;

  @override
  State<CinematicHero> createState() => CinematicHeroState();
}

class CinematicHeroState extends State<CinematicHero> {
  static const int _heroLoopLength = 10000;
  static const int _heroLoopStart = 5000;
  static const double _heroGradientSolidEndFraction = 0.02;
  static const double _heroGradientFadeMid1Alpha = 0.82;
  static const double _heroGradientFadeMid2Alpha = 0.2;
  static const double _heroSeamScrimWidth = 120;
  static const double _heroSeamTransitionEpsilon = 0.015;
  static const double _heroSlideEdgeGradientFraction = 0.10;
  static const double _heroRightEdgeFadeEnd = 0.14;
  static const double _heroRightEdgeFadeStart = 0.46;

  late final PageController _heroController;
  late final bool _ownsController;
  /// Keeps the [PageView] element across compact/bleed parent shape changes so
  /// the controller never briefly has two scroll positions.
  final GlobalKey _heroPageViewKey = GlobalKey(debugLabel: 'cinematic-hero-page');
  Timer? _heroTimer;
  int _heroIndex = 0;
  double? _heroPageViewportWidth;

  PageController get pageController => _heroController;
  int get heroIndex => _heroIndex;

  /// [PageController.page] asserts exactly one attached [PageView].
  /// [hasClients] is only "≥1" — remount / reparent can briefly attach two.
  bool get _heroHasSingleClient => _heroController.positions.length == 1;

  /// Never call [PageController.page] — read pixels from the sole position.
  double? _safeHeroPage() {
    final positions = _heroController.positions;
    if (positions.length != 1) return null;
    final position = positions.first;
    if (!position.hasPixels || !position.hasContentDimensions) return null;
    final extent = position.viewportDimension;
    if (extent <= 0) return null;
    return position.pixels / (extent * _heroController.viewportFraction);
  }

  @override
  void initState() {
    super.initState();
    _ownsController = widget.pageController == null;
    _heroController =
        widget.pageController ?? PageController(initialPage: _heroLoopStart);
    _startHeroTimer();
  }

  @override
  void didUpdateWidget(covariant CinematicHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slides.length != widget.slides.length) {
      _startHeroTimer();
    }
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    if (_ownsController) _heroController.dispose();
    super.dispose();
  }

  void stepFilm(int delta, {bool instant = false}) {
    final items = widget.slides;
    if (items.isEmpty) return;
    final count = items.length;
    var next = (_heroIndex + delta) % count;
    if (next < 0) next += count;
    _goToHeroStep(next, instant: instant);
  }

  void _startHeroTimer() {
    _heroTimer?.cancel();
    if (widget.slides.length < 2) return;
    _heroTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!_heroHasSingleClient) return;
      _heroController.nextPage(
        duration: const Duration(milliseconds: 1000),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _goToHeroStep(int realIndex, {required bool instant}) {
    final count = widget.slides.length;
    if (count <= 0 || !_heroHasSingleClient) return;
    final target = _heroLoopStart + (realIndex % count);
    if (instant) {
      _heroController.jumpToPage(target);
    } else {
      _heroController.animateToPage(
        target,
        duration: ForjaMotionTheme.of(context).pageFade.duration,
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _jumpHeroToReal(int realIndex, int count) {
    if (!mounted || !_heroHasSingleClient || count <= 0) return;
    final target = _heroLoopStart + (realIndex % count);
    if ((_safeHeroPage()?.round() ?? target) == target) return;
    _heroController.jumpToPage(target);
  }

  void _onHeroPageChanged(int pageIndex) {
    final items = widget.slides;
    if (items.isEmpty) return;
    final realIndex = pageIndex % items.length;
    if (_heroIndex != realIndex) {
      setState(() => _heroIndex = realIndex);
      widget.onIndexChanged?.call(realIndex);
    }
    final target = _heroLoopStart + realIndex;
    if (pageIndex < _heroLoopStart ~/ 2 ||
        pageIndex > _heroLoopLength - _heroLoopStart ~/ 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _heroHasSingleClient) {
          _heroController.jumpToPage(target);
        }
      });
    }
  }

  double _snapToDevicePixels(BuildContext context, double value) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return (value * dpr).round() / dpr;
  }

  double _backdropHeight(BuildContext context) {
    if (widget.height != null) return widget.height!;
    final layout = widget.layout;
    // Featured-row bleed owns height. Narrow windows still get the tall
    // cinematic band — compact only changes the text column, not height.
    final pageBleed = widget.pageBottomChild != null;
    if (pageBleed) {
      return _snapToDevicePixels(
        context,
        MediaQuery.sizeOf(context).height *
                ShellTokens.homeBackdropViewportFraction +
            layout.topBarBleed +
            layout.resolvedBleedDownOffset,
      );
    }
    final screenH = MediaQuery.sizeOf(context).height;
    final reservedBelow = layout.rowSpacing +
        layout.firstCatalogRowHeight +
        layout.firstCatalogRowHeight * layout.nextRowPeekFraction;
    final target = screenH * layout.heroHeightFraction;
    final maxHero = screenH - layout.topBarBleed - reservedBelow;
    return _snapToDevicePixels(
      context,
      math.min(target, math.max(layout.heroMinHeight, maxHero)),
    );
  }

  List<String> _slideUrls(CinematicHeroSlide slide) {
    final u = slide.primaryImageUrl;
    return u.isEmpty ? const [] : [u];
  }

  @override
  Widget build(BuildContext context) {
    final slides = widget.slides;
    if (slides.isEmpty) {
      return widget.shimmer ?? const SizedBox.shrink();
    }
    final layout = widget.layout;
    final compact = layout.compact;
    // Overlay bleed only on wide layout — compact stacks Featured under the hero.
    final pageBleed = widget.pageBottomChild != null && !compact;
    final imageHeight = _backdropHeight(context);
    final onHeight = widget.onHeight;
    if (onHeight != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        onHeight(imageHeight + layout.topBarBleed);
      });
    }
    final textTop = layout.topBarBleed +
        layout.scaledChrome(layout.resolvedTextColumnTopInset);
    final compactRightInset = compact ? layout.heroCompactRightInset : 48.0;
    final textRight = compact
        ? layout.scaledChrome(compactRightInset, floor: 12.0, ceil: compactRightInset)
        : layout.scaledChrome(48, floor: 24.0, ceil: 48.0);
    final textBottom = layout.scaledChrome(16, floor: 8.0, ceil: 16.0);
    final textBottomInset = pageBleed
        ? layout.firstCatalogRowHeight +
            layout.scaledChrome(ShellTokens.homePageBottomSectionTopPadding) +
            layout.resolvedBleedDownOffset +
            textBottom
        : textBottom;
    final textLeft = layout.scaledChrome(layout.sectionHorizontalPadding);
    final desktopTextWidth = math.min(
      MediaQuery.sizeOf(context).width * 0.34,
      layout.scaledChrome(layout.resolvedTextColumnWidth),
    );
    final shellBg = Theme.of(context).scaffoldBackgroundColor;
    final imageStartFraction = layout.resolvedImageStartFraction;
    final solidLeftWidth =
        MediaQuery.sizeOf(context).width * imageStartFraction;
    final textColumnWidth = compact
        ? MediaQuery.sizeOf(context).width - textLeft - textRight
        : desktopTextWidth;
    final heroSlide = slides[_heroIndex % slides.length];

    final heroBody = SizedBox(
      height: imageHeight,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: _buildCarousel(
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
              slide: heroSlide,
              isActive: true,
              compact: compact,
              desktopTextWidth: desktopTextWidth,
            ),
          ),
          Positioned(
            top: 0,
            bottom: 0,
            right: layout.scaledChrome(16, floor: 8.0, ceil: 20.0),
            child: Center(
              child: _buildStepIndicators(),
            ),
          ),
          if (widget.galleryOverlayBuilder != null)
            Positioned(
              left: solidLeftWidth,
              top: 0,
              right: 0,
              bottom: 0,
              child: widget.galleryOverlayBuilder!(context),
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

    // Stable outer shape so the PageView element is not remounted when compact
    // / Featured appear (that briefly attaches two positions to one controller).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        heroBody,
        if (compact && widget.pageBottomChild != null) widget.pageBottomChild!,
      ],
    );
  }

  Widget _buildCarousel({
    required Color shellBg,
    required double solidLeftWidth,
    required double imageStartFraction,
    required bool pageBleed,
  }) {
    final items = widget.slides;
    return LayoutBuilder(
      builder: (context, constraints) {
        final pageW = constraints.maxWidth.clamp(1.0, double.infinity);
        final prevW = _heroPageViewportWidth;
        if (prevW != null && (prevW - pageW).abs() > 0.5 && items.isNotEmpty) {
          final real = _heroIndex;
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _jumpHeroToReal(real, items.length),
          );
        }
        _heroPageViewportWidth = pageW;
        return PageView.builder(
          key: _heroPageViewKey,
          clipBehavior: Clip.hardEdge,
          controller: _heroController,
          itemCount: _heroLoopLength,
          onPageChanged: _onHeroPageChanged,
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
                  child: _buildSlideBackdrop(item, index),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: _buildImageGradients(
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

  Widget _buildSlideBackdrop(CinematicHeroSlide item, int index) {
    final shellBg = Theme.of(context).scaffoldBackgroundColor;
    final urls = _slideUrls(item);
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
            enableMotion: widget.layout.kenBurns,
          ),
        AnimatedBuilder(
          animation: _heroController,
          builder: (context, _) {
            final page = _safeHeroPage() ?? index.toDouble();
            final rightEdgeViewportFraction = index - page + 1.0;
            final opacity = _rightEdgeJoinOpacity(rightEdgeViewportFraction);
            return _buildTrailingEdge(opacity: opacity);
          },
        ),
      ],
    );
  }

  double _rightEdgeJoinOpacity(double rightEdgeViewportFraction) {
    if (rightEdgeViewportFraction >= _heroRightEdgeFadeStart) return 1.0;
    if (rightEdgeViewportFraction <= _heroRightEdgeFadeEnd) return 0.0;
    return (rightEdgeViewportFraction - _heroRightEdgeFadeEnd) /
        (_heroRightEdgeFadeStart - _heroRightEdgeFadeEnd);
  }

  Widget _buildTrailingEdge({required double opacity}) {
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
                        colors: [
                          Color(0xFF000000),
                          Color(0x6B000000),
                          Color(0x1F000000),
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
    final page = _safeHeroPage();
    if (page == null) return const SizedBox.shrink();
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
              child: IgnorePointer(
                child: Opacity(
                  opacity: seamOpacity.clamp(0.0, 1.0),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0x00000000),
                          Color(0x99000000),
                          Color(0x00000000),
                        ],
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

  Widget _buildImageGradients(
    Color shellBg, {
    required double imageStartFraction,
    required bool softBottomFade,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
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
                        shellBg.withValues(alpha: _heroGradientFadeMid1Alpha),
                        shellBg.withValues(alpha: _heroGradientFadeMid2Alpha),
                        shellBg.withValues(alpha: 0),
                      ],
                      stops: [
                        0.0,
                        imageStartFraction + _heroGradientSolidEndFraction,
                        imageStartFraction + 0.18,
                        imageStartFraction + 0.42,
                        math.min(1.0, imageStartFraction + 0.72),
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
              height: constraints.maxHeight * 0.42,
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

  Widget _buildHeroTextSlide({
    required CinematicHeroSlide slide,
    required bool isActive,
    required bool compact,
    required double desktopTextWidth,
  }) {
    final body = compact
        ? LayoutBuilder(
            builder: (context, constraints) {
              return Align(
                alignment: Alignment.bottomLeft,
                child: _buildCompactColumn(
                  slide,
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
                  widget.layout.resolvedTextColumnVerticalAlign,
                ),
                child: SizedBox(
                  width: desktopTextWidth,
                  child: _buildDesktopColumn(
                    slide,
                    maxHeight: constraints.maxHeight,
                    maxWidth: desktopTextWidth,
                    isActive: isActive,
                  ),
                ),
              );
            },
          );
    return CrossfadeSwap(
      child: KeyedSubtree(
        key: ValueKey(slide.id),
        child: body,
      ),
    );
  }

  Widget _buildDesktopColumn(
    CinematicHeroSlide slide, {
    required double maxHeight,
    required double maxWidth,
    bool isActive = true,
  }) {
    final layout = widget.layout;
    final overviewStyle = TextStyle(
      fontSize: layout.scaledType(layout.resolvedOverviewFontSize),
      height: layout.resolvedOverviewLineHeight,
      letterSpacing: 0.1,
      color: const Color(0x99FFFFFF),
    );
    final titleGap = layout.scaledChrome(layout.resolvedTitleMetaGap);
    final actionGap = layout.scaledChrome(layout.resolvedMetaActionsGap);
    final metaSlotHeight = layout.scaledChrome(layout.resolvedMetaSlotHeight);
    final metaOverviewGap =
        layout.scaledChrome(layout.resolvedMetaOverviewGap);
    final actionRowH = layout.tvDensity
        ? ShellTokens.controlHeightTv
        : ShellTokens.shellButtonHeight;
    final overview = slide.overview.trim();
    final upcomingReserve = slide.isUpcoming
        ? layout.scaledChrome(layout.resolvedUpcomingNoticeReserve)
        : 0.0;
    // Pass the same scaled chrome the Column paints. Host/metrics already
    // resolve profile min title — do not scale heroMinTitleHeight again.
    final layoutFit = heroDesktopTextLayout(
      maxHeight: maxHeight,
      hasOverview: overview.isNotEmpty,
      minTitleHeight: layout.heroMinTitleHeight,
      reservedBelowOverview: upcomingReserve,
      titleSlotHeight: layout.scaledChrome(layout.resolvedTitleSlotHeight),
      metaSlotHeight: metaSlotHeight,
      titleMetaGap: titleGap,
      metaActionsGap: actionGap,
      metaOverviewGap: metaOverviewGap,
      overviewMaxLines: layout.resolvedOverviewMaxLines,
      overviewFontSize: layout.scaledType(layout.resolvedOverviewFontSize),
      overviewLineHeight: layout.resolvedOverviewLineHeight,
      actionRowHeight: actionRowH,
    );

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRect(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (layoutFit.titleHeight > 0)
                SizedBox(
                  height: layoutFit.titleHeight,
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: _buildTitle(
                      slide,
                      desktop: true,
                      slotHeight: layoutFit.titleHeight,
                    ),
                  ),
                ),
              if (layoutFit.showMeta) ...[
                SizedBox(height: titleGap),
                SizedBox(
                  height: metaSlotHeight,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _buildMetaRow(slide, singleLine: true),
                  ),
                ),
              ],
              if (layoutFit.showOverview) ...[
                SizedBox(height: metaOverviewGap),
                SizedBox(
                  height: layoutFit.overviewSlotHeight,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: HeroOverviewText(
                      overview: overview,
                      style: overviewStyle,
                      maxLines: layoutFit.overviewMaxLines,
                      shrinkWrap: false,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (layoutFit.actionRowHeight > 0 || upcomingReserve > 0) ...[
          SizedBox(height: actionGap),
          widget.upcomingNoticeBuilder?.call(context, slide) ??
              const SizedBox.shrink(),
          SizedBox(
            height: layoutFit.actionRowHeight,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: widget.actionRowBuilder
                        ?.call(context, slide, isActive: isActive) ??
                    const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ],
    );

    // Bleed rail can leave < chrome height; fitter drops title/meta/overview
    // but CTA intrinsic height still needs a last-resort scaleDown.
    // FittedBox measures with unbounded max constraints — pin width so the
    // meta Row's Flexible/Expanded children stay legal.
    if (!maxHeight.isFinite || maxHeight <= 0) return column;
    final sized = SizedBox(width: maxWidth, child: column);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topLeft,
        child: sized,
      ),
    );
  }

  Widget _buildCompactColumn(
    CinematicHeroSlide slide, {
    required double maxHeight,
    required double maxWidth,
    bool isActive = true,
  }) {
    final layout = widget.layout;
    final tv = layout.tvDensity;
    final overview = slide.overview.trim();
    final titleMetaGap = tv ? layout.scaledChrome(8) : 8.0;
    final metaOverviewGap = tv ? layout.scaledChrome(8) : 8.0;
    final actionGap = tv
        ? layout.scaledChrome(ShellTokens.heroActionGapDesktop)
        : ShellTokens.heroActionGapDesktop;
    final overviewFontSize =
        tv ? layout.scaledType(13) : 13.0;
    const overviewHeight = 1.35;
    const overviewMaxLinesCap = 3;
    final metaReserve = tv ? layout.scaledChrome(24) : 24.0;
    final overviewLineHeight = overviewFontSize * overviewHeight;
    final ctaH =
        tv ? ShellTokens.controlHeightTv : ShellTokens.shellButtonHeight;
    // Worst-case chrome so synopsis shrinks/drops before the Column overflows.
    final fixedChrome = (tv
            ? layout.scaledChrome(ShellTokens.heroTitleSlotHeightCompact)
            : ShellTokens.heroTitleSlotHeightCompact) +
        titleMetaGap +
        metaReserve +
        actionGap +
        ctaH;
    var overviewLines = 0;
    if (overview.isNotEmpty) {
      final budget = maxHeight - fixedChrome - metaOverviewGap;
      if (budget >= overviewLineHeight) {
        overviewLines =
            (budget / overviewLineHeight).floor().clamp(0, overviewMaxLinesCap);
        // HeroOverviewText adds a Read More row when truncated — keep room.
        while (overviewLines > 0) {
          final need =
              overviewLines * overviewLineHeight + 8 + overviewLineHeight;
          if (need <= budget) break;
          overviewLines--;
        }
      }
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: maxWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTitle(slide, compact: true),
          SizedBox(height: titleMetaGap),
          _buildMetaRow(slide, singleLine: true),
          if (overviewLines > 0) ...[
            SizedBox(height: metaOverviewGap),
            HeroOverviewText(
              overview: overview,
              style: TextStyle(
                fontSize: overviewFontSize,
                height: overviewHeight,
                color: const Color(0x99FFFFFF),
              ),
              maxLines: overviewLines,
              shrinkWrap: true,
            ),
          ],
          SizedBox(height: actionGap),
          widget.upcomingNoticeBuilder?.call(context, slide) ??
              const SizedBox.shrink(),
          widget.actionRowBuilder?.call(context, slide, isActive: isActive) ??
              const SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _buildTitle(
    CinematicHeroSlide slide, {
    bool desktop = false,
    bool compact = false,
    double? slotHeight,
  }) {
    final logo = (slide.logoUrl ?? '').trim();
    return HeroTitle(
      key: ValueKey(slide.id),
      title: slide.title,
      logoUrl: logo.isEmpty ? null : logo,
      style: HeroTitleStyle.home,
      isLandscape: false,
      desktop: desktop,
      compact: compact,
      slotHeight: slotHeight,
      logoMaxHeight: widget.layout.logoMaxHeight,
      maxWidth: desktop ? widget.layout.resolvedTextColumnWidth : null,
      tvDensity: widget.layout.tvDensity,
      plainTitle: widget.layout.plainTitle,
      selectable: widget.layout.selectableTitle,
    );
  }

  Widget _buildMetaRow(CinematicHeroSlide slide, {bool singleLine = false}) {
    final layout = widget.layout;
    final metaFont = layout.scaledType(13);
    final genreFont = layout.scaledType(12);
    final gap = layout.scaledChrome(10, floor: 7.0, ceil: 10.0);
    final vote = slide.rating ?? 0;
    final rating = vote > 0
        ? Container(
            padding: EdgeInsets.symmetric(
              horizontal: layout.scaledChrome(8, floor: 4.0, ceil: 8.0),
              vertical: layout.scaledChrome(4, floor: 2.0, ceil: 4.0),
            ),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius:
                  BorderRadius.circular(layout.scaledChrome(20, floor: 10.0, ceil: 20.0)),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.star_rounded,
                  size: layout.scaledChrome(14, floor: 10.0, ceil: 14.0),
                  color: Colors.amber,
                ),
                SizedBox(width: layout.scaledChrome(4, floor: 2.0, ceil: 4.0)),
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

    String? year = slide.year;
    if ((year == null || year.isEmpty) == false && year!.contains('-')) {
      year = year.split('-').first;
    }

    Widget? typeBadge;
    if ((slide.badge ?? '').isNotEmpty) {
      typeBadge = _badge(slide.badge!);
    } else if (slide.mediaType == 'tv') {
      typeBadge = _badge('TV');
    } else if (slide.mediaType == 'movie') {
      typeBadge = _badge('FILM');
    }

    final genres = slide.genres.take(3).join('  ·  ');

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
                  if (year != null && year.isNotEmpty) ...[
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
                  if ((slide.statusChip ?? '').isNotEmpty &&
                      slide.statusChip != slide.badge) ...[
                    SizedBox(width: gap),
                    _badge(slide.statusChip!),
                  ],
                ],
              ),
            ),
          ),
          if (genres.isNotEmpty) ...[
            SizedBox(width: gap),
            Expanded(
              child: Text(
                genres,
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
          if (year != null && year.isNotEmpty)
            Text(
              year,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ?typeBadge,
          if ((slide.statusChip ?? '').isNotEmpty &&
              slide.statusChip != slide.badge)
            _badge(slide.statusChip!),
          if (genres.isNotEmpty)
            Text(
              genres,
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

  Widget _badge(String label) {
    final layout = widget.layout;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: layout.scaledChrome(8, floor: 4.0, ceil: 8.0),
        vertical: layout.scaledChrome(3, floor: 2.0, ceil: 3.0),
      ),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(layout.scaledChrome(4, floor: 2.0, ceil: 4.0)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: layout.scaledType(10),
          fontWeight: FontWeight.bold,
          color: Colors.white60,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildStepIndicators({Axis axis = Axis.vertical}) {
    final count = widget.slides.length;
    if (count < 2) return const SizedBox.shrink();
    final dots = List<Widget>.generate(count, (i) {
      final active = i == _heroIndex % count;
      return Padding(
        padding: EdgeInsets.symmetric(
          vertical: axis == Axis.vertical ? 4 : 0,
          horizontal: axis == Axis.horizontal ? 4 : 0,
        ),
        child: AnimatedContainer(
          duration: ForjaMotionTheme.of(context).playButtonLift.duration,
          width: active ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: Colors.white.withValues(alpha: active ? 0.95 : 0.35),
          ),
        ),
      );
    });
    if (axis == Axis.vertical) {
      return Column(mainAxisSize: MainAxisSize.min, children: dots);
    }
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: dots);
  }
}

/// Legacy gallery alias — same paint as [CinematicHero].
typedef HubCinematicHero = CinematicHero;
