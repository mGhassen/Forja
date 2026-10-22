import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

/// Layout tokens for the centered page / overlay wait state
/// (`ForjaLoadingState`): details page while metadata loads, player before
/// the first frame, terminal stream failure.
///
/// Spinner and status icon are **hand-tuned** on TV (readable at 10 ft — not
/// × [ShellTokens.tvChromeScale]). Type uses the leanback ladder; pads follow
/// chrome scale. See density families on [ShellTokens].
abstract final class LoadingStateTokens {
  static const double spinner = 44;

  /// Hand — a chrome-scaled 44 reads as a dot from the couch.
  static const double spinnerTv = 40;
  static const double spinnerStroke = 3;
  static const double spinnerStrokeTv = 3;

  static const double statusIcon = 48;

  /// Hand — same reason as [spinnerTv].
  static const double statusIconTv = 40;

  static const double titleFontSize = 20;
  static const double titleFontSizeTv = ShellTokens.tvTitleFontSize;
  static const double detailFontSize = 14;
  static const double detailFontSizeTv = ShellTokens.tvBodyFontSize;
  static const double hintFontSize = 12;
  static const double hintFontSizeTv = ShellTokens.tvMetaFontSize;

  static const double titleGap = 22;
  static const double titleGapTv = titleGap * ShellTokens.tvChromeScale;
  static const double detailGap = 8;
  static const double detailGapTv = detailGap * ShellTokens.tvChromeScale;
  static const double hintGap = 16;
  static const double hintGapTv = hintGap * ShellTokens.tvChromeScale;
  static const double actionsGap = 24;
  static const double actionsGapTv = actionsGap * ShellTokens.tvChromeScale;

  static const double maxWidth = 480;
  static const double maxWidthTv = maxWidth * ShellTokens.tvChromeScale;
  static const double padH = 32;
  static const double padHTv = padH * ShellTokens.tvChromeScale;
  static const double padV = 24;
  static const double padVTv = padV * ShellTokens.tvChromeScale;

  /// Outlined text actions under the state (Retry / Back).
  static const double actionPadH = 22;
  static const double actionPadHTv = actionPadH * ShellTokens.tvChromeScale;
  static const double actionPadV = 10;
  static const double actionPadVTv = actionPadV * ShellTokens.tvChromeScale;
  static const double actionRadius = 8;
  static const double actionRadiusTv = actionRadius * ShellTokens.tvChromeScale;
  static const double actionFontSize = 14;
  static const double actionFontSizeTv = ShellTokens.tvBodyFontSize;
  static const double actionGap = 16;
  static const double actionGapTv = actionGap * ShellTokens.tvChromeScale;

  /// Type rhythm — shared by the foundation widget and host action faces.
  static const double titleLineHeight = 1.25;
  static const double titleLetterSpacing = 0.15;
  static const double detailLineHeight = 1.4;
  static const double hintLetterSpacing = 0.2;
  static const double actionLetterSpacing = 0.4;

  static const int titleMaxLines = 2;
  static const int detailMaxLines = 2;

  /// Title / detail / hint emphasis on the dark shell background.
  static const double titleAlpha = 0.92;
  static const double detailAlpha = 0.62;
  static const double hintAlpha = 0.45;
}
