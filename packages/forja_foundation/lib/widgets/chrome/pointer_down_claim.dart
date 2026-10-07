import 'package:flutter/widgets.dart';

/// Marks a pointer-down as owned by a nested control (e.g. a card's list pin).
///
/// Pointer events reach the deepest [Listener] first. An ancestor that acts on
/// raw pointer-down (desktop mouse-down card open) checks [isClaimed] and
/// skips, so the nested tap owns the click.
class PointerDownClaim extends StatelessWidget {
  const PointerDownClaim({super.key, required this.child});

  final Widget child;

  static final Set<int> _claimed = <int>{};

  /// True when a nested [PointerDownClaim] took this pointer's current press.
  static bool isClaimed(int pointer) => _claimed.contains(pointer);

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) => _claimed.add(e.pointer),
      onPointerUp: (e) => _release(e.pointer),
      onPointerCancel: (e) => _release(e.pointer),
      child: child,
    );
  }

  static void _release(int pointer) {
    // Ancestors see up/cancel after this; release next frame.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _claimed.remove(pointer),
    );
  }
}
