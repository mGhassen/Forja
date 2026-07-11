import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:forja/shared/widgets/hero/hero_pill_buttons.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
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
    this.tvTabId,
  });

  final List<HubHeroSlide> slides;
  final double? firstRowHeight;
  final VoidCallback? onSearch;
  final String? tvTabId;

  @override
  State<HubCinematicHero> createState() => _HubCinematicHeroState();
}

class _HubCinematicHeroState extends State<HubCinematicHero> {
  static const int _loopLength = 10000;
  static const int _loopStart = 5000;

  late final PageController _controller =
      PageController(initialPage: _loopStart);
  final FocusNode _tvHeroPlayFocus = FocusNode(debugLabel: 'hub-hero-play');
  final FocusNode _tvSearchFocus = FocusNode(debugLabel: 'hub-hero-search');
  Timer? _timer;
  int _index = 0;
  bool _tvHeroInitialFocusDone = false;

  bool get _compact {
    if (ShellScope.metricsOf(context).usesTvDensity) return false;
    return MediaQuery.sizeOf(context).width < ShellTokens.heroDesktopMinBodyWidth;
  }

  @override
  void initState() {
    super.initState();
    ShellTvFocus.homeHeroPlay = _tvHeroPlayFocus;
    ShellTvFocus.hubHeroSearch = _tvSearchFocus;
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
    if (ShellTvFocus.homeHeroPlay == _tvHeroPlayFocus) {
      ShellTvFocus.homeHeroPlay = null;
    }
    if (ShellTvFocus.hubHeroSearch == _tvSearchFocus) {
      ShellTvFocus.hubHeroSearch = null;
    }
    _controller.dispose();
    _tvHeroPlayFocus.dispose();
    _tvSearchFocus.dispose();
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
            shellHeroNextRowPeekFraction(context);
    final reservedBelow = shellHomeRowSpacing(context) +
        firstRowHeight +
        nextRowPeek;
    final target = screenH * shellHeroHeightFraction(context);
    final maxHero = screenH - topBar - reservedBelow;
    return _snapToDevicePixels(
      math.min(target, math.max(shellHeroMinHeight(context), maxHero)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slides = widget.slides;
    if (slides.isEmpty) {
      return homeCinematicHeroShimmer(context);
    }

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

    final heroSlide = slides[_index];
    final backdropHeight = _heroBodyHeight();
    final topBarBleed = MediaQuery.paddingOf(context).top;
    final imageHeight = _snapToDevicePixels(backdropHeight + topBarBleed);
    final textTop = topBarBleed + ShellTokens.shellHeaderTopPadding;
    final tvNav = ShellScope.inputPolicyOf(context).useFocusableMoodChips;

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
              right: shellHomeSectionHorizontalPadding(context),
              child: tvNav
                  ? shellFocusableTap(
                      context: context,
                      onTap: widget.onSearch!,
                      borderRadius: shellScaled(context, 22).clamp(14.0, 22.0),
                      scaleOnFocus: ShellTokens.focusActiveScale,
                      focusNode: _tvSearchFocus,
                      tvTabId: widget.tvTabId,
                      tvZone: ShellTvZone.topBar,
                      onDownEdge: ShellTvFocus.focusHomeHeroPlay,
                      child: SizedBox(
                        height: shellScaled(context, 34).clamp(24.0, 34.0),
                        width: shellScaled(context, 44).clamp(32.0, 44.0),
                        child: Center(
                          child: Icon(
                            Icons.search_rounded,
                            color: Colors.white,
                            size: shellScaled(context, 30).clamp(20.0, 30.0),
                          ),
                        ),
                      ),
                    )
                  : ForjaPlainIcon(
                      icon: Icons.search_rounded,
                      color: Colors.white,
                      size: shellScaled(context, 30).clamp(20.0, 30.0),
                      hitSize: shellScaled(context, 44).clamp(32.0, 44.0),
                      onTap: widget.onSearch,
                    ),
            ),
          Positioned(
            left: shellHomeSectionHorizontalPadding(context),
            top: textTop,
            right: _compact
                ? shellScaled(context, 20).clamp(12.0, 20.0)
                : shellScaled(context, 48).clamp(24.0, 48.0),
            bottom: shellScaled(context, 16).clamp(8.0, 16.0),
            child: _compact
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      return ClipRect(
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: _buildCompactTextColumn(
                            heroSlide,
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
            right: shellScaled(context, 20).clamp(10.0, 20.0),
            bottom: _compact ? shellScaled(context, 16).clamp(8.0, 16.0) : null,
            top: _compact ? null : 0,
            height: _compact ? null : imageHeight,
            child: _compact
                ? _buildStepIndicators(slides, axis: Axis.horizontal)
                : Align(
                    alignment: Alignment.centerRight,
                    child: _buildStepIndicators(slides),
                  ),
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

  Widget _buildCompactTextColumn(
    HubHeroSlide slide, {
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
                child: _buildTitle(slide, compact: true),
              ),
            ),
            SizedBox(height: metaGap),
            SizedBox(
              height: metaRowHeight,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _buildMetaRow(slide),
              ),
            ),
            SizedBox(height: actionGap),
            _buildActionRow(slide),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildTitle(slide, compact: true),
        SizedBox(height: shellHeroMetaGap(context)),
        _buildMetaRow(slide),
        SizedBox(height: shellHeroActionGap(context)),
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
          fontSize: shellScaled(context, compact ? 28 : 40)
              .clamp(compact ? 18.0 : 24.0, compact ? 28.0 : 40.0),
          fontWeight: FontWeight.w900,
          height: 1.05,
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  Widget _buildMetaRow(HubHeroSlide slide) {
    final metaFont = shellScaled(context, 13).clamp(9.0, 13.0);
    final genreFont = shellScaled(context, 12).clamp(8.0, 12.0);
    final gap = shellScaled(context, 10).clamp(7.0, 10.0);
    final rating = slide.rating != null && slide.rating! > 0
        ? Container(
            padding: EdgeInsets.symmetric(
              horizontal: shellScaled(context, 8).clamp(4.0, 8.0),
              vertical: shellScaled(context, 4).clamp(2.0, 4.0),
            ),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(
                shellScaled(context, 20).clamp(10.0, 20.0),
              ),
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
                  slide.rating!.toStringAsFixed(1),
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

    return Row(
      children: [
        Flexible(
          fit: FlexFit.loose,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (rating != null) rating,
              if (slide.year != null && slide.year!.isNotEmpty) ...[
                if (rating != null) SizedBox(width: gap),
                Text(
                  slide.year!,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: metaFont,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              if (slide.badge != null && slide.badge!.isNotEmpty) ...[
                SizedBox(width: gap),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: shellScaled(context, 8).clamp(4.0, 8.0),
                    vertical: shellScaled(context, 3).clamp(2.0, 3.0),
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                    borderRadius: BorderRadius.circular(
                      shellScaled(context, 4).clamp(2.0, 4.0),
                    ),
                  ),
                  child: Text(
                    slide.badge!,
                    style: TextStyle(
                      fontSize: shellScaled(context, 10).clamp(7.0, 10.0),
                      fontWeight: FontWeight.bold,
                      color: Colors.white60,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (slide.genres.isNotEmpty) ...[
          SizedBox(width: gap),
          Expanded(
            child: Text(
              slide.genres.take(3).join('  ·  '),
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

  Widget _buildActionRow(HubHeroSlide slide) {
    final policy = ShellScope.inputPolicyOf(context);
    final tvNav = policy.useFocusableMoodChips;
    final play = HeroPillPlayButton(
      label: 'Play',
      onTap: slide.onPlay,
      focusNode: policy.heroPlayAutoFocus ? _tvHeroPlayFocus : null,
      tvTabId: tvNav ? widget.tvTabId : null,
      onUpEdge: tvNav ? ShellTvFocus.focusHubHeroSearch : null,
      onKeyEvent: tvNav
          ? (node, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                if (ShellTvFocusCoordinator.focusActiveNavTab()) {
                  return KeyEventResult.handled;
                }
              }
              return KeyEventResult.ignored;
            }
          : null,
    );
    return HeroPillActionRow(
      children: [
        if (tvNav)
          FocusTraversalOrder(order: const NumericFocusOrder(1), child: play)
        else
          play,
        const SizedBox(width: 10),
        HeroPillIconGroup(
          tvFocusOrderStart: tvNav ? 2 : null,
          tvTabId: tvNav ? widget.tvTabId : null,
          onUpEdge: tvNav ? ShellTvFocus.focusHubHeroSearch : null,
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
