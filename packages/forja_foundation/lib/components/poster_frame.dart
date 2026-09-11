import 'package:flutter/material.dart';
import 'package:forja_foundation/theme/forja_theme_extension.dart';
import 'package:forja_foundation/tokens/forja_aspects.dart';

/// Aspect-framed media slot (poster / backdrop).
class PosterFrame extends StatelessWidget {
  const PosterFrame({
    super.key,
    required this.child,
    this.aspectRatio = ForjaAspects.poster,
    this.width,
    this.borderRadius,
    this.clip = true,
  });

  final Widget child;
  final double aspectRatio;
  final double? width;
  final BorderRadius? borderRadius;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    final radius =
        borderRadius ?? BorderRadius.circular(theme.radiusMd);
    Widget framed = AspectRatio(
      aspectRatio: aspectRatio,
      child: clip
          ? ClipRRect(borderRadius: radius, child: child)
          : child,
    );
    if (width != null) {
      framed = SizedBox(width: width, child: framed);
    }
    return framed;
  }
}
