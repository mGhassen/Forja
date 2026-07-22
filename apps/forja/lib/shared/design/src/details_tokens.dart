import 'package:flutter/material.dart';
import 'package:forja/shared/design/src/shell_tokens.dart';

/// Layout constants for media-details surfaces (hero, body, sources panel).
///
/// Content gutters reuse [ShellTokens] so details stay aligned with shell
/// catalog rows and body max-width.
abstract final class DetailsTokens {
  /// Extra pull-up for movie details body (cast/trailers) — not used for TV episodes.
  static const double heroBodyOverlap = 120;

  /// Backdrop band reserved for seasons + episodes under the hero chrome.
  /// Tall enough for season posters + episode cards so the rail does not
  /// overflow upward and cover the hero image.
  static const double episodeBackdropBleed = 500;
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
      EdgeInsets.fromLTRB(16, 8, 12, 12);

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

  /// Back chevron on details overlays — matches hero title / body content inset.
  static double backButtonLeftInset(BuildContext context) {
    return contentLeftInset(MediaQuery.sizeOf(context).width);
  }

  /// Cinematic hero band (~82% viewport) — see media-details feature doc.
  static const double heroViewportFraction = 0.82;

  /// Floor for title/actions when the episode rail claims [episodeBackdropBleed].
  static const double heroWithEpisodesMinFraction = 0.42;

  /// Full on-screen backdrop band — title/actions + optional TV bleed.
  static double heroBackdropBand(
    BuildContext context, {
    double? viewportHeight,
    bool showEpisodeRail = false,
  }) {
    final height = viewportHeight ?? MediaQuery.sizeOf(context).height;
    final resolved = height.isFinite && height > 0
        ? height
        : MediaQuery.sizeOf(context).height;
    if (!showEpisodeRail) {
      return resolved * heroViewportFraction;
    }
    // Chrome uses the viewport above the rail band so seasons/episodes sit
    // at the bottom of the first screen instead of mid-hero.
    return (resolved - episodeBackdropBleed).clamp(
      resolved * heroWithEpisodesMinFraction,
      resolved * heroViewportFraction,
    );
  }

  /// Hero chrome height for media details — prefer [viewportHeight] from a [LayoutBuilder].
  /// TV episode rails add [episodeBackdropBleed] below this in the hero stack.
  static double heroHeight(
    BuildContext context, {
    double? viewportHeight,
    bool showEpisodeRail = false,
  }) {
    return heroBackdropBand(
      context,
      viewportHeight: viewportHeight,
      showEpisodeRail: showEpisodeRail,
    );
  }
}
