import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';

/// Shared density for Who’s watching tiles and the profile-switch splash.
///
/// TV uses a tighter composition so title / avatars / splash avatar do not
/// dominate short leanback viewports (overscan + 720p logical height).
@immutable
class ProfileChooserMetrics {
  const ProfileChooserMetrics._({
    required this.isTv,
    required this.titleFontSize,
    required this.subtitleFontSize,
    required this.avatarSize,
    required this.tileWidth,
    required this.tileSpacing,
    required this.sectionGap,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.splashEndFraction,
    required this.splashEndMax,
    required this.splashNameFontSize,
    required this.splashStatusFontSize,
    required this.splashNameGap,
    required this.splashStatusGap,
  });

  final bool isTv;
  final double titleFontSize;
  final double subtitleFontSize;
  final double avatarSize;
  final double tileWidth;
  final double tileSpacing;
  final double sectionGap;
  final double horizontalPadding;
  final double verticalPadding;
  final double splashEndFraction;
  final double splashEndMax;
  final double splashNameFontSize;
  final double splashStatusFontSize;
  final double splashNameGap;
  final double splashStatusGap;

  static ProfileChooserMetrics of(BuildContext context) {
    final tv = ShellTokens.isTvLayout(context);
    if (tv) {
      return const ProfileChooserMetrics._(
        isTv: true,
        titleFontSize: 26,
        subtitleFontSize: 13,
        avatarSize: 80,
        tileWidth: 100,
        tileSpacing: 20,
        sectionGap: 24,
        horizontalPadding: 40,
        verticalPadding: 16,
        // ~¼ of the short side, never larger than a leanback hero tile.
        splashEndFraction: 0.28,
        splashEndMax: 180,
        splashNameFontSize: 18,
        splashStatusFontSize: 12,
        splashNameGap: 14,
        splashStatusGap: 8,
      );
    }
    return const ProfileChooserMetrics._(
      isTv: false,
      titleFontSize: 36,
      subtitleFontSize: 14,
      avatarSize: 112,
      tileWidth: 132,
      tileSpacing: 28,
      sectionGap: 36,
      horizontalPadding: 32,
      verticalPadding: 24,
      splashEndFraction: 0.72,
      splashEndMax: 420,
      splashNameFontSize: 22,
      splashStatusFontSize: 13,
      splashNameGap: 20,
      splashStatusGap: 10,
    );
  }

  double splashEndAvatarSize(double maxSide) {
    final target = math.min(maxSide * splashEndFraction, splashEndMax);
    return math.max(avatarSize, target);
  }
}
