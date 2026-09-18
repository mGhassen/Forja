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
///
/// Nullable chrome overrides: omit → [ShellTokens] (pack visual props).
HeroDesktopTextLayout heroDesktopTextLayout({
  required double maxHeight,
  required bool hasOverview,
  required double minTitleHeight,
  double reservedBelowOverview = 0,
  double? titleSlotHeight,
  double? metaSlotHeight,
  double? titleMetaGap,
  double? metaActionsGap,
  double? metaOverviewGap,
  int? overviewMaxLines,
  double? overviewFontSize,
  double? overviewLineHeight,
}) {
  final titleGap = titleMetaGap ?? ShellTokens.heroTitleMetaGapDesktop;
  final actionGap = metaActionsGap ?? ShellTokens.heroMetaActionsGapDesktop;
  final metaH = metaSlotHeight ?? ShellTokens.heroMetaSlotHeightDesktop;
  final titleSlotMax = titleSlotHeight ?? ShellTokens.heroTitleSlotHeightDesktop;
  final metaGap = metaOverviewGap ?? ShellTokens.heroMetaOverviewGapDesktop;
  final maxLines = overviewMaxLines ?? ShellTokens.heroOverviewMaxLinesDesktop;
  final fontSize = overviewFontSize ?? ShellTokens.heroOverviewFontSizeDesktop;
  final lineHeight =
      overviewLineHeight ?? ShellTokens.heroOverviewLineHeightDesktop;

  final baseWithoutOverview =
      titleGap +
      metaH +
      actionGap +
      ShellTokens.shellButtonHeight +
      reservedBelowOverview;

  double textH(int lines) => fontSize * lineHeight * lines;

  double slotFor(int lines, {required bool includeReadMore}) {
    final text = textH(lines);
    if (!includeReadMore) return text;
    return text + ShellTokens.heroOverviewReadMoreGap + fontSize * lineHeight;
  }

  bool fits(double titleH, double overviewBlock) =>
      titleH + baseWithoutOverview + overviewBlock <= maxHeight;

  var titleHeight = titleSlotMax;

  if (!hasOverview) {
    if (!fits(titleHeight, 0)) {
      titleHeight = (maxHeight - baseWithoutOverview).clamp(
        minTitleHeight,
        titleSlotMax,
      );
    }
    return HeroDesktopTextLayout(
      titleHeight: titleHeight,
      showOverview: false,
      overviewMaxLines: 0,
      overviewSlotHeight: 0,
    );
  }

  var lines = maxLines;
  var includeReadMore = true;
  var slot = slotFor(lines, includeReadMore: includeReadMore);
  var overviewBlock = metaGap + slot;

  if (!fits(titleHeight, overviewBlock)) {
    titleHeight = (maxHeight - baseWithoutOverview - overviewBlock).clamp(
      minTitleHeight,
      titleSlotMax,
    );
  }

  while (!fits(titleHeight, overviewBlock) && lines > 1) {
    lines--;
    slot = slotFor(lines, includeReadMore: includeReadMore);
    overviewBlock = metaGap + slot;
    titleHeight = (maxHeight - baseWithoutOverview - overviewBlock).clamp(
      minTitleHeight,
      titleSlotMax,
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
    titleHeight = titleSlotMax;
    if (!fits(titleHeight, 0)) {
      titleHeight = (maxHeight - baseWithoutOverview).clamp(
        minTitleHeight,
        titleSlotMax,
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
