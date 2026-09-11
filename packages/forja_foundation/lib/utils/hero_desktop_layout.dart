import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

/// Desktop cinematic hero text column - prefer synopsis over a full logo slot.
class HeroDesktopTextLayout {
  const HeroDesktopTextLayout({
    required this.titleHeight,
    required this.showOverview,
    required this.overviewMaxLines,
    required this.overviewSlotHeight,
  });

  final double titleHeight;
  final bool showOverview;
  final int overviewMaxLines;
  final double overviewSlotHeight;
}

/// Fits title + optional overview into [maxHeight] for Home / hub heroes.
///
/// When space is tight (Featured / Latest stacked on the backdrop), shrinks the
/// title slot and overview lines before dropping the synopsis entirely.
/// Pass [reservedBelowOverview] for extra chrome under the overview (e.g. upcoming
/// notice) so that height is part of the fit budget.
HeroDesktopTextLayout heroDesktopTextLayout({
  required double maxHeight,
  required bool hasOverview,
  required double minTitleHeight,
  double reservedBelowOverview = 0,
}) {
  const titleGap = 20.0;
  const actionGap = 16.0;
  final baseWithoutOverview =
      titleGap +
      ShellTokens.heroMetaSlotHeightDesktop +
      actionGap +
      ShellTokens.shellButtonHeight +
      reservedBelowOverview;
  final metaGap = ShellTokens.heroMetaOverviewGapDesktop;

  double slotFor(int lines, {required bool includeReadMore}) {
    final text = ShellTokens.heroOverviewTextHeightDesktop(lines);
    if (!includeReadMore) return text;
    return ShellTokens.heroOverviewSlotHeightForLines(lines);
  }

  bool fits(double titleH, double overviewBlock) =>
      titleH + baseWithoutOverview + overviewBlock <= maxHeight;

  var titleHeight = ShellTokens.heroTitleSlotHeightDesktop;

  if (!hasOverview) {
    if (!fits(titleHeight, 0)) {
      titleHeight = (maxHeight - baseWithoutOverview).clamp(
        minTitleHeight,
        ShellTokens.heroTitleSlotHeightDesktop,
      );
    }
    return HeroDesktopTextLayout(
      titleHeight: titleHeight,
      showOverview: false,
      overviewMaxLines: 0,
      overviewSlotHeight: 0,
    );
  }

  var lines = ShellTokens.heroOverviewMaxLinesDesktop;
  var includeReadMore = true;
  var slot = slotFor(lines, includeReadMore: includeReadMore);
  var overviewBlock = metaGap + slot;

  if (!fits(titleHeight, overviewBlock)) {
    titleHeight = (maxHeight - baseWithoutOverview - overviewBlock).clamp(
      minTitleHeight,
      ShellTokens.heroTitleSlotHeightDesktop,
    );
  }

  while (!fits(titleHeight, overviewBlock) && lines > 1) {
    lines--;
    slot = slotFor(lines, includeReadMore: includeReadMore);
    overviewBlock = metaGap + slot;
    titleHeight = (maxHeight - baseWithoutOverview - overviewBlock).clamp(
      minTitleHeight,
      ShellTokens.heroTitleSlotHeightDesktop,
    );
  }

  // Keep read-more reserve whenever overview shows — HeroOverviewText always
  // paints Read More for truncated copy in fixed slots.
  if (!fits(titleHeight, overviewBlock)) {
    titleHeight = minTitleHeight;
    if (fits(titleHeight, overviewBlock)) {
      return HeroDesktopTextLayout(
        titleHeight: titleHeight,
        showOverview: true,
        overviewMaxLines: lines,
        overviewSlotHeight: slot,
      );
    }
    titleHeight = ShellTokens.heroTitleSlotHeightDesktop;
    if (!fits(titleHeight, 0)) {
      titleHeight = (maxHeight - baseWithoutOverview).clamp(
        minTitleHeight,
        ShellTokens.heroTitleSlotHeightDesktop,
      );
    }
    return HeroDesktopTextLayout(
      titleHeight: titleHeight,
      showOverview: false,
      overviewMaxLines: 0,
      overviewSlotHeight: 0,
    );
  }

  return HeroDesktopTextLayout(
    titleHeight: titleHeight,
    showOverview: true,
    overviewMaxLines: lines,
    overviewSlotHeight: slot,
  );
}

