import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Per-profile input and focus behavior.
class ShellInputPolicy {
  const ShellInputPolicy({
    required this.scaleOnHover,
    required this.scaleOnFocus,
    required this.ensureVisibleOnFocus,
    required this.wrapAppFocusTraversal,
    required this.useFocusableMoodChips,
    required this.heroPlayAutoFocus,
  });

  final bool scaleOnHover;
  final bool scaleOnFocus;
  final bool ensureVisibleOnFocus;
  final bool wrapAppFocusTraversal;
  final bool useFocusableMoodChips;
  final bool heroPlayAutoFocus;

  static const mobile = ShellInputPolicy(
    scaleOnHover: false,
    scaleOnFocus: false,
    ensureVisibleOnFocus: false,
    wrapAppFocusTraversal: false,
    useFocusableMoodChips: false,
    heroPlayAutoFocus: false,
  );

  static const desktop = ShellInputPolicy(
    scaleOnHover: true,
    scaleOnFocus: false,
    ensureVisibleOnFocus: false,
    wrapAppFocusTraversal: false,
    useFocusableMoodChips: false,
    heroPlayAutoFocus: false,
  );

  static const tv = ShellInputPolicy(
    scaleOnHover: false,
    scaleOnFocus: true,
    ensureVisibleOnFocus: true,
    wrapAppFocusTraversal: true,
    useFocusableMoodChips: true,
    heroPlayAutoFocus: true,
  );

  bool get isInteractiveActive => scaleOnHover || scaleOnFocus;

  /// Policy-aware hover OR focus — use with [shellFocusableTap] callbacks.
  static bool interactiveActive(
    ShellInputPolicy policy, {
    required bool hovered,
    required bool focused,
  }) =>
      (policy.scaleOnHover && hovered) || (policy.scaleOnFocus && focused);

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
