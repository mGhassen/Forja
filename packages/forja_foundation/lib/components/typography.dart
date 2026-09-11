import 'package:flutter/material.dart';
import 'package:forja_foundation/theme/forja_theme_extension.dart';

/// Heading level for [Heading].
enum HeadingLevel {
  h1,
  h2,
  h3,
  h4,
}

/// Theme-aware heading text.
class Heading extends StatelessWidget {
  const Heading(
    this.text, {
    super.key,
    this.level = HeadingLevel.h2,
    this.color,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  final String text;
  final HeadingLevel level;
  final Color? color;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    final style = switch (level) {
      HeadingLevel.h1 => TextStyle(
          color: color ?? theme.textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.w800,
          height: 1.2,
          letterSpacing: -0.3,
        ),
      HeadingLevel.h2 => TextStyle(
          color: color ?? theme.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          height: 1.25,
          letterSpacing: -0.2,
        ),
      HeadingLevel.h3 => TextStyle(
          color: color ?? theme.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
      HeadingLevel.h4 => TextStyle(
          color: color ?? theme.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w700,
          height: 1.35,
        ),
    };
    return Text(
      text,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}

/// Body text tone.
enum BodyTone {
  primary,
  secondary,
  muted,
}

/// Theme-aware body text.
class Body extends StatelessWidget {
  const Body(
    this.text, {
    super.key,
    this.tone = BodyTone.primary,
    this.size = 14,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.weight = FontWeight.w400,
  });

  final String text;
  final BodyTone tone;
  final double size;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    final color = switch (tone) {
      BodyTone.primary => theme.textPrimary,
      BodyTone.secondary => theme.textSecondary,
      BodyTone.muted => theme.textSecondary.withValues(alpha: 0.7),
    };
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: size,
        fontWeight: weight,
        height: 1.45,
      ),
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}
