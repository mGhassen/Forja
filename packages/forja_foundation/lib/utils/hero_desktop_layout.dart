import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

/// Desktop cinematic hero text column - prefer synopsis over a full logo slot.
class HeroDesktopTextLayout {
  const HeroDesktopTextLayout({
    required this.titleHeight,
    required this.showOverview,
    required this.showMeta,
    required this.overviewMaxLines,
    required this.overviewSlotHeight,
    required this.actionRowHeight,
  });

  final double titleHeight;
  final bool showOverview;

  /// When false, skip title↔meta gap and the meta slot (tight TV bleed).
  final bool showMeta;
  final int overviewMaxLines;
  final double overviewSlotHeight;

  /// Reserved height for the CTA row (may shrink below [ShellTokens.shellButtonHeight]).
  final double actionRowHeight;
}

/// Fits title + optional overview into [maxHeight] for Home / hub heroes.
///
/// When space is tight (Featured / Latest stacked on the backdrop), shrinks the
/// title slot and overview lines before dropping the synopsis entirely.
/// Pass [reservedBelowOverview] for extra chrome under the overview (e.g. upcoming
/// notice) so that height is part of the fit budget.
///
/// Guarantees the returned layout's painted height (title + meta + overview +
/// actions + [reservedBelowOverview]) is ≤ [maxHeight] (within 0.01px).
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
  double? actionRowHeight,
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
  final actionH = actionRowHeight ?? ShellTokens.shellButtonHeight;
  final budget = maxHeight < 0 ? 0.0 : maxHeight;

  double textH(int lines) => fontSize * lineHeight * lines;

  double slotFor(int lines, {required bool includeReadMore}) {
    final text = textH(lines);
    if (!includeReadMore) return text;
    return text + ShellTokens.heroOverviewReadMoreGap + fontSize * lineHeight;
  }

  double chrome({
    required bool withMeta,
    required double actionsH,
  }) {
    final metaBlock = withMeta ? titleGap + metaH : 0.0;
    final actionBlock = actionsH > 0 ? actionGap + actionsH : 0.0;
    return metaBlock + actionBlock + reservedBelowOverview;
  }

  bool fits({
    required double titleH,
    required double overviewBlock,
    required bool withMeta,
    required double actionsH,
  }) =>
      titleH + chrome(withMeta: withMeta, actionsH: actionsH) + overviewBlock <=
      budget + 0.01;

  HeroDesktopTextLayout pack({
    required double titleH,
    required bool overview,
    required bool withMeta,
    required int lines,
    required double slot,
    required double actionsH,
  }) {
    return HeroDesktopTextLayout(
      titleHeight: titleH.clamp(0.0, titleSlotMax),
      showOverview: overview,
      showMeta: withMeta,
      overviewMaxLines: overview ? lines : 0,
      overviewSlotHeight: overview ? slot : 0,
      actionRowHeight: actionsH.clamp(0.0, actionH),
    );
  }

  // --- Preferred: full title + overview ---
  var titleHeight = titleSlotMax;
  var lines = maxLines;
  var includeReadMore = true;
  var slot = hasOverview ? slotFor(lines, includeReadMore: includeReadMore) : 0.0;
  var overviewBlock = hasOverview ? metaGap + slot : 0.0;
  var withMeta = true;
  var actionsH = actionH;

  if (hasOverview) {
    if (!fits(
      titleH: titleHeight,
      overviewBlock: overviewBlock,
      withMeta: withMeta,
      actionsH: actionsH,
    )) {
      titleHeight = (budget - chrome(withMeta: withMeta, actionsH: actionsH) - overviewBlock)
          .clamp(minTitleHeight, titleSlotMax);
    }

    while (!fits(
          titleH: titleHeight,
          overviewBlock: overviewBlock,
          withMeta: withMeta,
          actionsH: actionsH,
        ) &&
        lines > 1) {
      lines--;
      slot = slotFor(lines, includeReadMore: includeReadMore);
      overviewBlock = metaGap + slot;
      titleHeight =
          (budget - chrome(withMeta: withMeta, actionsH: actionsH) - overviewBlock)
              .clamp(minTitleHeight, titleSlotMax);
    }

    if (fits(
      titleH: titleHeight,
      overviewBlock: overviewBlock,
      withMeta: withMeta,
      actionsH: actionsH,
    )) {
      return pack(
        titleH: titleHeight,
        overview: true,
        withMeta: withMeta,
        lines: lines,
        slot: slot,
        actionsH: actionsH,
      );
    }

    // Keep read-more reserve at min title if it still fits.
    titleHeight = minTitleHeight;
    if (fits(
      titleH: titleHeight,
      overviewBlock: overviewBlock,
      withMeta: withMeta,
      actionsH: actionsH,
    )) {
      return pack(
        titleH: titleHeight,
        overview: true,
        withMeta: withMeta,
        lines: lines,
        slot: slot,
        actionsH: actionsH,
      );
    }
  }

  // --- Drop overview; keep meta + actions ---
  overviewBlock = 0;
  titleHeight = titleSlotMax;
  if (!fits(
    titleH: titleHeight,
    overviewBlock: 0,
    withMeta: withMeta,
    actionsH: actionsH,
  )) {
    titleHeight =
        (budget - chrome(withMeta: withMeta, actionsH: actionsH)).clamp(
          0.0,
          titleSlotMax,
        );
  }
  if (fits(
    titleH: titleHeight,
    overviewBlock: 0,
    withMeta: withMeta,
    actionsH: actionsH,
  )) {
    return pack(
      titleH: titleHeight,
      overview: false,
      withMeta: withMeta,
      lines: 0,
      slot: 0,
      actionsH: actionsH,
    );
  }

  // --- Drop meta; keep actions ---
  withMeta = false;
  titleHeight =
      (budget - chrome(withMeta: false, actionsH: actionsH)).clamp(0.0, titleSlotMax);
  if (fits(
    titleH: titleHeight,
    overviewBlock: 0,
    withMeta: false,
    actionsH: actionsH,
  )) {
    return pack(
      titleH: titleHeight,
      overview: false,
      withMeta: false,
      lines: 0,
      slot: 0,
      actionsH: actionsH,
    );
  }

  // --- Shrink action row to whatever remains ---
  final remaining = budget - reservedBelowOverview;
  if (remaining <= 0) {
    return pack(
      titleH: 0,
      overview: false,
      withMeta: false,
      lines: 0,
      slot: 0,
      actionsH: 0,
    );
  }
  // Prefer a bit of title over a full CTA when both cannot fit.
  if (remaining <= actionGap) {
    return pack(
      titleH: remaining,
      overview: false,
      withMeta: false,
      lines: 0,
      slot: 0,
      actionsH: 0,
    );
  }
  final maxActions = (remaining - actionGap).clamp(0.0, actionH);
  titleHeight = (remaining - actionGap - maxActions).clamp(0.0, titleSlotMax);
  actionsH = maxActions;
  return pack(
    titleH: titleHeight,
    overview: false,
    withMeta: false,
    lines: 0,
    slot: 0,
    actionsH: actionsH,
  );
}
