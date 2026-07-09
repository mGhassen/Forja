import 'package:flutter/material.dart';
import 'package:forja/shared/design/src/forja_shell_colors.dart';
import 'package:google_fonts/google_fonts.dart';

/// Legacy design tokens for server grid / player overlay panels.
abstract final class DesignTokens {
  static const bgDark = Color(0xFF141414);
  static const bgCard = Color(0xFF1C1C1C);
  static const primary = ForjaShellColors.brandGreen;
  static const primaryDim = Color(0xFF17C972);
  static const accent = Color(0xFF9CA3AF);
  static const textPrimary = Color(0xFFF5F5F7);
  static const textSecondary = Color(0xFF9CA3AF);
  static const border = Color(0xFF2A2A2A);

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: bgDark,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accent,
        surface: bgCard,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: border),
        ),
      ),
    );
  }

  static BoxDecoration cinemaBackground = const BoxDecoration(
    color: Color(0xFF141414),
  );
}
