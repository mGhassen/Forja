import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
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
    this.scale = 1.0,
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
  final double scale;

  double scaled(double value) => value * scale;
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
  Timer? _heroTimer;
  int _heroIndex = 0;
  double? _heroPageViewportWidth;

  PageController get pageController => _heroController;
  int get heroIndex => _heroIndex;

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
      if (!_heroController.hasClients) return;
      _heroController.nextPage(
        duration: const Duration(milliseconds: 1000),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _goToHeroStep(int realIndex, {required bool instant}) {
    final count = widget.slides.length;
    if (count <= 0 || !_heroController.hasClients) return;
    final target = _heroLoopStart + (realIndex % count);
    if (instant) {
      _heroController.jumpToPage(target);
    } else {
      _heroController.animateToPage(
        target,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _jumpHeroToReal(int realIndex, int count) {
    if (!mounted || !_heroController.hasClients || count <= 0) return;
    final target = _heroLoopStart + (realIndex % count);
    if ((_heroController.page?.round() ?? target) == target) return;
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
        if (mounted && _heroController.hasClients) {
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
    final compact = layout.compact;
    final pageBleed = widget.pageBottomChild != null && !compact;
    if (pageBleed) {
      return _snapToDevicePixels(
        context,
        MediaQuery.sizeOf(context).height *
                ShellTokens.homeBackdropViewportFraction +
            layout.topBarBleed +
            ShellTokens.homePageBottomSectionDownOffset,
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
    final pageBleed = widget.pageBottomChild != null && !compact;
    final imageHeight = _backdropHeight(context);
    final textTop = layout.topBarBleed + ShellTokens.heroTextColumnTopInsetDesktop;
    final compactRightInset = compact ? layout.heroCompactRightInset : 48.0;
    final textRight = compact
        ? layout.scaled(compactRightInset).clamp(12.0, compactRightInset)
        : layout.scaled(48).clamp(24.0, 48.0);
    final textBottom = layout.scaled(16).clamp(8.0, 16.0);
    final textBottomInset = pageBleed
        ? layout.firstCatalogRowHeight +
            ShellTokens.homePageBottomSectionTopPadding +
            ShellTokens.homePageBottomSectionDownOffset +
            textBottom
        : textBottom;
    final textLeft = layout.sectionHorizontalPadding;
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
    final heroSlide = slides[_heroIndex % slides.length];

    return SizedBox(
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
            right: layout.scaled(20).clamp(10.0, 20.0),
            bottom: compact ? layout.scaled(16).clamp(8.0, 16.0) : null,
            top: compact ? null : 0,
            height: compact ? null : imageHeight,
            child: compact
                ? _buildStepIndicators(axis: Axis.horizontal)
                : Align(
                    alignment: Alignment.centerRight,
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
            final page = _heroController.hasClients
                ? (_heroController.page ?? index.toDouble())
                : index.toDouble();
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
    return compact
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
                alignment: const Alignment(
                  -1,
                  ShellTokens.heroTextColumnVerticalAlign,
                ),
                child: SizedBox(
                  width: desktopTextWidth,
                  child: _buildDesktopColumn(
                    slide,
                    maxHeight: constraints.maxHeight,
                    isActive: isActive,
                  ),
                ),
              );
            },
          );
  }

  Widget _buildDesktopColumn(
    CinematicHeroSlide slide, {
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
    final overview = slide.overview.trim();
    final upcomingReserve = slide.isUpcoming
        ? ShellTokens.heroUpcomingNoticeReserveDesktop
        : 0.0;
    final layoutFit = heroDesktopTextLayout(
      maxHeight: maxHeight,
      hasOverview: overview.isNotEmpty,
      minTitleHeight: widget.layout.heroMinTitleHeight,
      reservedBelowOverview: upcomingReserve,
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
              const SizedBox(height: titleGap),
              SizedBox(
                height: ShellTokens.heroMetaSlotHeightDesktop,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _buildMetaRow(slide, singleLine: true),
                ),
              ),
              if (layoutFit.showOverview) ...[
                SizedBox(height: ShellTokens.heroMetaOverviewGapDesktop),
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
        const SizedBox(height: actionGap),
        widget.upcomingNoticeBuilder?.call(context, slide) ??
            const SizedBox.shrink(),
        widget.actionRowBuilder?.call(context, slide, isActive: isActive) ??
            const SizedBox.shrink(),
      ],
    );
  }

  Widget _buildCompactColumn(
    CinematicHeroSlide slide, {
    required double maxHeight,
    required double maxWidth,
    bool isActive = true,
  }) {
    final overview = slide.overview.trim();
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: maxWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTitle(slide, compact: true),
          const SizedBox(height: 8),
          _buildMetaRow(slide),
          if (overview.isNotEmpty) ...[
            const SizedBox(height: 8),
            HeroOverviewText(
              overview: overview,
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                color: Color(0x99FFFFFF),
              ),
              maxLines: 3,
              shrinkWrap: true,
            ),
          ],
          const SizedBox(height: 12),
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
      tvDensity: widget.layout.tvDensity,
      plainTitle: widget.layout.plainTitle,
      selectable: widget.layout.selectableTitle,
    );
  }

  Widget _buildMetaRow(CinematicHeroSlide slide, {bool singleLine = false}) {
    final layout = widget.layout;
    final metaFont = layout.scaled(13).clamp(9.0, 13.0);
    final genreFont = layout.scaled(12).clamp(8.0, 12.0);
    final gap = layout.scaled(10).clamp(7.0, 10.0);
    final vote = slide.rating ?? 0;
    final rating = vote > 0
        ? Container(
            padding: EdgeInsets.symmetric(
              horizontal: layout.scaled(8).clamp(4.0, 8.0),
              vertical: layout.scaled(4).clamp(2.0, 4.0),
            ),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius:
                  BorderRadius.circular(layout.scaled(20).clamp(10.0, 20.0)),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.star_rounded,
                  size: layout.scaled(14).clamp(10.0, 14.0),
                  color: Colors.amber,
                ),
                SizedBox(width: layout.scaled(4).clamp(2.0, 4.0)),
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
        horizontal: layout.scaled(8).clamp(4.0, 8.0),
        vertical: layout.scaled(3).clamp(2.0, 3.0),
      ),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(layout.scaled(4).clamp(2.0, 4.0)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: layout.scaled(10).clamp(7.0, 10.0),
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
          duration: const Duration(milliseconds: 200),
          width: active ? 10 : 6,
          height: active ? 10 : 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
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
