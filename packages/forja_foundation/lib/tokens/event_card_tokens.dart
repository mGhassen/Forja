import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

/// Layout tokens for live event cards.
abstract final class EventCardTokens {
  static const double _s = ShellTokens.tvChromeScale;

  static const double radius = 14;
  static const double radiusTv = 8;
  static const double titleFontSize = 12;
  static const double titleFontSizeTv = ShellTokens.tvBodyFontSize;
  static const double metaFontSize = 10;
  static const double metaFontSizeTv = ShellTokens.tvMetaFontSize;
  static const double badgeFontSize = 8.5;
  static const double badgeFontSizeTv = ShellTokens.tvMetaFontSize;
  static const double playIconSize = 28;
  static const double playIconSizeTv = playIconSize * _s;
  static const double playOverlaySize = 48;
  static const double playOverlaySizeTv = playOverlaySize * _s;
  static const double padV = 8;
  static const double padVTv = padV * _s;
  static const double cornerBadgeFontSize = 10;
  static const double cornerBadgeFontSizeTv = ShellTokens.tvMetaFontSize;
  static const double teamAvatarRadius = 18;
  static const double teamAvatarRadiusTv = teamAvatarRadius * _s;

  /// Desktop grid min width = continue-watching wide × this.
  static const double desktopWidthScale = 0.85;

  /// Desktop grid min height = continue-watching wide × this.
  static const double desktopHeightScale = 1.0;

  static const double desktopHeightMin = 130;
  static const double desktopHeightMax = 165;

  /// Kit paint fallback when props omit width/height.
  static const double paintFallbackWidth = 220;
  static const double paintFallbackHeight = 124;

  static bool _tv(BuildContext context) =>
      ShellPaintScope.usesTvDensityOf(context);

  static double radiusOf(BuildContext context) =>
      _tv(context) ? radiusTv : radius;

  static double titleFontSizeOf(BuildContext context) =>
      _tv(context) ? titleFontSizeTv : titleFontSize;

  static double metaFontSizeOf(BuildContext context) =>
      _tv(context) ? metaFontSizeTv : metaFontSize;

  static double badgeFontSizeOf(BuildContext context) =>
      _tv(context) ? badgeFontSizeTv : badgeFontSize;

  static double playIconSizeOf(BuildContext context) =>
      _tv(context) ? playIconSizeTv : playIconSize;

  static double playOverlaySizeOf(BuildContext context) =>
      _tv(context) ? playOverlaySizeTv : playOverlaySize;

  static double padVOf(BuildContext context) =>
      _tv(context) ? padVTv : padV;

  static double cornerBadgeFontSizeOf(BuildContext context) =>
      _tv(context) ? cornerBadgeFontSizeTv : cornerBadgeFontSize;

  static double teamAvatarRadiusOf(BuildContext context) =>
      _tv(context) ? teamAvatarRadiusTv : teamAvatarRadius;
}
