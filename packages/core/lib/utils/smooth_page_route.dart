import 'package:flutter/material.dart';

/// A buttery page transition for navigating to a "details" screen from a
/// poster card. Combines a quick fade with a subtle scale-up + soft slide
/// to feel like the card is unfurling into the next screen — and to mask
/// the unavoidable TMDB / details bootstrap on initState.
///
/// Why not MaterialPageRoute?
///   • MaterialPageRoute on Android slides up + fades, but its short
///     duration makes any heavy initState work look like a stutter.
///   • A 380ms fade + scale gives the destination's first frame enough
///     time to land before the user fully sees it.
class SmoothDetailsRoute<T> extends PageRouteBuilder<T> {
  SmoothDetailsRoute({required WidgetBuilder builder})
      : super(
          opaque: true,
          barrierColor: Colors.black,
          transitionDuration: const Duration(milliseconds: 380),
          reverseTransitionDuration: const Duration(milliseconds: 260),
          pageBuilder: (ctx, anim, secAnim) => builder(ctx),
          transitionsBuilder: (ctx, anim, secAnim, child) {
            final curved = CurvedAnimation(
              parent: anim,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
                child: child,
              ),
            );
          },
        );
}
