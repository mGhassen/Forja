import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/widgets/hero/hero_pill_buttons.dart';
import 'package:forja/shared/widgets/hero_overview_text.dart';
import 'package:forja/shared/widgets/home_loading_skeleton.dart';
import 'package:forja/shared/widgets/hub/hub_catalog_section.dart';

class HubHeroSlide {
  const HubHeroSlide({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.overview = '',
    this.rating,
    this.year,
    this.badge,
    this.genres = const [],
    required this.onPlay,
    required this.onDetails,
  });

  final String id;
  final String title;
  final String imageUrl;
  final String overview;
  final double? rating;
  final String? year;
  final String? badge;
  final List<String> genres;
  final VoidCallback onPlay;
  final VoidCallback onDetails;
}

class HubCinematicHero extends StatefulWidget {
  const HubCinematicHero({
    super.key,
    required this.slides,
    this.firstRowHeight,
    this.onSearch,
  });

  final List<HubHeroSlide> slides;
  final double? firstRowHeight;
  final VoidCallback? onSearch;

  @override
  State<HubCinematicHero> createState() => _HubCinematicHeroState();
}

class _HubCinematicHeroState extends State<HubCinematicHero> {
  static const int _loopLength = 10000;
  static const int _loopStart = 5000;

  late final PageController _controller =
      PageController(initialPage: _loopStart);
  Timer? _timer;
  int _index = 0;

  bool get _compact =>
      MediaQuery.sizeOf(context).width < ShellTokens.heroDesktopMinBodyWidth;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant HubCinematicHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slides.length != widget.slides.length) {
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.slides.length < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted || !_controller.hasClients) return;
      final nextPage = (_controller.page?.round() ?? _loopStart) + 1;
      _controller.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 1000),
        curve: Curves.fastOutSlowIn,
      );
    });
  }

  void _onPageChanged(int pageIndex) {
    final slides = widget.slides;
    if (slides.isEmpty) return;
    final count = slides.length;
    final realIndex = pageIndex % count;
    if (_index != realIndex) {
      setState(() => _index = realIndex);
    }

    if (pageIndex <= 2 || pageIndex >= _loopLength - 3) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_controller.hasClients) return;
        _controller.jumpToPage(_loopStart + realIndex);
      });
    }
  }

  void _goToStep(int stepIndex) {
    final slides = widget.slides;
    if (!_controller.hasClients || slides.isEmpty) return;
    final count = slides.length;
    final currentPage = _controller.page?.round() ?? _loopStart;
    final currentReal = currentPage % count;
    if (currentReal == stepIndex) return;

    var delta = stepIndex - currentReal;
    if (delta > count ~/ 2) {
      delta -= count;
    } else if (delta < -count ~/ 2) {
      delta += count;
    }

    _controller.animateToPage(
      currentPage + delta,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );
  }

  double _snapToDevicePixels(double value) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return (value * dpr).round() / dpr;
  }

  double _heroBodyHeight() {
    if (_compact) {
      final screenH = MediaQuery.sizeOf(context).height;
      final target = screenH * ShellTokens.heroHeightFractionCompact;
      return _snapToDevicePixels(
        math.max(ShellTokens.heroMinHeightCompact, target),
      );
    }

    final screenH = MediaQuery.sizeOf(context).height;
    final topBar = MediaQuery.paddingOf(context).top;
    final firstRowHeight = widget.firstRowHeight ??
        HubCatalogSection.sectionHeight(context, compactTop: true);
    final nextRowPeek =
        HubCatalogSection.sectionHeight(context) *
            ShellTokens.heroNextRowPeekFraction;
    final reservedBelow = ShellTokens.homeRowSpacing +
        firstRowHeight +
        nextRowPeek;
    final target = screenH * ShellTokens.heroHeightFractionDesktop;
    final maxHero = screenH - topBar - reservedBelow;
    return _snapToDevicePixels(
      math.min(target, math.max(320.0, maxHero)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slides = widget.slides;
    if (slides.isEmpty) {
      return homeCinematicHeroShimmer(context);
    }

    final heroSlide = slides[_index];
    final backdropHeight = _heroBodyHeight();
    final topBarBleed = MediaQuery.paddingOf(context).top;
    final imageHeight = _snapToDevicePixels(backdropHeight + topBarBleed);
    final textTop = topBarBleed + ShellTokens.shellHeaderTopPadding;

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
            child: _buildBackdrop(slides),
          ),
          if (widget.onSearch != null)
            Positioned(
              top: textTop,
              right: ShellTokens.bodyHorizontalPadding,
              child: ForjaPlainIcon(
                icon: Icons.search_rounded,
                color: Colors.white,
                size: 30,
                hitSize: 44,
                onTap: widget.onSearch,
              ),
            ),
          Positioned(
            left: ShellTokens.bodyHorizontalPadding,
            top: textTop,
            right: _compact ? 20 : 48,
            bottom: 16,
            child: _compact
                ? _buildCompactTextColumn(heroSlide)
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
                            child: _buildDesktopTextColumn(
                              heroSlide,
                              maxHeight: constraints.maxHeight,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Positioned(
            right: 20,
            bottom: _compact ? 16 : null,
            top: _compact ? null : 0,
            height: _compact ? null : imageHeight,
            child: _compact
                ? _buildStepIndicators(slides, axis: Axis.horizontal)
                : Center(child: _buildStepIndicators(slides)),
          ),
        ],
      ),
    );
  }

  Widget _buildBackdrop(List<HubHeroSlide> slides) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final shellBg = Theme.of(context).scaffoldBackgroundColor;
        final imageLeft = constraints.maxWidth *
            (_compact
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
                  controller: _controller,
                  itemCount: _loopLength,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, index) {
                    final slide = slides[index % slides.length];
                    return CachedNetworkImage(
                      imageUrl: slide.imageUrl,
                      fit: BoxFit.cover,
                      alignment: Alignment.centerRight,
                      filterQuality: FilterQuality.medium,
                      placeholder: (c, u) => ColoredBox(color: shellBg),
                      errorWidget: (c, u, e) => ColoredBox(color: shellBg),
                    );
                  },
                ),
              ),
              _buildImageGradients(
                shellBg,
                imageStartFraction: _compact
                    ? ShellTokens.heroImageStartFractionCompact
                    : ShellTokens.heroImageStartFraction,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImageGradients(
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

  Widget _buildCompactTextColumn(HubHeroSlide slide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildTitle(slide, compact: true),
        const SizedBox(height: 10),
        _buildMetaRow(slide),
        const SizedBox(height: 12),
        _buildActionRow(slide),
      ],
    );
  }

  Widget _buildDesktopTextColumn(
    HubHeroSlide slide, {
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
    const minTitleHeight = 72.0;

    final baseWithoutOverview = titleGap +
        ShellTokens.heroMetaSlotHeightDesktop +
        actionGap +
        ShellTokens.shellButtonHeight;
    final overviewBlock = ShellTokens.heroMetaOverviewGapDesktop +
        ShellTokens.heroOverviewSlotHeightDesktop;

    var titleHeight = ShellTokens.heroTitleSlotHeightDesktop;
    final showOverview = slide.overview.isNotEmpty &&
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
            child: _buildTitle(slide),
          ),
        ),
        const SizedBox(height: titleGap),
        SizedBox(
          height: ShellTokens.heroMetaSlotHeightDesktop,
          child: Align(
            alignment: Alignment.centerLeft,
            child: _buildMetaRow(slide),
          ),
        ),
        if (showOverview) ...[
          SizedBox(height: ShellTokens.heroMetaOverviewGapDesktop),
          SizedBox(
            height: ShellTokens.heroOverviewSlotHeightDesktop,
            child: Align(
              alignment: Alignment.topLeft,
              child: HeroOverviewText(
                overview: slide.overview,
                style: overviewStyle,
                maxLines: ShellTokens.heroOverviewMaxLinesDesktop,
                shrinkWrap: false,
                onReadMore: slide.onDetails,
              ),
            ),
          ),
        ],
        const SizedBox(height: actionGap),
        _buildActionRow(slide),
      ],
    );
  }

  Widget _buildTitle(HubHeroSlide slide, {bool compact = false}) {
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
      child: Text(
        slide.title,
        key: ValueKey(slide.id),
        maxLines: compact ? 2 : 3,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white,
          fontSize: compact ? 28 : 40,
          fontWeight: FontWeight.w900,
          height: 1.05,
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  Widget _buildMetaRow(HubHeroSlide slide) {
    final rating = slide.rating != null && slide.rating! > 0
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                const SizedBox(width: 4),
                Text(
                  slide.rating!.toStringAsFixed(1),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          )
        : null;

    return Row(
      children: [
        if (rating != null) rating,
        if (slide.year != null && slide.year!.isNotEmpty) ...[
          if (rating != null) const SizedBox(width: 10),
          Text(
            slide.year!,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        if (slide.badge != null && slide.badge!.isNotEmpty) ...[
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              slide.badge!,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white60,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
        if (slide.genres.isNotEmpty) ...[
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              slide.genres.take(3).join('  ·  '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionRow(HubHeroSlide slide) {
    return Row(
      children: [
        HeroPillPlayButton(
          label: 'Play',
          onTap: slide.onPlay,
        ),
        const SizedBox(width: 10),
        HeroPillIconGroup(
          slots: [
            HeroPillIconSlot(
              icon: Icons.info_outline_rounded,
              tooltip: 'Details',
              onTap: slide.onDetails,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStepIndicators(
    List<HubHeroSlide> slides, {
    Axis axis = Axis.vertical,
  }) {
    const selectedColor = Colors.white;
    final unselectedColor = Colors.white.withValues(alpha: 0.25);

    final dots = List.generate(slides.length, (i) {
      final selected = i == _index;
      final isVertical = axis == Axis.vertical;
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => _goToStep(i),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: isVertical
                ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
                : const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              width: isVertical
                  ? (selected ? 8.0 : 6.0)
                  : (selected ? 28.0 : 8.0),
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

    return axis == Axis.vertical
        ? Column(mainAxisSize: MainAxisSize.min, children: dots)
        : Row(mainAxisSize: MainAxisSize.min, children: dots);
  }
}
