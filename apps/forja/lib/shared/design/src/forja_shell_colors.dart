import 'package:flutter/material.dart';
import 'package:forja/shared/theme/app_theme.dart';

/// Muted chrome palette for shell nav and flat cinematic CTAs.
/// Shell chrome is theme-independent — do not use [AppTheme.primaryColor] here.
abstract final class ForjaShellColors {
  /// Hero / cinematic overlays (Home top bar) — always light text on imagery.
  static const cinematic = _CinematicShellPalette();

  /// Brand green from the Forja logo — hero Play CTA fill.
  static const Color brandGreen = Color(0xFF1CE783);

  static Color get iconMuted =>
      AppTheme.isLightMode ? _lightIconMuted : _darkIconMuted;
  static Color get iconActive =>
      AppTheme.isLightMode ? _lightIconActive : _darkIconActive;
  static Color get iconHover =>
      AppTheme.isLightMode ? _lightIconHover : _darkIconHover;
  static Color get textPrimary =>
      AppTheme.isLightMode ? _lightTextPrimary : _darkTextPrimary;
  static Color get textSecondary =>
      AppTheme.isLightMode ? _lightTextSecondary : _darkTextSecondary;
  static Color get borderSubtle =>
      AppTheme.isLightMode ? _lightBorderSubtle : _darkBorderSubtle;
  static Color get surfaceElevated =>
      AppTheme.isLightMode ? _lightSurfaceElevated : _darkSurfaceElevated;
  static Color get ghostBorder =>
      AppTheme.isLightMode ? _lightGhostBorder : _darkGhostBorder;
  static Color get navUnderline =>
      AppTheme.isLightMode ? _lightNavUnderline : _darkNavUnderline;
  static Color get inkHover =>
      AppTheme.isLightMode ? _lightInkHover : _darkInkHover;
  static Color get inkSplash =>
      AppTheme.isLightMode ? _lightInkSplash : _darkInkSplash;
  static Color get sectionIconBg =>
      AppTheme.isLightMode ? _lightSectionIconBg : _darkSectionIconBg;
  static Color get sectionAccent => iconActive;
  static Color get chipSelectedBg =>
      AppTheme.isLightMode ? _lightChipSelectedBg : _darkChipSelectedBg;
  static Color get chipSelectedBorder =>
      AppTheme.isLightMode ? _lightChipSelectedBorder : _darkChipSelectedBorder;
  static Color get chipSelectedIcon =>
      AppTheme.isLightMode ? _lightChipSelectedIcon : _darkChipSelectedIcon;
  static Color get progressFill =>
      AppTheme.isLightMode ? _lightProgressFill : _darkProgressFill;
  static Color get badgeLabel => textSecondary;

  static const Color _darkIconMuted = Color(0xFF6B7280);
  static const Color _darkIconActive = Color(0xFF9CA3AF);
  static const Color _darkIconHover = Color(0xFFD1D5DB);
  static const Color _darkTextPrimary = Color(0xFFE5E7EB);
  static const Color _darkTextSecondary = Color(0xFF9CA3AF);
  static const Color _darkBorderSubtle = Color(0xFF2A2A2A);
  static const Color _darkSurfaceElevated = Color(0xFF1C1C1C);
  static const Color _darkGhostBorder = Color(0xFF4B5563);
  static const Color _darkNavUnderline = Color(0xFFE5E7EB);
  static const Color _darkInkHover = Color(0x0AFFFFFF);
  static const Color _darkInkSplash = Color(0x14FFFFFF);
  static const Color _darkSectionIconBg = Color(0xFF252525);
  static const Color _darkChipSelectedBg = Color(0x33FFFFFF);
  static const Color _darkChipSelectedBorder = Color(0x99E5E7EB);
  static const Color _darkChipSelectedIcon = _darkTextPrimary;
  static const Color _darkProgressFill = _darkTextPrimary;

  static const Color _lightIconMuted = Color(0xFF6B7280);
  static const Color _lightIconActive = Color(0xFF374151);
  static const Color _lightIconHover = Color(0xFF111827);
  static const Color _lightTextPrimary = Color(0xFF111827);
  static const Color _lightTextSecondary = Color(0xFF6B7280);
  static const Color _lightBorderSubtle = Color(0xFFE5E7EB);
  static const Color _lightSurfaceElevated = Color(0xFFFFFFFF);
  static const Color _lightGhostBorder = Color(0xFFD1D5DB);
  static const Color _lightNavUnderline = Color(0xFF111827);
  static const Color _lightInkHover = Color(0x0A000000);
  static const Color _lightInkSplash = Color(0x14000000);
  static const Color _lightSectionIconBg = Color(0xFFF3F4F6);
  static const Color _lightChipSelectedBg = Color(0x1A000000);
  static const Color _lightChipSelectedBorder = Color(0xFF9CA3AF);
  static const Color _lightChipSelectedIcon = _lightTextPrimary;
  static const Color _lightProgressFill = _lightTextPrimary;
}

/// Fixed dark-on-imagery palette for hero overlays (not tied to light mode).
final class _CinematicShellPalette {
  const _CinematicShellPalette();

  Color get textPrimary => ForjaShellColors._darkTextPrimary;
  Color get textSecondary => ForjaShellColors._darkTextSecondary;
  Color get navUnderline => ForjaShellColors._darkNavUnderline;
  Color get borderSubtle => ForjaShellColors._darkBorderSubtle;
  Color get menuSurface => const Color(0xFF141414);
}
