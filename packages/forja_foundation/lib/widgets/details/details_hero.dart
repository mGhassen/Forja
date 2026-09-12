import 'package:flutter/material.dart';
import 'package:forja_foundation/theme/forja_theme_extension.dart';
import 'package:forja_foundation/tokens/forja_details_tokens.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/utils/cover_urls.dart';
import 'package:forja_foundation/widgets/catalog/rotating_hero_backdrop.dart';
import 'package:forja_foundation/widgets/details/facts_panel.dart';
import 'package:forja_foundation/widgets/details/hero_content_scrim.dart';
import 'package:forja_foundation/widgets/details/hero_overview_text.dart';
import 'package:forja_foundation/widgets/details/hero_title.dart';
import 'package:forja_foundation/widgets/details/play_row.dart';

/// Cinematic details hero — props + slots only (RFC-106 Zone A).
class DetailsHero extends StatelessWidget {
  const DetailsHero({
    super.key,
    required this.backdropUrl,
    this.backdropUrls = const [],
    required this.title,
    this.subtitle,
    this.genres = const [],
    this.metaParts = const [],
    this.rating,
    this.overview = '',
    this.facts = const [],
    this.logoUrl,
    this.actionRow,
    this.belowActionRow,
    this.belowActionRowFullWidth = false,
    this.belowActionRowGap = 20,
    this.scaleActionRow = true,
    this.contentScrim = false,
    this.height,
    this.progressBar,
    this.bodyOverlap,
    this.pageBottomChild,
    this.seriesProgress,
    this.showSeasonRail = false,
    this.chromeOnly = false,
    this.enableKenBurns = true,
    this.tvDensity = false,
    this.plainTitle = false,
    this.selectableTitle = false,
    this.factsValueMaxLines = 1,
  });

  final String backdropUrl;
  /// Extra hero backdrops (full URLs). Rotates randomly with [backdropUrl].
  final List<String> backdropUrls;
  final String title;
  final String? subtitle;
  final List<String> genres;
  final List<String> metaParts;
  final double? rating;
  final String overview;
  /// Right-column fact rows (host maps TMDB/rich extras → these).
  final List<MapEntry<String, String>> facts;
  final String? logoUrl;
  final Widget? actionRow;
  /// Fills remaining hero height below [actionRow] (live match streams, etc.).
  final Widget? belowActionRow;
  /// When true, [belowActionRow] spans the full hero content width instead of
  /// the narrow description column (40% on desktop).
  final bool belowActionRowFullWidth;
  /// Gap between [actionRow] and [belowActionRow] (live match streams can sit closer).
  final double belowActionRowGap;
  /// When false, [actionRow] keeps intrinsic size (no FittedBox scaleDown).
  final bool scaleActionRow;
  /// Full-bleed soft scrim from title through [belowActionRow] (live match details).
  final bool contentScrim;
  final double? height;
  /// Host wires [WatchProgressBar] (or any progress paint).
  final Widget? progressBar;
  final double? bodyOverlap;
  final Widget? pageBottomChild;
  final Widget? seriesProgress;
  /// When false, hero bleed matches episodes-only height (no season posters).
  final bool showSeasonRail;

  /// Title / meta / actions only — backdrop drawn elsewhere (e.g. live match
  /// detail with a full-bleed surface under a side streams rail).
  final bool chromeOnly;

  /// Host maps [ShellInputPolicy.kenBurnsBackdrop].
  final bool enableKenBurns;
  /// Host maps [ShellMetrics.usesTvDensity].
  final bool tvDensity;
  /// Host maps [ShellInputPolicy.useFocusableMoodChips].
  final bool plainTitle;
  /// Host maps desktop text select.
  final bool selectableTitle;
  final int factsValueMaxLines;

  @override
  Widget build(BuildContext context) {
    final showEpisodeRail = pageBottomChild != null;
    final h = height ??
        DetailsTokens.heroHeight(
          context,
          showEpisodeRail: showEpisodeRail,
          showSeasonRail: showSeasonRail,
        );
    final bleed = showEpisodeRail
        ? DetailsTokens.episodeRailBleed(showSeasonRail: showSeasonRail)
        : 0.0;
    final totalH = h + bleed;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final topInset = MediaQuery.paddingOf(context).top;
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final contentInset = DetailsTokens.contentHorizontalPadding(viewportWidth);
    final heroContentTop = topInset + DetailsTokens.heroContentTopInset;
    final railGap = DetailsTokens.heroContentToRailGap(h);
    final contentBottom = belowActionRow != null
        ? bottomInset
        : bleed + railGap + bottomInset;

    return SizedBox(
      height: totalH,
      width: double.infinity,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (!chromeOnly)
              DetailsHeroSurface(
                backdropUrl: backdropUrl,
                backdropUrls: backdropUrls,
                height: totalH,
                bodyOverlap: bodyOverlap ?? DetailsTokens.heroBodyOverlap,
                pageBottomChild: pageBottomChild,
                showSeasonRail: showSeasonRail,
                enableKenBurns: enableKenBurns,
              ),
            Positioned(
              left: 0,
              right: 0,
              top: heroContentTop,
              bottom: contentBottom,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final paddedContent = ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: ShellTokens.bodyMaxWidthDesktop,
                      maxHeight: constraints.maxHeight,
                      minHeight: belowActionRow != null
                          ? constraints.maxHeight
                          : 0,
                    ),
                    child: Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: contentInset),
                      child: _DetailsHeroLayout(
                        title: title,
                        subtitle: subtitle,
                        genres: genres,
                        metaParts: metaParts,
                        rating: rating,
                        overview: overview,
                        facts: facts,
                        logoUrl: logoUrl,
                        actionRow: actionRow,
                        belowActionRow: belowActionRow,
                        belowActionRowFullWidth: belowActionRowFullWidth,
                        belowActionRowGap: belowActionRowGap,
                        scaleActionRow: scaleActionRow,
                        progressBar: progressBar,
                        seriesProgress: seriesProgress,
                        tvDensity: tvDensity,
                        plainTitle: plainTitle,
                        selectableTitle: selectableTitle,
                        factsValueMaxLines: factsValueMaxLines,
                        // Inside horizontal padding — do not re-count inset.
                        availableWidth:
                            (constraints.maxWidth - 2 * contentInset)
                                .clamp(0.0, double.infinity),
                        maxHeight: constraints.maxHeight,
                      ),
                    ),
                  );
                  final Widget body;
                  if (contentScrim && belowActionRow != null) {
                    // Scrim is edge-to-edge; title / streams stay inset.
                    body = SizedBox(
                      width: double.infinity,
                      height: constraints.maxHeight,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          const Positioned.fill(child: KitHeroContentScrim()),
                          Align(
                            alignment: Alignment.topCenter,
                            child: paddedContent,
                          ),
                        ],
                      ),
                    );
                  } else if (belowActionRow != null) {
                    body = SizedBox(
                      width: double.infinity,
                      height: constraints.maxHeight,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: paddedContent,
                      ),
                    );
                  } else {
                    body = Align(
                      alignment: Alignment.topCenter,
                      child: paddedContent,
                    );
                  }
                  return body;
                },
              ),
            ),
            if (pageBottomChild != null)
              Positioned(
                left: 0,
                right: 0,
                top: h,
                bottom: 0,
                child: Align(
                  // Top of bleed = season-row Y (episode thumbs when no seasons).
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: ShellTokens.bodyMaxWidthDesktop,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        0,
                        DetailsTokens.episodeSectionTopPadding,
                        0,
                        DetailsTokens.episodeSectionBottomPadding,
                      ),
                      child: pageBottomChild!,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Full-bleed cinematic backdrop + gradients (no title chrome).
class DetailsHeroSurface extends StatelessWidget {
  const DetailsHeroSurface({
    super.key,
    required this.backdropUrl,
    this.backdropUrls = const [],
    this.height,
    this.bodyOverlap,
    this.pageBottomChild,
    this.showSeasonRail = false,
    this.enableKenBurns = true,
  });

  final String backdropUrl;
  final List<String> backdropUrls;
  final double? height;
  final double? bodyOverlap;
  final Widget? pageBottomChild;
  final bool showSeasonRail;
  final bool enableKenBurns;

  @override
  Widget build(BuildContext context) {
    final showEpisodeRail = pageBottomChild != null;
    final h = height ??
        DetailsTokens.heroHeight(
          context,
          showEpisodeRail: showEpisodeRail,
          showSeasonRail: showSeasonRail,
        );
    final bleed = showEpisodeRail
        ? DetailsTokens.episodeRailBleed(showSeasonRail: showSeasonRail)
        : 0.0;
    final totalH = h + bleed;
    final shellBg = ForjaThemeExtension.of(context).bgDark;
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final cinematicDesktop = viewportWidth >= 900;
    final resolvedOverlap = bodyOverlap ?? DetailsTokens.heroBodyOverlap;
    final pageBleed = bleed > 0;

    return SizedBox(
      height: totalH,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: shellBg),
          Positioned.fill(
            child: backdropUrl.isEmpty
                ? ColoredBox(color: shellBg)
                : RotatingHeroBackdrop(
                    imageUrls: backdropUrls.isNotEmpty
                        ? backdropUrls
                        : [backdropUrl],
                    showColorTint: false,
                    enableMotion: enableKenBurns,
                  ),
          ),
          if (cinematicDesktop)
            Positioned.fill(
              child: IgnorePointer(
                child: _CinematicHeroBottomGradient(
                  shellBg: shellBg,
                  overlap: pageBleed ? 0 : resolvedOverlap,
                  softFade: pageBleed,
                ),
              ),
            ),
          if (cinematicDesktop)
            Positioned.fill(
              child: IgnorePointer(
                child: _CinematicHeroSideGradient(shellBg: shellBg),
              ),
            ),
          if (!cinematicDesktop)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: pageBleed ? totalH * 0.42 : h * 0.55 + resolvedOverlap,
              child: IgnorePointer(
                child: _HeroBottomFade(shellBg: shellBg, soft: pageBleed),
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailsHeroLayout extends StatelessWidget {
  const _DetailsHeroLayout({
    required this.title,
    this.subtitle,
    required this.genres,
    required this.metaParts,
    this.rating,
    required this.overview,
    required this.facts,
    this.logoUrl,
    this.actionRow,
    this.belowActionRow,
    this.belowActionRowFullWidth = false,
    this.belowActionRowGap = 20,
    this.scaleActionRow = true,
    this.progressBar,
    this.seriesProgress,
    this.availableWidth,
    this.maxHeight,
    this.tvDensity = false,
    this.plainTitle = false,
    this.selectableTitle = false,
    this.factsValueMaxLines = 1,
  });

  final String title;
  final String? subtitle;
  final List<String> genres;
  final List<String> metaParts;
  final double? rating;
  final String overview;
  final List<MapEntry<String, String>> facts;
  final String? logoUrl;
  final Widget? actionRow;
  final Widget? belowActionRow;
  final bool belowActionRowFullWidth;
  final double belowActionRowGap;
  final bool scaleActionRow;
  final Widget? progressBar;
  final Widget? seriesProgress;
  final double? availableWidth;
  final double? maxHeight;
  final bool tvDensity;
  final bool plainTitle;
  final bool selectableTitle;
  final int factsValueMaxLines;

  Widget? _factsChild() {
    final panel = FactsPanel(
      rows: [
        for (final e in facts) (label: e.key, value: e.value),
      ],
      valueMaxLines: factsValueMaxLines,
    );
    return panel.hasContent ? panel : null;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 900;
    final leftColumnWidth = width * DetailsTokens.heroDescriptionWidthFraction;
    final rawLogo = (logoUrl ?? '').trim();
    final resolvedLogo =
        rawLogo.isEmpty ? null : resolveAbsoluteCoverUrl(rawLogo);
    final useFullWidthList =
        belowActionRow != null && belowActionRowFullWidth && maxHeight != null;
    // Live match streams: action row (Providers / Live TV + search) needs the
    // full content width — the 40% description column clips/scales the search.
    final headerWidth = useFullWidthList
        ? (availableWidth ?? width)
        : (compact ? (availableWidth ?? width) : leftColumnWidth);

    _DetailsHeroMainColumn buildMainColumn({
      Widget? belowAction,
      double? columnMaxHeight,
      double? contentWidth,
    }) {
      return _DetailsHeroMainColumn(
        logoUrl: resolvedLogo,
        title: title,
        subtitle: subtitle,
        genres: genres,
        metaParts: metaParts,
        rating: rating,
        overview: overview,
        actionRow: actionRow,
        belowActionRow: belowAction,
        belowActionRowGap: belowActionRowGap,
        scaleActionRow: scaleActionRow,
        progressBar: progressBar,
        seriesProgress: seriesProgress,
        maxContentWidth: contentWidth ?? headerWidth,
        maxHeight: columnMaxHeight,
        tvDensity: tvDensity,
        plainTitle: plainTitle,
        selectableTitle: selectableTitle,
      );
    }

    Widget factsOverlay({required Widget body}) {
      final factsChild = _factsChild();
      final hasFacts = factsChild != null;
      return SizedBox(
        width: double.infinity,
        height: maxHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            body,
            if (maxHeight != null)
              Align(
                alignment: Alignment.bottomRight,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 300,
                    maxHeight: maxHeight!,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedOpacity(
                      opacity: hasFacts ? 1 : 0,
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      child: factsChild == null
                          ? const SizedBox.shrink()
                          : ListView(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              physics: const ClampingScrollPhysics(),
                              children: [factsChild],
                            ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    if (useFullWidthList) {
      final listBody = SizedBox(
        width: double.infinity,
        height: maxHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildMainColumn(contentWidth: headerWidth),
            SizedBox(height: belowActionRowGap),
            Expanded(child: belowActionRow!),
          ],
        ),
      );

      if (compact) return listBody;
      return factsOverlay(body: listBody);
    }

    final mainColumn = buildMainColumn(
      belowAction: belowActionRow,
      columnMaxHeight: maxHeight,
    );

    if (compact) {
      return SizedBox(
        width: double.infinity,
        height: maxHeight,
        child: mainColumn,
      );
    }

    return factsOverlay(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: leftColumnWidth,
          height: maxHeight,
          child: mainColumn,
        ),
      ),
    );
  }
}

class _DetailsHeroMainColumn extends StatelessWidget {
  const _DetailsHeroMainColumn({
    this.logoUrl,
    required this.title,
    this.subtitle,
    required this.genres,
    required this.metaParts,
    this.rating,
    required this.overview,
    this.actionRow,
    this.belowActionRow,
    this.belowActionRowGap = 20,
    this.scaleActionRow = true,
    this.progressBar,
    this.seriesProgress,
    required this.maxContentWidth,
    this.maxHeight,
    this.tvDensity = false,
    this.plainTitle = false,
    this.selectableTitle = false,
  });

  static const _overviewStyle = TextStyle(
    fontSize: 14,
    height: 1.6,
    color: Color(0xB8FFFFFF),
  );
  /// Room for up to 3 lines of text title (auto-shrinks in [HeroTitle]).
  static const _textTitleBlockHeight = 96.0;
  static const _titleMinHeight = 32.0;
  static const _subtitleBlockHeight = 26.0;
  static const _genreBlockHeight = 20.0;
  static const _metaBlockHeight = 24.0;
  static const _overviewGap = 14.0;
  static const _actionGap = 18.0;
  static const _progressBlockHeight = 36.0;
  static const _seriesProgressBlockHeight = 28.0;

  final String? logoUrl;
  final String title;
  final String? subtitle;
  final List<String> genres;
  final List<String> metaParts;
  final double? rating;
  final String overview;
  final Widget? actionRow;
  final Widget? belowActionRow;
  final double belowActionRowGap;
  final bool scaleActionRow;
  final Widget? progressBar;
  final Widget? seriesProgress;
  final double maxContentWidth;
  final double? maxHeight;
  final bool tvDensity;
  final bool plainTitle;
  final bool selectableTitle;

  static double get _overviewSlotHeight =>
      _overviewStyle.fontSize! *
          _overviewStyle.height! *
          ShellTokens.heroOverviewMaxLinesDesktop +
      ShellTokens.heroOverviewReadMoreGap +
      _overviewStyle.fontSize! * _overviewStyle.height!;

  bool get _hasSubtitle =>
      subtitle != null && subtitle!.isNotEmpty && subtitle != title;

  bool get _hasLogo => logoUrl != null && logoUrl!.isNotEmpty;

  double get _defaultTitleHeight => _textTitleBlockHeight;

  Widget _titleWidget(double slotHeight) {
    return HeroTitle(
      title: title,
      logoUrl: logoUrl,
      slotHeight: slotHeight,
      tvDensity: tvDensity,
      plainTitle: plainTitle,
      selectable: selectableTitle,
    );
  }

  double _footerReserve({
    required bool showProgress,
    required bool showSeriesProgress,
  }) {
    var reserved = 0.0;
    if (actionRow != null) reserved += _actionGap + ShellTokens.shellButtonHeight;
    if (belowActionRow != null) reserved += belowActionRowGap;
    if (showProgress) reserved += 14 + _progressBlockHeight;
    if (showSeriesProgress) {
      reserved += (showProgress ? 8 : 14) + _seriesProgressBlockHeight;
    }
    return reserved;
  }

  /// Meta stack only - actions + progress are reserved below in the column.
  double _metaUsedHeight({
    required bool showSubtitle,
    required bool showGenres,
    required bool showOverview,
    required bool showMetaLine,
    required double titleHeight,
  }) {
    var used = titleHeight;
    if (showSubtitle) used += 6 + _subtitleBlockHeight;
    if (showGenres) used += 10 + _genreBlockHeight;
    if (showMetaLine) used += 14 + _metaBlockHeight;
    if (showOverview) used += _overviewGap + _overviewSlotHeight;
    return used;
  }

  @override
  Widget build(BuildContext context) {
    final bounded = maxHeight != null && maxHeight!.isFinite && maxHeight! > 0;

    var showSubtitle = _hasSubtitle;
    var showGenres = genres.isNotEmpty;
    var showOverview = overview.isNotEmpty;
    var showMetaLine = metaParts.isNotEmpty || (rating != null && rating! > 0);
    var showProgress = progressBar != null;
    var showSeriesProgress = seriesProgress != null;
    var titleHeight = _defaultTitleHeight;

    // Keep title + Play first. Text titles shrink before dropping overview.
    double? metaBudget;
    if (bounded) {
      metaBudget = (maxHeight! -
              _footerReserve(
                showProgress: showProgress,
                showSeriesProgress: showSeriesProgress,
              ))
          .clamp(0.0, maxHeight!);

      bool overBudget() =>
          _metaUsedHeight(
            showSubtitle: showSubtitle,
            showGenres: showGenres,
            showOverview: showOverview,
            showMetaLine: showMetaLine,
            titleHeight: titleHeight,
          ) >
          metaBudget!;

      void refreshBudget() {
        metaBudget = (maxHeight! -
                _footerReserve(
                  showProgress: showProgress,
                  showSeriesProgress: showSeriesProgress,
                ))
            .clamp(0.0, maxHeight!);
      }

      if (overBudget()) showSubtitle = false;
      if (overBudget()) showOverview = false;
      if (overBudget()) showGenres = false;
      // Meta (type / year / cert / ★) stays above synopsis on tight ATV chrome.
      if (overBudget()) showMetaLine = false;
      if (!_hasLogo && overBudget()) {
        titleHeight = 64.0;
      }
      if (overBudget() && showSeriesProgress) {
        showSeriesProgress = false;
        refreshBudget();
      }
      if (overBudget() && showProgress) {
        showProgress = false;
        refreshBudget();
      }
      if (overBudget()) {
        final rest = _metaUsedHeight(
          showSubtitle: showSubtitle,
          showGenres: showGenres,
          showOverview: showOverview,
          showMetaLine: showMetaLine,
          titleHeight: 0,
        );
        titleHeight = (metaBudget! - rest).clamp(0.0, _defaultTitleHeight);
        if (titleHeight < _titleMinHeight) {
          titleHeight = metaBudget!.clamp(0.0, _defaultTitleHeight);
          if (titleHeight < _titleMinHeight) titleHeight = 0;
        }
      }
    }

    final metaColumn = <Widget>[
      if (titleHeight > 0)
        if (bounded)
          SizedBox(
            height: titleHeight,
            child: Align(
              alignment: Alignment.bottomLeft,
                  child: _titleWidget(titleHeight),
            ),
          )
        else
          _titleWidget(_defaultTitleHeight),
      if (showSubtitle) ...[
        const SizedBox(height: 6),
        Text(
          subtitle!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.62),
          ),
        ),
      ],
      if (showGenres) ...[
        const SizedBox(height: 10),
        Text(
          genres.take(4).join(' • '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.78),
            letterSpacing: 0.2,
          ),
        ),
      ],
      if (showMetaLine) ...[
        const SizedBox(height: 14),
        DetailsHeroMetaLine(
          parts: metaParts,
          rating: rating,
          singleLine: bounded,
        ),
      ],
      if (showOverview) ...[
        const SizedBox(height: _overviewGap),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: _overviewSlotHeight),
          child: Align(
            alignment: Alignment.topLeft,
            child: HeroOverviewText(
              overview: overview,
              maxLines: ShellTokens.heroOverviewMaxLinesDesktop,
              shrinkWrap: true,
              style: _overviewStyle,
            ),
          ),
        ),
      ],
    ];

    // Pack meta → actions → progress at the top (Play sits under synopsis).
    final footer = <Widget>[
      if (actionRow != null) ...[
        const SizedBox(height: _actionGap),
        DetailsHeroActionRowFit(
          scaleDown: scaleActionRow,
          child: actionRow!,
        ),
      ],
      if (showProgress) ...[
        const SizedBox(height: 14),
        SizedBox(
          width: 220,
          child: progressBar!,
        ),
      ],
      if (showSeriesProgress) ...[
        SizedBox(height: showProgress ? 8 : 14),
        seriesProgress!,
      ],
    ];

    if (!bounded) {
      return SizedBox(
        width: maxContentWidth,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [...metaColumn, ...footer],
          ),
        ),
      );
    }

    if (belowActionRow != null) {
      return SizedBox(
        width: maxContentWidth,
        height: maxHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              fit: FlexFit.loose,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: metaColumn,
              ),
            ),
            if (actionRow != null) ...[
              const SizedBox(height: _actionGap),
              DetailsHeroActionRowFit(
          scaleDown: scaleActionRow,
          child: actionRow!,
        ),
            ],
            SizedBox(height: belowActionRowGap),
            Expanded(child: belowActionRow!),
          ],
        ),
      );
    }

    // Pack meta + CTAs together at the top (same as MediaDetailsHero).
    // Do not put meta in a Flexible above the footer — that expands into the
    // tall hero band and leaves a dead gap under Read More.
    return SizedBox(
      width: maxContentWidth,
      height: maxHeight,
      child: Align(
        alignment: Alignment.topLeft,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [...metaColumn, ...footer],
          ),
        ),
      ),
    );
  }
}

class DetailsHeroMetaLine extends StatelessWidget {
  const DetailsHeroMetaLine({
    super.key,
    required this.parts,
    this.rating,
    this.singleLine = false,
  });

  final List<String> parts;
  final double? rating;
  final bool singleLine;

  @override
  Widget build(BuildContext context) {
    final textParts = parts.where((p) => p.trim().isNotEmpty).toList();
    final ratingWidget = rating != null && rating! > 0
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star_rounded, size: 16, color: Colors.amber.shade400),
              const SizedBox(width: 4),
              Text(
                rating!.toStringAsFixed(1),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          )
        : null;

    if (textParts.isEmpty && ratingWidget == null) {
      return const SizedBox.shrink();
    }

    if (singleLine) {
      final line = textParts.join(' • ');
      return Row(
        children: [
          if (line.isNotEmpty)
            Flexible(
              child: Text(
                line,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          if (ratingWidget != null) ...[
            if (line.isNotEmpty) const SizedBox(width: 12),
            ratingWidget,
          ],
        ],
      );
    }

    final items = <Widget>[];
    for (final part in textParts) {
      items.add(_metaText(part));
    }
    if (ratingWidget != null) items.add(ratingWidget);
    if (items.isEmpty) return const SizedBox.shrink();

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0)
            Text(
              '•',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 12),
            ),
          items[i],
        ],
      ],
    );
  }

  Widget _metaText(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.72),
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _HeroBottomFade extends StatelessWidget {
  const _HeroBottomFade({required this.shellBg, this.soft = false});

  final Color shellBg;
  final bool soft;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: soft
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
          stops: soft
              ? const [0.0, 0.42, 0.68, 0.9, 1.0]
              : const [0.0, 0.35, 0.68, 0.92, 1.0],
        ),
      ),
    );
  }
}

class _CinematicHeroBottomGradient extends StatelessWidget {
  const _CinematicHeroBottomGradient({
    required this.shellBg,
    this.overlap = 0,
    this.softFade = false,
  });

  final Color shellBg;
  final double overlap;
  final bool softFade;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fraction = softFade ? 0.42 : 0.55;
        return IgnorePointer(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: constraints.maxHeight * fraction + overlap,
              width: double.infinity,
              child: _HeroBottomFade(shellBg: shellBg, soft: softFade),
            ),
          ),
        );
      },
    );
  }
}

class _CinematicHeroSideGradient extends StatelessWidget {
  const _CinematicHeroSideGradient({required this.shellBg});

  final Color shellBg;

  @override
  Widget build(BuildContext context) {
    final fadeEnd = ShellTokens.heroImageGradientFadeEndFraction;
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              shellBg,
              shellBg.withValues(alpha: 0.72),
              shellBg.withValues(alpha: 0.28),
              Colors.transparent,
            ],
            stops: [0.0, fadeEnd * 0.31, fadeEnd * 0.66, fadeEnd],
          ),
        ),
      ),
    );
  }
}
