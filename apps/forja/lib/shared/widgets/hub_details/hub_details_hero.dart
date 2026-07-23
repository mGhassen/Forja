import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/widgets/hero/desktop_selectable_title.dart';
import 'package:forja/shared/widgets/hero_overview_text.dart';
import 'package:forja/shared/widgets/hub_details/hub_details_facts_panel.dart';
import 'package:forja/shared/widgets/hub_details/hub_details_play_row.dart';
import 'package:forja/shared/widgets/movie_atmosphere.dart';
import 'package:forja/shared/widgets/watch_progress_bar.dart';

/// Cinematic details hero for non-TMDB hubs — matches [MediaDetailsHero] layout.
class HubDetailsHero extends StatelessWidget {
  const HubDetailsHero({
    super.key,
    required this.backdropUrl,
    required this.title,
    this.subtitle,
    this.genres = const [],
    this.metaParts = const [],
    this.rating,
    this.overview = '',
    this.facts = const [],
    this.actionRow,
    this.height,
    this.positionMs,
    this.durationMs,
    this.bodyOverlap,
    this.pageBottomChild,
    this.seriesProgress,
  });

  final String backdropUrl;
  final String title;
  final String? subtitle;
  final List<String> genres;
  final List<String> metaParts;
  final double? rating;
  final String overview;
  final List<MapEntry<String, String>> facts;
  final Widget? actionRow;
  final double? height;
  final int? positionMs;
  final int? durationMs;
  final double? bodyOverlap;
  final Widget? pageBottomChild;
  final Widget? seriesProgress;

  @override
  Widget build(BuildContext context) {
    final showEpisodeRail = pageBottomChild != null;
    final h = height ??
        DetailsTokens.heroHeight(
          context,
          showEpisodeRail: showEpisodeRail,
        );
    final bleed =
        showEpisodeRail ? DetailsTokens.episodeBackdropBleed : 0.0;
    final totalH = h + bleed;
    final shellBg = AppTheme.bgDark;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final topInset = MediaQuery.paddingOf(context).top;
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final cinematicDesktop = viewportWidth >= 900;
    final contentInset = DetailsTokens.contentHorizontalPadding(viewportWidth);
    final heroContentTop = topInset + DetailsTokens.heroContentTopInset;
    final bodyOverlap =
        this.bodyOverlap ?? DetailsTokens.heroBodyOverlap;
    final pageBleed = bleed > 0;

    return SizedBox(
      height: totalH,
      width: double.infinity,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: shellBg),
            Positioned.fill(
              child: backdropUrl.isEmpty
                  ? ColoredBox(color: shellBg)
                  : KenBurnsBackdrop(imageUrl: backdropUrl, showColorTint: false),
            ),
            if (cinematicDesktop)
              Positioned.fill(
                child: IgnorePointer(
                  child: _CinematicHeroBottomGradient(
                    shellBg: shellBg,
                    overlap: pageBleed ? 0 : bodyOverlap,
                    softFade: pageBleed,
                  ),
                ),
              ),
            if (cinematicDesktop)
              Positioned.fill(
                child: IgnorePointer(child: _CinematicHeroSideGradient(shellBg: shellBg)),
              ),
            if (!cinematicDesktop)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: pageBleed ? totalH * 0.42 : h * 0.55 + bodyOverlap,
                child: IgnorePointer(
                  child: _HeroBottomFade(shellBg: shellBg, soft: pageBleed),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              top: heroContentTop,
              bottom: bleed + 72 + bottomInset,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: ShellTokens.bodyMaxWidthDesktop,
                        maxHeight: constraints.maxHeight,
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: contentInset),
                        child: _HubHeroLayout(
                          title: title,
                          subtitle: subtitle,
                          genres: genres,
                          metaParts: metaParts,
                          rating: rating,
                          overview: overview,
                          facts: facts,
                          actionRow: actionRow,
                          positionMs: positionMs,
                          durationMs: durationMs,
                          seriesProgress: seriesProgress,
                          availableWidth: constraints.maxWidth,
                          maxHeight: constraints.maxHeight,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (pageBottomChild != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Align(
                  alignment: Alignment.bottomCenter,
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

class _HubHeroLayout extends StatelessWidget {
  const _HubHeroLayout({
    required this.title,
    this.subtitle,
    required this.genres,
    required this.metaParts,
    this.rating,
    required this.overview,
    required this.facts,
    this.actionRow,
    this.positionMs,
    this.durationMs,
    this.seriesProgress,
    this.availableWidth,
    this.maxHeight,
  });

  final String title;
  final String? subtitle;
  final List<String> genres;
  final List<String> metaParts;
  final double? rating;
  final String overview;
  final List<MapEntry<String, String>> facts;
  final Widget? actionRow;
  final int? positionMs;
  final int? durationMs;
  final Widget? seriesProgress;
  final double? availableWidth;
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 900;
    final leftColumnWidth = width * DetailsTokens.heroDescriptionWidthFraction;
    final mainColumn = _HubHeroMainColumn(
      title: title,
      subtitle: subtitle,
      genres: genres,
      metaParts: metaParts,
      rating: rating,
      overview: overview,
      actionRow: actionRow,
      positionMs: positionMs,
      durationMs: durationMs,
      seriesProgress: seriesProgress,
      maxContentWidth: compact ? (availableWidth ?? width) : leftColumnWidth,
      maxHeight: maxHeight,
    );

    if (compact) {
      return SizedBox(
        width: double.infinity,
        height: maxHeight,
        child: mainColumn,
      );
    }

    final factsPanel = HubDetailsFactsPanel(entries: facts);
    return SizedBox(
      width: double.infinity,
      height: maxHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: leftColumnWidth,
              height: maxHeight,
              child: mainColumn,
            ),
          ),
          if (factsPanel.hasContent && maxHeight != null)
            Align(
              alignment: Alignment.bottomRight,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 300,
                  maxHeight: maxHeight!,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    physics: const ClampingScrollPhysics(),
                    children: [factsPanel],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HubHeroMainColumn extends StatelessWidget {
  const _HubHeroMainColumn({
    required this.title,
    this.subtitle,
    required this.genres,
    required this.metaParts,
    this.rating,
    required this.overview,
    this.actionRow,
    this.positionMs,
    this.durationMs,
    this.seriesProgress,
    required this.maxContentWidth,
    this.maxHeight,
  });

  static const _overviewStyle = TextStyle(
    fontSize: 14,
    height: 1.6,
    color: Color(0xB8FFFFFF),
  );
  static const _titleBlockHeight = 96.0;
  static const _subtitleBlockHeight = 26.0;
  static const _genreBlockHeight = 30.0;
  static const _metaBlockHeight = 24.0;
  static const _metaBlockHeightWrapped = 40.0;
  static const _overviewGap = 14.0;
  static const _actionGap = 18.0;
  static const _progressBlockHeight = 36.0;
  static const _seriesProgressBlockHeight = 28.0;

  final String title;
  final String? subtitle;
  final List<String> genres;
  final List<String> metaParts;
  final double? rating;
  final String overview;
  final Widget? actionRow;
  final int? positionMs;
  final int? durationMs;
  final Widget? seriesProgress;
  final double maxContentWidth;
  final double? maxHeight;

  static double get _overviewSlotHeight =>
      _overviewStyle.fontSize! *
          _overviewStyle.height! *
          ShellTokens.heroOverviewMaxLinesDesktop +
      ShellTokens.heroOverviewReadMoreGap +
      _overviewStyle.fontSize! * _overviewStyle.height!;

  bool get _hasSubtitle =>
      subtitle != null && subtitle!.isNotEmpty && subtitle != title;

  double _usedHeight({
    required bool showSubtitle,
    required bool showGenres,
    required bool showOverview,
    required bool showProgress,
    required bool showSeriesProgress,
    required bool singleLineMeta,
    required double titleHeight,
  }) {
    final metaHeight =
        singleLineMeta ? _metaBlockHeight : _metaBlockHeightWrapped;
    var used = titleHeight + 14 + metaHeight;
    if (showSubtitle) used += 6 + _subtitleBlockHeight;
    if (showGenres) used += 10 + _genreBlockHeight;
    if (showOverview) used += _overviewGap + _overviewSlotHeight;
    if (actionRow != null) used += _actionGap + ShellTokens.shellButtonHeight;
    if (showProgress) used += 14 + _progressBlockHeight;
    if (showSeriesProgress) {
      used += (showProgress ? 8 : 14) + _seriesProgressBlockHeight;
    }
    return used;
  }

  @override
  Widget build(BuildContext context) {
    final bounded = maxHeight != null && maxHeight!.isFinite && maxHeight! > 0;

    var showSubtitle = _hasSubtitle;
    var showGenres = genres.isNotEmpty;
    var showOverview = overview.isNotEmpty;
    var showProgress =
        positionMs != null && durationMs != null && durationMs! > 0;
    var showSeriesProgress = seriesProgress != null;
    var titleHeight = _titleBlockHeight;

    if (bounded) {
      bool overBudget() =>
          _usedHeight(
            showSubtitle: showSubtitle,
            showGenres: showGenres,
            showOverview: showOverview,
            showProgress: showProgress,
            showSeriesProgress: showSeriesProgress,
            singleLineMeta: true,
            titleHeight: titleHeight,
          ) >
          maxHeight!;

      // Keep fixed 3-line synopsis + Read More; drop secondary chrome first.
      if (overBudget()) showGenres = false;
      if (overBudget()) showSubtitle = false;
      if (overBudget()) showSeriesProgress = false;
      if (overBudget()) showProgress = false;
      if (overBudget()) {
        titleHeight = (maxHeight! -
                _usedHeight(
                  showSubtitle: showSubtitle,
                  showGenres: showGenres,
                  showOverview: showOverview,
                  showProgress: showProgress,
                  showSeriesProgress: showSeriesProgress,
                  singleLineMeta: true,
                  titleHeight: 0,
                ))
            .clamp(48.0, _titleBlockHeight);
      }
    }

    final metaColumn = <Widget>[
      SizedBox(
        height: titleHeight,
        child: Align(
          alignment: Alignment.bottomLeft,
          child: HubHeroTitle(title: title),
        ),
      ),
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
      const SizedBox(height: 14),
      HubHeroMetaLine(
        parts: metaParts,
        rating: rating,
        singleLine: bounded,
      ),
      if (showOverview) ...[
        const SizedBox(height: _overviewGap),
        SizedBox(
          height: _overviewSlotHeight,
          child: Align(
            alignment: Alignment.topLeft,
            child: HeroOverviewText(
              overview: overview,
              maxLines: ShellTokens.heroOverviewMaxLinesDesktop,
              shrinkWrap: false,
              style: _overviewStyle,
            ),
          ),
        ),
      ],
    ];

    return SizedBox(
      width: maxContentWidth,
      height: bounded ? maxHeight : null,
      child: Align(
        alignment: Alignment.topLeft,
        child: ClipRect(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ...metaColumn,
              if (actionRow != null) ...[
                const SizedBox(height: _actionGap),
                DetailsHeroActionRowFit(child: actionRow!),
              ],
              if (showProgress) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: 220,
                  child: WatchProgressBar(
                    positionMs: positionMs!,
                    durationMs: durationMs!,
                  ),
                ),
              ],
              if (showSeriesProgress) ...[
                SizedBox(height: showProgress ? 8 : 14),
                seriesProgress!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class HubHeroTitle extends StatelessWidget {
  const HubHeroTitle({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 48,
      fontWeight: FontWeight.w900,
      color: Colors.white,
      height: 1.0,
      letterSpacing: -1.2,
    );
    return wrapDesktopSelectableTitle(
      context,
      Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          desktopTitleSelectionGhost(
            Transform.translate(
              offset: const Offset(-1.5, 0),
              child: Text(
                title,
                style: style.copyWith(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.45),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          desktopTitleSelectionGhost(
            Transform.translate(
              offset: const Offset(1.5, 0),
              child: Text(
                title,
                style: style.copyWith(
                  color: const Color(0xFFFBBF24).withValues(alpha: 0.4),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Text(
            title,
            style: style,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class HubHeroMetaLine extends StatelessWidget {
  const HubHeroMetaLine({
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
