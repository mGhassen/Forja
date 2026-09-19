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
    // AnimatedSwitcher defaults to center; labels / section titles need start.
    // Use [layoutBuilder] — older Flutter SDKs have no AnimatedSwitcher.alignment.
    this.alignment = AlignmentDirectional.centerStart,
  });

  final Widget child;
  final Duration duration;
  final Curve switchInCurve;
  final Curve switchOutCurve;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: switchInCurve,
      switchOutCurve: switchOutCurve,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: alignment,
          children: <Widget>[
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: child,
    );
  }
}
