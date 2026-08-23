import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:forja/shared/design/src/shell_keyboard_focus_scope.dart';

/// TV app-root traversal - never use geometry for LEFT/RIGHT (rows trap in widgets).
class _ShellTvDirectionalFocusAction extends DirectionalFocusAction {
  _ShellTvDirectionalFocusAction();

  @override
  Object? invoke(DirectionalFocusIntent intent) {
    if (intent.direction == TraversalDirection.left ||
        intent.direction == TraversalDirection.right) {
      return false;
    }
    super.invoke(intent);
    return null;
  }
}

/// Per-profile input and focus behavior.
class ShellInputPolicy {
  const ShellInputPolicy({
    required this.scaleOnHover,
    required this.scaleOnFocus,
    required this.ensureVisibleOnFocus,
    required this.wrapAppFocusTraversal,
    required this.useFocusableMoodChips,
    required this.heroPlayAutoFocus,
    required this.kenBurnsBackdrop,
  });

  final bool scaleOnHover;
  final bool scaleOnFocus;
  final bool ensureVisibleOnFocus;
  final bool wrapAppFocusTraversal;
  final bool useFocusableMoodChips;
  final bool heroPlayAutoFocus;

  /// Slow pan/zoom on hero backdrops. Off on TV — full-bleed
  /// [Transform.scale] every frame saccades on leanback SoCs.
  final bool kenBurnsBackdrop;

  static const mobile = ShellInputPolicy(
    scaleOnHover: false,
    scaleOnFocus: false,
    ensureVisibleOnFocus: false,
    wrapAppFocusTraversal: false,
    useFocusableMoodChips: false,
    heroPlayAutoFocus: false,
    kenBurnsBackdrop: true,
  );

  /// Desktop: mouse hover + TV D-pad focus graph. Ken Burns on (fine on desktop GPUs).
  static const desktop = ShellInputPolicy(
    scaleOnHover: true,
    scaleOnFocus: true,
    ensureVisibleOnFocus: true,
    wrapAppFocusTraversal: true,
    useFocusableMoodChips: true,
    heroPlayAutoFocus: true,
    kenBurnsBackdrop: true,
  );

  static const tv = ShellInputPolicy(
    scaleOnHover: false,
    scaleOnFocus: true,
    ensureVisibleOnFocus: true,
    wrapAppFocusTraversal: true,
    useFocusableMoodChips: true,
    heroPlayAutoFocus: true,
    kenBurnsBackdrop: false,
  );

  bool get isInteractiveActive => scaleOnHover || scaleOnFocus;

  /// TV leanback: snap focus chrome (no 200ms tweens). Weak SoCs stutter
  /// when every D-pad step runs [AnimatedScale] / color / saturation tweens.
  bool get instantFocusChrome => scaleOnFocus && !scaleOnHover;

  /// Whether [focused] should paint D-pad / keyboard focus chrome.
  bool focusChromeVisible(BuildContext context, {required bool focused}) {
    if (!scaleOnFocus || !focused) return false;
    if (instantFocusChrome) return true;
    return ShellKeyboardFocusScope.chromeVisibleOf(context);
  }

  /// Focus styling on desktop hybrid — ignores mouse/touch focus retention.
  bool focusStyled(BuildContext context, {required bool focused}) =>
      focusChromeVisible(context, focused: focused);

  /// Policy-aware hover OR keyboard focus chrome.
  static bool interactiveActive(
    ShellInputPolicy policy, {
    required bool hovered,
    required bool focused,
    BuildContext? context,
  }) {
    final focusChrome = context != null
        ? policy.focusChromeVisible(context, focused: focused)
        : (policy.scaleOnFocus && focused && policy.instantFocusChrome);
    return (policy.scaleOnHover && hovered) || focusChrome;
  }

  /// App-root D-pad / arrow traversal when [wrapAppFocusTraversal] is on.
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
          DirectionalFocusIntent: _ShellTvDirectionalFocusAction(),
        },
        child: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: child,
        ),
      ),
    );
  }
}
