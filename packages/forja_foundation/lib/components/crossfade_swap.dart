import 'package:flutter/material.dart';

/// Crossfade when [child] identity ([key] / [ValueKey]) changes.
///
/// Used for schedule meta, EPG titles, scrape chips — keep [duration] short.
class CrossfadeSwap extends StatelessWidget {
  const CrossfadeSwap({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 250),
    this.switchInCurve = Curves.easeOut,
    this.switchOutCurve = Curves.easeIn,
  });

  final Widget child;
  final Duration duration;
  final Curve switchInCurve;
  final Curve switchOutCurve;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: switchInCurve,
      switchOutCurve: switchOutCurve,
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: child,
    );
  }
}
