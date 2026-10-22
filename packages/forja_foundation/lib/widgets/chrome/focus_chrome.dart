import 'package:flutter/widgets.dart';
import 'package:forja_foundation/tokens/focus_chrome_tokens.dart';

/// Paint-only leanback focus ring around [child] — the shared
/// [FocusChromeTokens] signature, drawn [inset] outside the child's box so
/// text tabs and icons get a pill / backplate without any layout change.
///
/// [behind] paints the ring + fill under the child (nav rail backplate);
/// default paints it over the child (card ring over the poster).
class FocusChromeRing extends StatelessWidget {
  const FocusChromeRing({
    super.key,
    required this.active,
    required this.child,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
    this.inset = EdgeInsets.zero,
    this.fill,
    this.withGlow = true,
    this.behind = false,
  });

  final bool active;
  final Widget child;
  final BorderRadius? borderRadius;
  final BoxShape shape;
  final EdgeInsets inset;
  final Color? fill;
  final bool withGlow;
  final bool behind;

  @override
  Widget build(BuildContext context) {
    // Tree shape never changes with [active]: the ring slot is always
    // mounted and only its decoration toggles, so the child keeps its State
    // (nav icon animations, resolved pack icons) across focus enter / leave.
    final ring = Positioned(
      left: -inset.left,
      right: -inset.right,
      top: -inset.top,
      bottom: -inset.bottom,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: active
              ? FocusChromeTokens.ring(
                  borderRadius: borderRadius,
                  shape: shape,
                  fill: fill,
                  withGlow: withGlow,
                )
              : const BoxDecoration(),
        ),
      ),
    );
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.passthrough,
      children: behind ? [ring, child] : [child, ring],
    );
  }
}
