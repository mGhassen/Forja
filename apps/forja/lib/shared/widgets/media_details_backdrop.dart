import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Blurred, top-aligned backdrop used to continue the hero image into the body.
class MediaDetailsBackdropLayer extends StatelessWidget {
  const MediaDetailsBackdropLayer({
    super.key,
    required this.imageUrl,
    this.blurSigma = 36,
    this.alignment = Alignment.topCenter,
    this.scale = 1.18,
  });

  final String imageUrl;
  final double blurSigma;
  final Alignment alignment;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(
          sigmaX: blurSigma,
          sigmaY: blurSigma,
          tileMode: TileMode.decal,
        ),
        child: Transform.scale(
          scale: scale,
          alignment: alignment,
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            alignment: alignment,
            width: double.infinity,
            height: double.infinity,
            errorWidget: (_, _, _) => const ColoredBox(color: Color(0xFF141414)),
          ),
        ),
      ),
    );
  }
}

/// Blurred backdrop + vertical scrim for hero-to-body continuity.
class MediaDetailsBackdropScrim extends StatelessWidget {
  const MediaDetailsBackdropScrim({
    super.key,
    this.imageUrl,
    required this.gradientStops,
    required this.gradientColors,
    this.blurSigma = 36,
    this.fallbackColor = const Color(0xFF141414),
    this.imageScale = 1.18,
  });

  final String? imageUrl;
  final List<double> gradientStops;
  final List<Color> gradientColors;
  final double blurSigma;
  final Color fallbackColor;
  final double imageScale;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    final hasImage = url != null && url.isNotEmpty;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (hasImage)
          MediaDetailsBackdropLayer(
            imageUrl: url,
            blurSigma: blurSigma,
            scale: imageScale,
          )
        else
          ColoredBox(color: fallbackColor),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: gradientColors,
              stops: gradientStops,
            ),
          ),
        ),
      ],
    );
  }
}
