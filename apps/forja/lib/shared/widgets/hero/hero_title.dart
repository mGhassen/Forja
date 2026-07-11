import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:forja/shared/design/src/shell_tokens.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:rust/rust.dart';

enum HeroTitleStyle { details, home }

/// TMDB logo or stylized title for hero surfaces (Home carousel, media details).
class HeroTitle extends StatelessWidget {
  const HeroTitle({
    super.key,
    required this.movie,
    this.logoUrl,
    this.style = HeroTitleStyle.details,
    this.isLandscape = false,
    this.desktop = false,
    this.compact = false,
    this.maxWidth,
    this.slotHeight,
  });

  final Movie movie;
  final String? logoUrl;
  final HeroTitleStyle style;
  final bool isLandscape;
  final bool desktop;
  final bool compact;
  final double? maxWidth;
  final double? slotHeight;

  @override
  Widget build(BuildContext context) {
    if (style == HeroTitleStyle.details) {
      return _DetailsHeroTitle(
        movie: movie,
        logoUrl: logoUrl,
        slotHeight: slotHeight,
      );
    }
    return _HomeHeroTitleSlot(
      movie: movie,
      logoUrl: logoUrl,
      isLandscape: isLandscape,
      desktop: desktop,
      compact: compact,
      maxWidth: maxWidth,
      slotHeight: slotHeight,
    );
  }
}

class _DetailsHeroTitle extends StatelessWidget {
  const _DetailsHeroTitle({
    required this.movie,
    this.logoUrl,
    this.slotHeight,
  });

  final Movie movie;
  final String? logoUrl;
  final double? slotHeight;

  @override
  Widget build(BuildContext context) {
    final hasLogo = logoUrl != null && logoUrl!.isNotEmpty;
    final logoHeight = slotHeight ?? 96.0;
    if (hasLogo) {
      return CachedNetworkImage(
        imageUrl: logoUrl!,
        height: logoHeight,
        fit: BoxFit.contain,
        alignment: Alignment.centerLeft,
        placeholder: (_, _) => _chromaticTitle(movie, logoHeight),
        errorWidget: (_, _, _) => _chromaticTitle(movie, logoHeight),
      );
    }
    return _chromaticTitle(movie, logoHeight);
  }

  Widget _chromaticTitle(Movie movie, double maxHeight) {
    final fontSize = maxHeight <= 56 ? 32.0 : maxHeight <= 72 ? 40.0 : 48.0;
    final maxLines = maxHeight <= 56 ? 1 : 2;
    final style = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      color: Colors.white,
      height: 1.0,
      letterSpacing: -1.2,
    );
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Transform.translate(
          offset: const Offset(-1.5, 0),
          child: Text(
            movie.title,
            style: style.copyWith(color: const Color(0xFF38BDF8).withValues(alpha: 0.45)),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Transform.translate(
          offset: const Offset(1.5, 0),
          child: Text(
            movie.title,
            style: style.copyWith(color: const Color(0xFFFBBF24).withValues(alpha: 0.4)),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          movie.title,
          style: style,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _HomeHeroTitleSlot extends StatelessWidget {
  const _HomeHeroTitleSlot({
    required this.movie,
    this.logoUrl,
    required this.isLandscape,
    this.desktop = false,
    this.compact = false,
    this.maxWidth,
    this.slotHeight,
  });

  final Movie movie;
  final String? logoUrl;
  final bool isLandscape;
  final bool desktop;
  final bool compact;
  final double? maxWidth;
  final double? slotHeight;

  @override
  Widget build(BuildContext context) {
    final bodyWidth = MediaQuery.sizeOf(context).width;
    final logoMaxHeight = compact
        ? ShellTokens.heroLogoMaxHeightCompact
        : desktop
            ? ShellTokens.heroLogoMaxHeightDesktop
            : (isLandscape ? 140.0 : 110.0);
    final resolvedMaxWidth = maxWidth ??
        (compact
            ? bodyWidth * 0.72
            : desktop
                ? ShellTokens.heroTextColumnWidthDesktop
                : (isLandscape ? 420.0 : bodyWidth * 0.75));
    final resolvedSlotHeight = slotHeight ??
        (compact
            ? ShellTokens.heroTitleSlotHeightCompact
            : desktop
                ? ShellTokens.heroTitleSlotHeightDesktop
                : logoMaxHeight + 14);
    final title = _plainTitleText(
      movie,
      isLandscape,
      desktop: desktop,
      compact: compact,
    );
    final hasLogo = logoUrl != null && logoUrl!.isNotEmpty;

    return SizedBox(
      height: compact ? null : resolvedSlotHeight,
      width: resolvedMaxWidth,
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: EdgeInsets.only(bottom: desktop || compact ? 0 : 14),
          child: SizedBox(
            height: logoMaxHeight,
            width: resolvedMaxWidth,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: hasLogo
                  ? CachedNetworkImage(
                      imageUrl: logoUrl!,
                      height: logoMaxHeight,
                      width: resolvedMaxWidth,
                      fit: BoxFit.contain,
                      alignment: Alignment.centerLeft,
                      placeholder: (_, _) => title,
                      errorWidget: (_, _, _) => title,
                      fadeInDuration: const Duration(milliseconds: 250),
                      fadeOutDuration: Duration.zero,
                    )
                  : title,
            ),
          ),
        ),
      ),
    );
  }

  Widget _plainTitleText(
    Movie movie,
    bool isLandscape, {
    bool desktop = false,
    bool compact = false,
  }) {
    final fontSize = compact
        ? 22.0
        : desktop
            ? 32.0
            : (isLandscape ? 48.0 : 36.0);
    return Text(
      movie.title,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        color: Colors.white,
        height: 1.0,
        letterSpacing: -1.0,
        shadows: [
                const Shadow(color: Colors.black, blurRadius: 40),
                Shadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 80),
              ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
