import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Per-profile input and focus behavior.
class ShellInputPolicy {
  const ShellInputPolicy({
    required this.showFocusRing,
    required this.scaleOnHover,
    required this.scaleOnFocus,
    required this.ensureVisibleOnFocus,
    required this.wrapAppFocusTraversal,
    required this.useFocusableMoodChips,
    required this.heroPlayAutoFocus,
  });

  final bool showFocusRing;
  final bool scaleOnHover;
  final bool scaleOnFocus;
  final bool ensureVisibleOnFocus;
  final bool wrapAppFocusTraversal;
  final bool useFocusableMoodChips;
  final bool heroPlayAutoFocus;

  static const mobile = ShellInputPolicy(
    showFocusRing: false,
    scaleOnHover: false,
    scaleOnFocus: false,
    ensureVisibleOnFocus: false,
    wrapAppFocusTraversal: false,
    useFocusableMoodChips: false,
    heroPlayAutoFocus: false,
  );

  static const desktop = ShellInputPolicy(
    showFocusRing: false,
    scaleOnHover: true,
    scaleOnFocus: false,
    ensureVisibleOnFocus: false,
    wrapAppFocusTraversal: false,
    useFocusableMoodChips: false,
    heroPlayAutoFocus: false,
  );

  static const tv = ShellInputPolicy(
    showFocusRing: true,
    scaleOnHover: false,
    scaleOnFocus: true,
    ensureVisibleOnFocus: true,
    wrapAppFocusTraversal: true,
    useFocusableMoodChips: true,
    heroPlayAutoFocus: true,
  );

  bool get isInteractiveActive => scaleOnHover || scaleOnFocus;

  Decoration? focusRingDecoration({required double borderRadius}) {
    if (!showFocusRing) return null;
    return BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: Colors.white, width: 3),
    );
  }

  /// App-root D-pad traversal — TV only.
  static Widget maybeWrapFocusTraversal({required Widget child, required bool enabled}) {
    if (!enabled) return child;
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.arrowUp):
            DirectionalFocusIntent(TraversalDirection.up),
        SingleActivator(LogicalKeyboardKey.arrowDown):
            DirectionalFocusIntent(TraversalDirection.down),
        SingleActivator(LogicalKeyboardKey.arrowLeft):
            DirectionalFocusIntent(TraversalDirection.left),
        SingleActivator(LogicalKeyboardKey.arrowRight):
            DirectionalFocusIntent(TraversalDirection.right),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          DirectionalFocusIntent: DirectionalFocusAction(),
        },
        child: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: child,
        ),
      ),
    );
  }
}
