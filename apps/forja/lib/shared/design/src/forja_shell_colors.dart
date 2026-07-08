import 'package:flutter/material.dart';

/// Muted chrome palette for shell nav and flat cinematic CTAs.
/// Shell chrome is theme-independent — do not use [AppTheme.primaryColor] here.
abstract final class ForjaShellColors {
  static const Color iconMuted = Color(0xFF6B7280);
  static const Color iconActive = Color(0xFF9CA3AF);
  static const Color iconHover = Color(0xFFD1D5DB);
  static const Color textPrimary = Color(0xFFE5E7EB);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color borderSubtle = Color(0xFF2A2A2A);
  static const Color surfaceElevated = Color(0xFF1C1C1C);
  static const Color ghostBorder = Color(0xFF4B5563);

  /// Netflix-style active tab underline (white/grey, not theme primary).
  static const Color navUnderline = Color(0xFFE5E7EB);

  /// Subtle Material ink — avoids theme-primary purple hover on shell controls.
  static const Color inkHover = Color(0x0AFFFFFF);
  static const Color inkSplash = Color(0x14FFFFFF);

  /// Flat home section headers (theme-independent).
  static const Color sectionIconBg = Color(0xFF252525);
  static const Color sectionAccent = iconActive;
  static const Color chipSelectedBg = Color(0x33FFFFFF);
  static const Color chipSelectedBorder = Color(0x99E5E7EB);
  static const Color chipSelectedIcon = textPrimary;
  static const Color progressFill = textPrimary;
  static const Color badgeLabel = textSecondary;
}
