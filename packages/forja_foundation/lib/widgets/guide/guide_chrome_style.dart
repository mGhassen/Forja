import 'package:flutter/material.dart';

import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/widgets/chrome/forja_scrollbar.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

/// Guide / live player chrome tokens — flat cinematic shell (RFC-025).
abstract final class GuideChromeStyle {
  static const cinematic = ForjaShellColors.cinematic;

  static Color get accent => cinematic.navUnderline;
  static Color get accentMuted => cinematic.textSecondary;
  static Color get textPrimary => cinematic.textPrimary;
  static Color get textSecondary => cinematic.textSecondary;
  static Color get border => cinematic.borderSubtle;
  static Color get surface => cinematic.menuSurface;
  /// Translucent dark glass over live video (floating EPG, channel guide shell).
  /// Matches [ForjaFrostedPanel] without blur — no BackdropFilter on the player.
  static Color get surfaceGlass =>
      cinematic.menuSurface.withValues(alpha: 0.82);
  static Color get surfaceMuted => Colors.white.withValues(alpha: 0.04);
  static Color get chipSelectedBg => ForjaShellColors.chipSelectedBg;
  static Color get chipSelectedBorder => ForjaShellColors.chipSelectedBorder;
  static Color get progress => ForjaShellColors.brandGreen;
  static Color get iconMuted => ForjaShellColors.cinematic.textSecondary;
  static Color get liveBadge => const Color(0xFFEF4444);

  static const TextStyle pageTitle = TextStyle(
    color: Colors.white,
    fontSize: 20,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
  );

  static const TextStyle headerTitle = TextStyle(
    color: Colors.white,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle overlayTitle = TextStyle(
    color: Colors.white,
    fontSize: 19,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
  );

  static BoxDecoration chipDecoration({required bool selected}) => BoxDecoration(
        color: selected ? chipSelectedBg : surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? chipSelectedBorder : Colors.white.withValues(alpha: 0.12),
        ),
      );

  static BoxDecoration primaryButtonDecoration({bool subtle = false}) =>
      BoxDecoration(
        color: subtle ? surfaceMuted : chipSelectedBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: subtle ? border : chipSelectedBorder,
        ),
      );

  static BoxDecoration dialogSurface() => BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      );

  static SliderThemeData sliderTheme(BuildContext context) =>
      SliderTheme.of(context).copyWith(
        activeTrackColor: progress,
        inactiveTrackColor: Colors.white.withValues(alpha: 0.18),
        thumbColor: ForjaShellColors.brandGreen,
        overlayColor: progress.withValues(alpha: 0.2),
      );
}

/// Thin green position scroller for **list** chrome (categories, channels,
/// schedules, Portals, guide). No-op off TV — desktop uses [ForjaScrollBehavior].
class LiveTvScrollbar extends StatelessWidget {
  const LiveTvScrollbar({
    super.key,
    required this.controller,
    required this.child,
    /// When set, overrides [ShellPaintScope.usesTvDensityOf].
    this.enabled,
  });

  final ScrollController controller;
  final Widget child;
  final bool? enabled;

  @override
  Widget build(BuildContext context) {
    final on = enabled ?? ShellPaintScope.usesTvDensityOf(context);
    if (!on) return child;
    return RawScrollbar(
      controller: controller,
      thumbVisibility: true,
      trackVisibility: true,
      interactive: false,
      thickness: ForjaScrollbarStyle.thickness,
      radius: ForjaScrollbarStyle.radius,
      mainAxisMargin: ForjaScrollbarStyle.mainAxisMargin,
      crossAxisMargin: ForjaScrollbarStyle.crossAxisMargin,
      thumbColor: ForjaScrollbarStyle.thumbColor,
      trackColor: ForjaScrollbarStyle.trackColor,
      trackBorderColor: Colors.transparent,
      child: forjaSuppressAutoScrollbar(context: context, child: child),
    );
  }
}

/// Alias — guide panels often prefer the Guide* name.
typedef GuideTvScrollbar = LiveTvScrollbar;
