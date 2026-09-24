import 'package:flutter/material.dart';

/// Muted chrome palette for shell nav and flat cinematic CTAs.
abstract final class ForjaShellColors {
  /// Hero / cinematic overlays (Home top bar) - always light text on imagery.
  static const cinematic = _CinematicShellPalette();

  /// Brand green from the Forja logo - hero Play CTA fill.
  static const Color brandGreen = Color(0xFF1CE783);

  /// Pack-update alert (nav badge, Settings tip / tile).
  static const Color packUpdateAlert = Color(0xFFFBBF24);

  static const Color iconMuted = Color(0xFF6B7280);
  static const Color iconActive = Color(0xFF9CA3AF);
  static const Color iconHover = Color(0xFFD1D5DB);
  static const Color textPrimary = Color(0xFFE5E7EB);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color borderSubtle = Color(0xFF2A2A2A);
  /// Hub / IPTV / Live page body (pre-wipe [AppTheme.bgDark]).
  static const Color bgDark = Color(0xFF141414);
  /// Cards / elevated chrome on [bgDark] — not the page fill.
  static const Color surfaceElevated = Color(0xFF1C1C1C);
  static const Color ghostBorder = Color(0xFF4B5563);
  static const Color navUnderline = Color(0xFFE5E7EB);
  static const Color inkHover = Color(0x0AFFFFFF);
  static const Color inkSplash = Color(0x14FFFFFF);
  static const Color sectionIconBg = Color(0xFF252525);
  static const Color sectionAccent = iconActive;
  static const Color chipSelectedBg = Color(0x33FFFFFF);
  static const Color chipSelectedBorder = Color(0x99E5E7EB);
  static const Color chipSelectedIcon = textPrimary;
  static const Color progressFill = textPrimary;
  static const Color badgeLabel = textSecondary;

  /// Unaired / not-yet-started episode date and number-chip label (soft amber).
  static const Color upcomingMuted = Color(0xFFC9A46C);
}

/// Fixed dark-on-imagery palette for hero overlays.
final class _CinematicShellPalette {
  const _CinematicShellPalette();

  Color get textPrimary => ForjaShellColors.textPrimary;
  Color get textSecondary => ForjaShellColors.textSecondary;
  Color get navUnderline => ForjaShellColors.navUnderline;
  Color get borderSubtle => ForjaShellColors.borderSubtle;
  Color get menuSurface => ForjaShellColors.bgDark;

  /// Back / compact ☰ idle on imagery (matches [ShellBackIconButton]).
  Color get chromeIconIdle => Colors.white.withValues(alpha: 0.54);

  /// Back / compact ☰ hover + focus.
  Color get chromeIconActive => Colors.white;
}
