import 'package:flutter/material.dart';
import 'package:forja_foundation/theme/forja_theme_extension.dart';
import 'package:forja_foundation/tokens/forja_aspects.dart';

/// Generic shimmer / placeholder block.
class Skeleton extends StatelessWidget {
  const Skeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius,
  });

  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius:
            borderRadius ?? BorderRadius.circular(theme.radiusSm),
      ),
    );
  }
}

/// Stack of text-line skeletons.
class SkeletonText extends StatelessWidget {
  const SkeletonText({
    super.key,
    this.lines = 3,
    this.lineHeight = 12,
    this.spacing,
    this.lastLineFraction = 0.65,
  });

  final int lines;
  final double lineHeight;
  final double? spacing;
  final double lastLineFraction;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    final gap = spacing ?? theme.spaceSm;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < lines; i++) ...[
          if (i > 0) SizedBox(height: gap),
          FractionallySizedBox(
            widthFactor: i == lines - 1 && lines > 1 ? lastLineFraction : 1,
            alignment: Alignment.centerLeft,
            child: Skeleton(height: lineHeight),
          ),
        ],
      ],
    );
  }
}

/// Poster-shaped skeleton (default 2:3).
class SkeletonPoster extends StatelessWidget {
  const SkeletonPoster({
    super.key,
    this.width = 120,
    this.aspectRatio = ForjaAspects.poster,
    this.borderRadius,
  });

  final double width;
  final double aspectRatio;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    return SizedBox(
      width: width,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Skeleton(
          height: double.infinity,
          borderRadius:
              borderRadius ?? BorderRadius.circular(theme.radiusMd),
        ),
      ),
    );
  }
}
