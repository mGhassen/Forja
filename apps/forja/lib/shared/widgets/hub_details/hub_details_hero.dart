import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/widgets/hero_overview_text.dart';
import 'package:forja/shared/widgets/hub_details/hub_details_facts_panel.dart';
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

  @override
  Widget build(BuildContext context) {
    final h = height ?? ShellTokens.detailsHeroHeight(context, showEpisodeRail: true);
    final shellBg = AppTheme.bgDark;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final topInset = MediaQuery.paddingOf(context).top;
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final cinematicDesktop = viewportWidth >= 900;
    final contentInset = ShellTokens.detailsContentHorizontalPadding(viewportWidth);
    final heroContentTop = topInset + ShellTokens.detailsHeroContentTopInset;

    return SizedBox(
      height: h,
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
                    overlap: ShellTokens.detailsHeroBodyOverlap,
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
                height: h * 0.55 + ShellTokens.detailsHeroBodyOverlap,
                child: IgnorePointer(child: _HeroBottomFade(shellBg: shellBg)),
              ),
            Positioned(
              left: 0,
              right: 0,
              top: heroContentTop,
              bottom: 72 + bottomInset,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: ShellTokens.bodyMaxWidthDesktop),
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
                    ),
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

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 900;
    final leftColumnWidth = width * ShellTokens.detailsHeroDescriptionWidthFraction;
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
      maxContentWidth: compact ? width : leftColumnWidth,
    );

    if (compact) return mainColumn;

    final factsPanel = HubDetailsFactsPanel(entries: facts);
    return Stack(
      fit: StackFit.expand,
      children: [
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: leftColumnWidth, child: mainColumn),
        ),
        if (factsPanel.hasContent)
          Align(
            alignment: Alignment.bottomRight,
            child: SizedBox(width: 300, child: factsPanel),
          ),
      ],
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
    required this.maxContentWidth,
  });

  final String title;
  final String? subtitle;
  final List<String> genres;
  final List<String> metaParts;
  final double? rating;
  final String overview;
  final Widget? actionRow;
  final int? positionMs;
  final int? durationMs;
  final double maxContentWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: maxContentWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          HubHeroTitle(title: title),
          if (subtitle != null && subtitle!.isNotEmpty && subtitle != title) ...[
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
          if (genres.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              genres.take(4).join(' • '),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.78),
                letterSpacing: 0.2,
              ),
            ),
          ],
          const SizedBox(height: 14),
          HubHeroMetaLine(parts: metaParts, rating: rating),
          if (overview.isNotEmpty) ...[
            const SizedBox(height: 14),
            HeroOverviewText(
              overview: overview,
              maxLines: 3,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: Colors.white.withValues(alpha: 0.72),
              ),
            ),
          ],
          if (actionRow != null) ...[
            const SizedBox(height: 18),
            actionRow!,
          ],
          if (positionMs != null && durationMs != null && durationMs! > 0) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: 220,
              child: WatchProgressBar(
                positionMs: positionMs!,
                durationMs: durationMs!,
              ),
            ),
          ],
        ],
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
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Transform.translate(
          offset: const Offset(-1.5, 0),
          child: Text(
            title,
            style: style.copyWith(color: const Color(0xFF38BDF8).withValues(alpha: 0.45)),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Transform.translate(
          offset: const Offset(1.5, 0),
          child: Text(
            title,
            style: style.copyWith(color: const Color(0xFFFBBF24).withValues(alpha: 0.4)),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          title,
          style: style,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class HubHeroMetaLine extends StatelessWidget {
  const HubHeroMetaLine({super.key, required this.parts, this.rating});

  final List<String> parts;
  final double? rating;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (final part in parts) {
      if (part.trim().isEmpty) continue;
      items.add(_metaText(part));
    }
    if (rating != null && rating! > 0) {
      items.add(Row(
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
      ));
    }
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
  const _HeroBottomFade({required this.shellBg});

  final Color shellBg;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
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
    );
  }
}

class _CinematicHeroBottomGradient extends StatelessWidget {
  const _CinematicHeroBottomGradient({required this.shellBg, this.overlap = 0});

  final Color shellBg;
  final double overlap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return IgnorePointer(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: constraints.maxHeight * 0.55 + overlap,
              width: double.infinity,
              child: _HeroBottomFade(shellBg: shellBg),
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
