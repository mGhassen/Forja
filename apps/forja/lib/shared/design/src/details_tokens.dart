import 'package:flutter/material.dart';
import 'package:forja/shared/design/src/shell_tokens.dart';

/// Layout constants for media-details surfaces (hero, body, sources panel).
///
/// Content gutters reuse [ShellTokens] so details stay aligned with shell
/// catalog rows and body max-width.
abstract final class DetailsTokens {
  /// Extra pull-up for movie details body (cast/trailers) - not used for TV episodes.
  static const double heroBodyOverlap = 120;

  /// Backdrop band reserved for seasons + episodes under the hero chrome.
  /// Tall enough for season posters + episode cards so the rail does not
  /// overflow upward and cover the hero image.
  static const double episodeBackdropBleed = 500;

  /// Episodes-only rail (no season posters) - title + episode cards + padding.
  /// Keeps ~180px less empty gap under Play when there is a single season.
  static const double episodeBackdropBleedEpisodesOnly = 320;

  /// Bleed under hero chrome for the episode picker.
  static double episodeRailBleed({required bool showSeasonRail}) =>
      showSeasonRail ? episodeBackdropBleed : episodeBackdropBleedEpisodesOnly;

  /// Extra chrome above the rail so series/anime keep synopsis + Play.
  /// Makes the hero stack slightly taller than the viewport (rows sit lower).
  static const double episodeHeroChromeExtra = 100;
  static const double episodeSectionTopPadding = 8;
  static const double episodeSectionBottomPadding = 12;
  static const double heroContentTopInset = 88;

  static const double heroDescriptionWidthFraction = 0.40;
  static const double bodyTopSpacing = 36;

  /// Shared gap between details body sections (and episode rail → first section).
  static const double sectionSpacing = 48;
  static const double bodyTopSpacingWithEpisodes = sectionSpacing;

  /// Title → row gap inside cast / trailers / recommendations on details.
  static const double sectionTitleGap = 16;
  static const double bodyBottomSpacing = 80;

  /// Sources sliding panel on media details (player overlays use
  /// [ShellTokens.playerSidePanelPadding]).
  static const EdgeInsets sourcesPanelPadding =
      EdgeInsets.fromLTRB(16, 0, 12, 12);

  static const double contentPaddingDesktop =
      ShellTokens.homeSectionHorizontalPadding;
  static const double contentPaddingCompact =
      ShellTokens.homeSectionHorizontalPadding;

  static double contentHorizontalPadding(double viewportWidth) {
    if (viewportWidth >= ShellTokens.shellNavCompactMaxWidth) {
      return contentPaddingDesktop;
    }
    return contentPaddingCompact;
  }

  static double contentLeftInset(double viewportWidth) {
    final padding = contentHorizontalPadding(viewportWidth);
    final columnWidth = viewportWidth < ShellTokens.bodyMaxWidthDesktop
        ? viewportWidth
        : ShellTokens.bodyMaxWidthDesktop;
    final sideGutter = (viewportWidth - columnWidth) / 2;
    return sideGutter + padding;
  }

  /// Back chevron on details overlays - matches hero title / body content inset.
  static double backButtonLeftInset(BuildContext context) {
    return contentLeftInset(MediaQuery.sizeOf(context).width);
  }

  /// Cinematic hero band (~82% viewport) - see media-details feature doc.
  static const double heroViewportFraction = 0.82;

  /// Floor for title/actions when the episode rail claims [episodeBackdropBleed].
  static const double heroWithEpisodesMinFraction = 0.42;

  /// Compact phones / short landscape (incl. 720p Android TV) need a taller
  /// chrome floor - 0.42 leaves ~60–100px for the title/Play column after top
  /// inset + rail gap, which zeros the title and drops synopsis.
  static const double heroWithEpisodesMinFractionCompact = 0.58;

  /// Viewports shorter than this use the compact chrome floor even when wide
  /// (720p ATV is landscape but still tight for title + synopsis + Play).
  static const double heroWithEpisodesShortViewportHeight = 900;

  /// Gap between hero meta/actions and the episode rail (inside the bleed).
  static double heroContentToRailGap(double heroChromeHeight) =>
      heroChromeHeight < 480 ? 24.0 : 72.0;

  /// Full on-screen backdrop band - title/actions + optional TV bleed.
  static double heroBackdropBand(
    BuildContext context, {
    double? viewportHeight,
    bool showEpisodeRail = false,
    bool showSeasonRail = false,
  }) {
    final size = MediaQuery.sizeOf(context);
    final height = viewportHeight ?? size.height;
    final resolved = height.isFinite && height > 0 ? height : size.height;
    if (!showEpisodeRail) {
      return resolved * heroViewportFraction;
    }
    final compact = size.width < ShellTokens.shellNavCompactMaxWidth;
    final shortViewport = resolved < heroWithEpisodesShortViewportHeight;
    final minFraction = (compact || shortViewport)
        ? heroWithEpisodesMinFractionCompact
        : heroWithEpisodesMinFraction;
    final bleed = episodeRailBleed(showSeasonRail: showSeasonRail);
    // Chrome uses the viewport above the rail band so seasons/episodes sit
    // near the bottom of the first screen instead of mid-hero. A small chrome
    // boost keeps synopsis visible; the stack grows ~[episodeHeroChromeExtra].
    return (resolved - bleed + episodeHeroChromeExtra).clamp(
      resolved * minFraction,
      resolved * heroViewportFraction,
    );
  }

  /// Hero chrome height for media details - prefer [viewportHeight] from a [LayoutBuilder].
  /// TV episode rails add [episodeRailBleed] below this in the hero stack.
  static double heroHeight(
    BuildContext context, {
    double? viewportHeight,
    bool showEpisodeRail = false,
    bool showSeasonRail = false,
  }) {
    return heroBackdropBand(
      context,
      viewportHeight: viewportHeight,
      showEpisodeRail: showEpisodeRail,
      showSeasonRail: showSeasonRail,
    );
  }
}
