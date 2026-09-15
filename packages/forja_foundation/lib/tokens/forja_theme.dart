import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';

/// Palette aliases for server grid / player overlay panels.
///
/// Prefer [ForjaShellColors] / [ForjaThemeExtension] for new UI.
/// [ThemeData] entry is [forjaThemeData] only — do not add a second factory here.
abstract final class DesignTokens {
  static const bgDark = ForjaShellColors.bgDark;
  static const bgCard = ForjaShellColors.surfaceElevated;
  static const primary = ForjaShellColors.brandGreen;
  static const primaryDim = Color(0xFF17C972);
  static const accent = Color(0xFF9CA3AF);
  static const textPrimary = Color(0xFFF5F5F7);
  static const textSecondary = Color(0xFF9CA3AF);
  static const border = Color(0xFF2A2A2A);
}
