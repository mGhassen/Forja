import 'package:flutter/material.dart';

/// Crossfade when [child] identity ([key] / [ValueKey]) changes.
///
/// Used for schedule meta, EPG titles, scrape chips — keep [duration] short.
///
/// Layout stays child-sized ([StackFit.loose]) so a fade never re-parents
/// alignment under a stretched column (AnimatedSwitcher's default Stack would).
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
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          fit: StackFit.loose,
          alignment: AlignmentDirectional.centerStart,
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
