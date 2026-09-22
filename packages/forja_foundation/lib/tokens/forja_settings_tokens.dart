import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

/// Layout constants for the Settings category hub (RFC-033).
///
/// Spatial chrome (pads, icons, switches) follows [ShellTokens.tvChromeScale].
/// Type roles map onto the shell ladder — never invent a parallel Settings scale:
///
/// | Role | Desktop | TV |
/// |---|---|---|
/// | Hub / page title | [hubTitleSize] / [pageTitleSize] | [ShellTokens.tvTitleFontSize] |
/// | Category / row title | [categoryTitleSize] / [rowTitleSize] | [ShellTokens.tvBodyFontSize] |
/// | Subtitle / group label | [categorySubtitleSize] / … | [ShellTokens.tvMetaFontSize] |
abstract final class SettingsTokens {
  /// Below this width, use list → push instead of sidebar.
  static const double splitMinWidth = 900;

  static const double _s = ShellTokens.tvChromeScale;

  /// Category rail — wide enough for title + subtitle without heavy ellipsis.
  static const double sidebarWidth = 280;

  /// Leanback — hand width so labels stay readable (not × [tvChromeScale]).
  static const double sidebarWidthTv = 240;
  static const double detailMaxWidth = 720;
  /// Leanback — denser than desktop; keep form rows readable (not × chrome).
  static const double detailMaxWidthTv = 480;

  /// Flat green left-bar + ink fill (category rail and detail rows) — no card radius.
  static const double categoryTileRadius = 0;
  static const double groupRadius = 12;
  static const double rowMinHeight = 56;
  static const double rowMinHeightTv = rowMinHeight * _s;
  static const double groupSpacing = 24;
  static const double groupSpacingTv = groupSpacing * _s;
  static const double pagePadding = 20;
  static const double pagePaddingTv = pagePadding * _s;

  // --- Type roles → shell ladder on TV ---
  static const double groupLabelSize = 11;
  static const double groupLabelSizeTv = ShellTokens.tvMetaFontSize;
  static const double categoryTitleSize = 15;
  static const double categoryTitleSizeTv = ShellTokens.tvBodyFontSize;
  static const double categorySubtitleSize = 12;
  static const double categorySubtitleSizeTv = ShellTokens.tvMetaFontSize;
  static const double categoryIconSize = 22;
  static const double categoryIconSizeTv = categoryIconSize * _s;
  static const double pageTitleSize = 22;
  static const double pageTitleSizeTv = ShellTokens.tvTitleFontSize;

  /// Hub list / sidebar "Settings" title ([ShellTabHeader]).
  static const double hubTitleSize = 24;
  static const double hubTitleSizeTv = ShellTokens.tvTitleFontSize;

  /// Detail row title / subtitle (toggle, link, select rows).
  static const double rowTitleSize = 15;
  static const double rowTitleSizeTv = ShellTokens.tvBodyFontSize;
  static const double rowSubtitleSize = 12.5;
  static const double rowSubtitleSizeTv = ShellTokens.tvMetaFontSize;

  /// Toggle / action / select row content inset (title+subtitle column).
  static const double rowPadH = 2;
  static const double rowPadV = 16;
  /// Hand-tuned — denser than desktop, roomier than chrome ×scale (~10).
  static const double rowPadVTv = 10;
  static const double rowTitleSubtitleGap = 4;
  static const double rowTitleSubtitleGapTv = 1;

  /// Settings → Addons master list (Playback / Stremio / …) — roomier than
  /// dense toggle rows so title+subtitle cards do not feel glued together.
  static const double addonListRowPadV = 22;
  static const double addonListRowPadVTv = 14;
  static const double addonListSeparatorHeight = 12;
  static const double addonListSeparatorHeightTv = 8;

  /// Category tab chips under Forja Packs / Addons (Movie & TV, Anime, …).
  static const EdgeInsets categoryChipPad =
      EdgeInsets.symmetric(horizontal: 12, vertical: 6);
  static const EdgeInsets categoryChipPadTv =
      EdgeInsets.symmetric(horizontal: 8, vertical: 3);
  static const EdgeInsets categoryChipStripPad =
      EdgeInsets.fromLTRB(4, 8, 4, 8);
  static const EdgeInsets categoryChipStripPadTv =
      EdgeInsets.fromLTRB(2, 2, 2, 2);
  static const double categoryChipGap = 8;
  static const double categoryChipGapTv = 4;

  /// Expandable pack / addon header + nested children inset.
  static const double expandHeaderLeadingTop = 12;
  static const double expandHeaderLeadingTopTv = 6;
  static const double expandHeaderPadV = 8;
  static const double expandHeaderPadVTv = 4;
  static const EdgeInsets expandChildrenPad =
      EdgeInsets.fromLTRB(8, 0, 2, 8);
  static const EdgeInsets expandChildrenPadTv =
      EdgeInsets.fromLTRB(4, 0, 2, 4);

  /// Flat switch geometry — thumb is always a circle (never non-uniform scaled).
  static const double switchTrackWidth = 34;
  static const double switchTrackWidthTv = switchTrackWidth * _s;
  static const double switchTrackHeight = 18;
  static const double switchTrackHeightTv = switchTrackHeight * _s;
  static const double switchThumbSize = 12;
  static const double switchThumbSizeTv = switchThumbSize * _s;

  /// Filled CTA (Install / Update all / Retry) — chrome family, type = row title.
  static const double filledButtonHeight = 36;
  /// Hand-tuned — chrome ×scale (~22) crushes label + icon; keep denser than
  /// desktop but roomy enough for the type ladder.
  static const double filledButtonHeightTv = 28;
  static const double filledButtonIconSize = 18;
  static const double filledButtonIconSizeTv = filledButtonIconSize * _s;
  static const double filledButtonPadH = 18;
  static const double filledButtonPadHTv = filledButtonPadH * _s;

  /// Icon-only toolbar (Reload / remove) — chrome family.
  static const double iconButtonIconSize = 20;
  static const double iconButtonIconSizeTv = iconButtonIconSize * _s;
  static const double iconButtonHitSize = 40;
  static const double iconButtonHitSizeTv = iconButtonHitSize * _s;

  /// Expand / collapse chevron on Settings expandable rows.
  static const double expandChevronSize = 20;
  /// Hand-tuned — chrome ×scale of 20 still dominates denser row type.
  static const double expandChevronSizeTv = 12;
  static const double expandChevronHitSize = 40;
  static const double expandChevronHitSizeTv = 28;

  /// Profile & account active-profile stage (avatar + Watching now).
  static const double profileStageAvatarSize = 88;
  static const double profileStageAvatarSizeTv =
      profileStageAvatarSize * _s;
  static const double profileStageGlowSize = 108;
  static const double profileStageGlowSizeTv = profileStageGlowSize * _s;
  static const double profileStageGap = 20;
  static const double profileStageGapTv = profileStageGap * _s;
  static const double profileStageChevronSize = 28;
  static const double profileStageChevronSizeTv = expandChevronSizeTv;
  static const EdgeInsets profileStagePad =
      EdgeInsets.fromLTRB(2, 10, 2, 18);
  static const EdgeInsets profileStagePadTv =
      EdgeInsets.fromLTRB(2, 6, 2, 10);
  static const EdgeInsets profileStageBadgePad =
      EdgeInsets.symmetric(horizontal: 8, vertical: 3);
  static const EdgeInsets profileStageBadgePadTv =
      EdgeInsets.symmetric(horizontal: 5, vertical: 2);

  /// Underline [SettingsTextField] content inset.
  static const double textFieldPadTop = 18;
  static const double textFieldPadTopTv = textFieldPadTop * _s;
  static const double textFieldPadBottom = 10;
  static const double textFieldPadBottomTv = textFieldPadBottom * _s;

  /// Settings [Slider] chrome (disk cache, connections, …).
  static const double sliderTrackHeight = 3;
  static const double sliderTrackHeightTv = 2;
  static const double sliderThumbRadius = 8;
  static const double sliderThumbRadiusTv = 5;
  static const double sliderOverlayRadius = 16;
  static const double sliderOverlayRadiusTv = 10;
  static const double sliderTickRadius = 2;
  static const double sliderTickRadiusTv = 1.5;
  static const double sliderPadTop = 8;
  static const double sliderPadTopTv = sliderPadTop * _s;
  static const double sliderPadBottom = 12;
  static const double sliderPadBottomTv = sliderPadBottom * _s;

  /// Forja Packs choice cards (Official / Community).
  static const double packChoiceMinHeight = 168;
  static const double packChoiceMinHeightTv = packChoiceMinHeight * _s;
  static const double packChoiceMinHeightCompact = 112;
  /// Hand-tuned — chrome ×scale of 112 still leaves a tall empty band under
  /// denser type; hug content + [IntrinsicHeight] stretch instead.
  static const double packChoiceMinHeightCompactTv = 0;
  static const double packChoiceRadius = 16;
  static const double packChoiceRadiusTv = 6;
  static const double packChoiceRadiusCompact = 12;
  /// Hand-tuned — chrome ×scale of 12 still reads pill-like on denser TV tiles.
  static const double packChoiceRadiusCompactTv = 4;
  static const double packChoiceIconSize = 32;
  static const double packChoiceIconSizeTv = packChoiceIconSize * _s;
  static const double packChoiceIconSizeCompact = 22;
  static const double packChoiceIconSizeCompactTv = categoryIconSizeTv;
  static const double packChoiceGap = 14;
  static const double packChoiceGapTv = 8;
  static const double packChoiceGapCompact = 10;
  /// Hand-tuned — chrome ×scale of 10 still reads wide next to denser TV cards.
  static const double packChoiceGapCompactTv = 6;
  static const EdgeInsets packChoicePad =
      EdgeInsets.fromLTRB(18, 20, 18, 18);
  static const EdgeInsets packChoicePadTv =
      EdgeInsets.fromLTRB(10, 10, 10, 10);
  static const EdgeInsets packChoicePadCompact =
      EdgeInsets.fromLTRB(12, 12, 12, 12);
  static const EdgeInsets packChoicePadCompactTv =
      EdgeInsets.fromLTRB(8, 8, 8, 8);
  static const double packChoiceIconTitleGap = 16;
  static const double packChoiceIconTitleGapTv = 8;
  static const double packChoiceIconTitleGapCompact = 10;
  static const double packChoiceIconTitleGapCompactTv = 6;
  static const double packChoiceTitleSubGap = 8;
  static const double packChoiceTitleSubGapTv = 4;
  static const double packChoiceTitleSubGapCompact = 4;
  static const double packChoiceTitleSubGapCompactTv = 3;
  /// Outer pad around the Official / Community row in Settings → Forja Packs.
  static const EdgeInsets packChoiceSectionPad =
      EdgeInsets.fromLTRB(2, 4, 2, 14);
  static const EdgeInsets packChoiceSectionPadTv =
      EdgeInsets.fromLTRB(2, 2, 2, 8);

  /// [AlertDialog] / select-sheet chrome (Settings + rehosted overlays).
  static const double dialogMaxWidthFraction = 0.45;
  static const double dialogMaxWidthFractionTv = 0.32;
  static const double dialogMaxWidthMin = 320;
  static const double dialogMaxWidthMinTv = 240;
  /// Desktop confirm / pack-update dialogs were fixed at 420–440 before TV
  /// density work — keep that cap (do not grow toward a 10-foot sheet).
  static const double dialogMaxWidthCap = 440;
  static const double dialogMaxWidthCapTv = 360;
  static const double dialogMaxHeightFraction = 0.65;
  static const double dialogMaxHeightFractionTv = 0.55;
  static const double dialogOptionPadH = 14;
  static const double dialogOptionPadHTv = dialogOptionPadH * _s;
  static const double dialogOptionPadV = 12;
  static const double dialogOptionPadVTv = dialogOptionPadV * _s;
  static const double dialogCheckSize = 22;
  static const double dialogCheckSizeTv = dialogCheckSize * _s;
  static const double dialogRadius = 14;
  static const double dialogRadiusTv = 10;
  static const double dialogInsetH = 40;
  static const double dialogInsetHTv = 48;
  static const double dialogInsetV = 24;
  static const double dialogInsetVTv = 20;
  static const double dialogTitlePadH = 24;
  static const double dialogTitlePadHTv = 16;
  static const double dialogTitlePadTop = 24;
  static const double dialogTitlePadTopTv = 14;
  static const double dialogTitlePadBottom = 16;
  static const double dialogTitlePadBottomTv = 8;
  static const double dialogContentPadH = 24;
  static const double dialogContentPadHTv = 16;
  static const double dialogContentPadBottom = 24;
  static const double dialogContentPadBottomTv = 12;

  /// True when Settings should show the split sidebar layout.
  /// Desktop / wide and Android TV (1080p+) use the same hub chrome.
  static bool useSplitLayout(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= splitMinWidth;
  }

  static bool _tv(BuildContext context) =>
      ShellPaintScope.usesTvDensityOf(context);

  static double sidebarWidthOf(BuildContext context) =>
      _tv(context) ? sidebarWidthTv : sidebarWidth;

  static double detailMaxWidthOf(BuildContext context) =>
      _tv(context) ? detailMaxWidthTv : detailMaxWidth;

  static double rowMinHeightOf(BuildContext context) =>
      _tv(context) ? rowMinHeightTv : rowMinHeight;

  static double groupSpacingOf(BuildContext context) =>
      _tv(context) ? groupSpacingTv : groupSpacing;

  static double pagePaddingOf(BuildContext context) =>
      _tv(context) ? pagePaddingTv : pagePadding;

  static double groupLabelSizeOf(BuildContext context) =>
      _tv(context) ? groupLabelSizeTv : groupLabelSize;

  static double categoryTitleSizeOf(BuildContext context) =>
      _tv(context) ? categoryTitleSizeTv : categoryTitleSize;

  static double categorySubtitleSizeOf(BuildContext context) =>
      _tv(context) ? categorySubtitleSizeTv : categorySubtitleSize;

  static double categoryIconSizeOf(BuildContext context) =>
      _tv(context) ? categoryIconSizeTv : categoryIconSize;

  static double pageTitleSizeOf(BuildContext context) =>
      _tv(context) ? pageTitleSizeTv : pageTitleSize;

  static double hubTitleSizeOf(BuildContext context) =>
      _tv(context) ? hubTitleSizeTv : hubTitleSize;

  static double rowTitleSizeOf(BuildContext context) =>
      _tv(context) ? rowTitleSizeTv : rowTitleSize;

  static double rowSubtitleSizeOf(BuildContext context) =>
      _tv(context) ? rowSubtitleSizeTv : rowSubtitleSize;

  static EdgeInsets rowPaddingOf(BuildContext context) => EdgeInsets.symmetric(
        horizontal: rowPadH,
        vertical: _tv(context) ? rowPadVTv : rowPadV,
      );

  static EdgeInsets addonListRowPaddingOf(BuildContext context) =>
      EdgeInsets.symmetric(
        horizontal: rowPadH,
        vertical: _tv(context) ? addonListRowPadVTv : addonListRowPadV,
      );

  static double addonListSeparatorHeightOf(BuildContext context) =>
      _tv(context) ? addonListSeparatorHeightTv : addonListSeparatorHeight;

  static double rowTitleSubtitleGapOf(BuildContext context) =>
      _tv(context) ? rowTitleSubtitleGapTv : rowTitleSubtitleGap;

  static EdgeInsets categoryChipPadOf(BuildContext context) =>
      _tv(context) ? categoryChipPadTv : categoryChipPad;

  static EdgeInsets categoryChipStripPadOf(BuildContext context) =>
      _tv(context) ? categoryChipStripPadTv : categoryChipStripPad;

  static double categoryChipGapOf(BuildContext context) =>
      _tv(context) ? categoryChipGapTv : categoryChipGap;

  static double expandHeaderLeadingTopOf(BuildContext context) =>
      _tv(context) ? expandHeaderLeadingTopTv : expandHeaderLeadingTop;

  static double expandHeaderPadVOf(BuildContext context) =>
      _tv(context) ? expandHeaderPadVTv : expandHeaderPadV;

  static EdgeInsets expandChildrenPadOf(BuildContext context) =>
      _tv(context) ? expandChildrenPadTv : expandChildrenPad;

  static double switchTrackWidthOf(BuildContext context) =>
      _tv(context) ? switchTrackWidthTv : switchTrackWidth;

  static double switchTrackHeightOf(BuildContext context) =>
      _tv(context) ? switchTrackHeightTv : switchTrackHeight;

  static double switchThumbSizeOf(BuildContext context) =>
      _tv(context) ? switchThumbSizeTv : switchThumbSize;

  static double filledButtonHeightOf(BuildContext context) =>
      _tv(context) ? filledButtonHeightTv : filledButtonHeight;

  static double filledButtonFontSizeOf(BuildContext context) =>
      rowTitleSizeOf(context);

  static double filledButtonIconSizeOf(BuildContext context) =>
      _tv(context) ? filledButtonIconSizeTv : filledButtonIconSize;

  static double filledButtonPadHOf(BuildContext context) =>
      _tv(context) ? filledButtonPadHTv : filledButtonPadH;

  static double iconButtonIconSizeOf(BuildContext context) =>
      _tv(context) ? iconButtonIconSizeTv : iconButtonIconSize;

  static double iconButtonHitSizeOf(BuildContext context) =>
      _tv(context) ? iconButtonHitSizeTv : iconButtonHitSize;

  static double expandChevronSizeOf(BuildContext context) =>
      _tv(context) ? expandChevronSizeTv : expandChevronSize;

  static double expandChevronHitSizeOf(BuildContext context) =>
      _tv(context) ? expandChevronHitSizeTv : expandChevronHitSize;

  static double profileStageAvatarSizeOf(BuildContext context) =>
      _tv(context) ? profileStageAvatarSizeTv : profileStageAvatarSize;

  static double profileStageGlowSizeOf(BuildContext context) =>
      _tv(context) ? profileStageGlowSizeTv : profileStageGlowSize;

  static double profileStageGapOf(BuildContext context) =>
      _tv(context) ? profileStageGapTv : profileStageGap;

  static double profileStageChevronSizeOf(BuildContext context) =>
      _tv(context) ? profileStageChevronSizeTv : profileStageChevronSize;

  static EdgeInsets profileStagePadOf(BuildContext context) =>
      _tv(context) ? profileStagePadTv : profileStagePad;

  static EdgeInsets profileStageBadgePadOf(BuildContext context) =>
      _tv(context) ? profileStageBadgePadTv : profileStageBadgePad;

  static double textFieldPadTopOf(BuildContext context) =>
      _tv(context) ? textFieldPadTopTv : textFieldPadTop;

  static double textFieldPadBottomOf(BuildContext context) =>
      _tv(context) ? textFieldPadBottomTv : textFieldPadBottom;

  static double sliderTrackHeightOf(BuildContext context) =>
      _tv(context) ? sliderTrackHeightTv : sliderTrackHeight;

  static double sliderThumbRadiusOf(BuildContext context) =>
      _tv(context) ? sliderThumbRadiusTv : sliderThumbRadius;

  static double sliderOverlayRadiusOf(BuildContext context) =>
      _tv(context) ? sliderOverlayRadiusTv : sliderOverlayRadius;

  static double sliderTickRadiusOf(BuildContext context) =>
      _tv(context) ? sliderTickRadiusTv : sliderTickRadius;

  static double sliderPadTopOf(BuildContext context) =>
      _tv(context) ? sliderPadTopTv : sliderPadTop;

  static double sliderPadBottomOf(BuildContext context) =>
      _tv(context) ? sliderPadBottomTv : sliderPadBottom;

  static double packChoiceMinHeightOf(
    BuildContext context, {
    required bool compact,
  }) {
    if (compact) {
      return _tv(context)
          ? packChoiceMinHeightCompactTv
          : packChoiceMinHeightCompact;
    }
    return _tv(context) ? packChoiceMinHeightTv : packChoiceMinHeight;
  }

  static double packChoiceRadiusOf(
    BuildContext context, {
    required bool compact,
  }) {
    if (compact) {
      return _tv(context)
          ? packChoiceRadiusCompactTv
          : packChoiceRadiusCompact;
    }
    return _tv(context) ? packChoiceRadiusTv : packChoiceRadius;
  }

  static double packChoiceIconSizeOf(
    BuildContext context, {
    required bool compact,
  }) {
    if (compact) {
      return _tv(context)
          ? packChoiceIconSizeCompactTv
          : packChoiceIconSizeCompact;
    }
    return _tv(context) ? packChoiceIconSizeTv : packChoiceIconSize;
  }

  static double packChoiceGapOf(
    BuildContext context, {
    required bool compact,
  }) =>
      compact
          ? (_tv(context) ? packChoiceGapCompactTv : packChoiceGapCompact)
          : (_tv(context) ? packChoiceGapTv : packChoiceGap);

  static EdgeInsets packChoicePadOf(
    BuildContext context, {
    required bool compact,
  }) {
    if (compact) {
      return _tv(context) ? packChoicePadCompactTv : packChoicePadCompact;
    }
    return _tv(context) ? packChoicePadTv : packChoicePad;
  }

  static double packChoiceIconTitleGapOf(
    BuildContext context, {
    required bool compact,
  }) =>
      compact
          ? (_tv(context)
              ? packChoiceIconTitleGapCompactTv
              : packChoiceIconTitleGapCompact)
          : (_tv(context) ? packChoiceIconTitleGapTv : packChoiceIconTitleGap);

  static double packChoiceTitleSubGapOf(
    BuildContext context, {
    required bool compact,
  }) =>
      compact
          ? (_tv(context)
              ? packChoiceTitleSubGapCompactTv
              : packChoiceTitleSubGapCompact)
          : (_tv(context) ? packChoiceTitleSubGapTv : packChoiceTitleSubGap);

  static EdgeInsets packChoiceSectionPadOf(BuildContext context) =>
      _tv(context) ? packChoiceSectionPadTv : packChoiceSectionPad;

  static double dialogMaxWidthOf(BuildContext context, double screenWidth) {
    final fraction =
        _tv(context) ? dialogMaxWidthFractionTv : dialogMaxWidthFraction;
    final min = _tv(context) ? dialogMaxWidthMinTv : dialogMaxWidthMin;
    final cap = _tv(context) ? dialogMaxWidthCapTv : dialogMaxWidthCap;
    return (screenWidth * fraction).clamp(min, cap);
  }

  static double dialogMaxHeightOf(BuildContext context, double screenHeight) {
    final fraction =
        _tv(context) ? dialogMaxHeightFractionTv : dialogMaxHeightFraction;
    return screenHeight * fraction;
  }

  static double dialogOptionPadHOf(BuildContext context) =>
      _tv(context) ? dialogOptionPadHTv : dialogOptionPadH;

  static double dialogOptionPadVOf(BuildContext context) =>
      _tv(context) ? dialogOptionPadVTv : dialogOptionPadV;

  static double dialogCheckSizeOf(BuildContext context) =>
      _tv(context) ? dialogCheckSizeTv : dialogCheckSize;

  static double dialogRadiusOf(BuildContext context) =>
      _tv(context) ? dialogRadiusTv : dialogRadius;

  static EdgeInsets dialogInsetPaddingOf(BuildContext context) => EdgeInsets.symmetric(
        horizontal: _tv(context) ? dialogInsetHTv : dialogInsetH,
        vertical: _tv(context) ? dialogInsetVTv : dialogInsetV,
      );

  static EdgeInsets dialogTitlePaddingOf(BuildContext context) => EdgeInsets.fromLTRB(
        _tv(context) ? dialogTitlePadHTv : dialogTitlePadH,
        _tv(context) ? dialogTitlePadTopTv : dialogTitlePadTop,
        _tv(context) ? dialogTitlePadHTv : dialogTitlePadH,
        _tv(context) ? dialogTitlePadBottomTv : dialogTitlePadBottom,
      );

  static EdgeInsets dialogContentPaddingOf(BuildContext context) =>
      EdgeInsets.fromLTRB(
        _tv(context) ? dialogContentPadHTv : dialogContentPadH,
        0,
        _tv(context) ? dialogContentPadHTv : dialogContentPadH,
        _tv(context) ? dialogContentPadBottomTv : dialogContentPadBottom,
      );

  /// Map a one-off desktop [fontSize] onto the Settings ladder (same as
  /// [ShellTokens.tvTypeSize] on TV). Prefer named roles above when the
  /// role is clear; use this for legacy literals during migration.
  static double typeSizeOf(BuildContext context, double desktop) =>
      _tv(context) ? ShellTokens.tvTypeSize(desktop) : desktop;
}
