import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:forja/shared/theme/app_theme.dart';

class AppTheme {
  static const bgDark = Color(0xFF141414);
  static const bgCard = Color(0xFF1C1C1C);
  static const primary = Color(0xFF3B82F6);
  static const primaryDim = Color(0xFF2563EB);
  static const accent = Color(0xFF00E5FF);
  static const textPrimary = Color(0xFFF5F5F7);
  static const textSecondary = Color(0xFF9CA3AF);
  static const border = Color(0xFF2A2A35);

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
