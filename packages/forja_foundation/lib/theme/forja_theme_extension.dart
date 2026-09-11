import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:google_fonts/google_fonts.dart';

/// Theme extension bridging shell colors + spacing into [ThemeData].
@immutable
class ForjaThemeExtension extends ThemeExtension<ForjaThemeExtension> {
  const ForjaThemeExtension({
    required this.brandGreen,
    required this.textPrimary,
    required this.textSecondary,
    required this.borderSubtle,
    required this.surfaceElevated,
    required this.bgDark,
    required this.spaceSm,
    required this.spaceMd,
    required this.spaceLg,
    required this.radiusSm,
    required this.radiusMd,
  });

  factory ForjaThemeExtension.dark() => const ForjaThemeExtension(
        brandGreen: ForjaShellColors.brandGreen,
        textPrimary: ForjaShellColors.textPrimary,
        textSecondary: ForjaShellColors.textSecondary,
        borderSubtle: ForjaShellColors.borderSubtle,
        surfaceElevated: ForjaShellColors.surfaceElevated,
        bgDark: Color(0xFF141414),
        spaceSm: 8,
        spaceMd: 16,
        spaceLg: 24,
        radiusSm: 6,
        radiusMd: 8,
      );

  final Color brandGreen;
  final Color textPrimary;
  final Color textSecondary;
  final Color borderSubtle;
  final Color surfaceElevated;
  final Color bgDark;
  final double spaceSm;
  final double spaceMd;
  final double spaceLg;
  final double radiusSm;
  final double radiusMd;

  static ForjaThemeExtension of(BuildContext context) {
    final ext = Theme.of(context).extension<ForjaThemeExtension>();
    return ext ?? ForjaThemeExtension.dark();
  }

  @override
  ForjaThemeExtension copyWith({
    Color? brandGreen,
    Color? textPrimary,
    Color? textSecondary,
    Color? borderSubtle,
    Color? surfaceElevated,
    Color? bgDark,
    double? spaceSm,
    double? spaceMd,
    double? spaceLg,
    double? radiusSm,
    double? radiusMd,
  }) {
    return ForjaThemeExtension(
      brandGreen: brandGreen ?? this.brandGreen,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      bgDark: bgDark ?? this.bgDark,
      spaceSm: spaceSm ?? this.spaceSm,
      spaceMd: spaceMd ?? this.spaceMd,
      spaceLg: spaceLg ?? this.spaceLg,
      radiusSm: radiusSm ?? this.radiusSm,
      radiusMd: radiusMd ?? this.radiusMd,
    );
  }

  @override
  ForjaThemeExtension lerp(ThemeExtension<ForjaThemeExtension>? other, double t) {
    if (other is! ForjaThemeExtension) return this;
    return ForjaThemeExtension(
      brandGreen: Color.lerp(brandGreen, other.brandGreen, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      bgDark: Color.lerp(bgDark, other.bgDark, t)!,
      spaceSm: lerpDouble(spaceSm, other.spaceSm, t)!,
      spaceMd: lerpDouble(spaceMd, other.spaceMd, t)!,
      spaceLg: lerpDouble(spaceLg, other.spaceLg, t)!,
      radiusSm: lerpDouble(radiusSm, other.radiusSm, t)!,
      radiusMd: lerpDouble(radiusMd, other.radiusMd, t)!,
    );
  }
}

/// Material [ThemeData] factory for Forja dark cinematic shell.
ThemeData forjaThemeData({Brightness brightness = Brightness.dark}) {
  final ext = ForjaThemeExtension.dark();
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
  );
  return base.copyWith(
    scaffoldBackgroundColor: ext.bgDark,
    colorScheme: ColorScheme.dark(
      primary: ext.brandGreen,
      secondary: ext.textSecondary,
      surface: ext.surfaceElevated,
    ),
    textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
      bodyColor: ext.textPrimary,
      displayColor: ext.textPrimary,
    ),
    extensions: <ThemeExtension<dynamic>>[ext],
  );
}
