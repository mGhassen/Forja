import 'package:flutter/material.dart';
import 'package:forja/shared/player/in_app_mini/in_app_mini_player_controller.dart';

/// Player route that becomes non-opaque while in-app mini is active so the
/// shell under the route receives hits and paints through.
class InAppMiniAwarePageRoute<T> extends PageRoute<T> {
  InAppMiniAwarePageRoute({
    required this.builder,
    super.settings,
    Duration transitionDuration = const Duration(milliseconds: 350),
    Duration reverseTransitionDuration = const Duration(milliseconds: 300),
    this.transitionsBuilder,
    bool fullscreenDialog = false,
  })  : _transitionDuration = transitionDuration,
        _reverseTransitionDuration = reverseTransitionDuration,
        _fullscreenDialog = fullscreenDialog {
    InAppMiniPlayerController.instance.active.addListener(_onMiniChanged);
  }

  final WidgetBuilder builder;
  final RouteTransitionsBuilder? transitionsBuilder;
  final Duration _transitionDuration;
  final Duration _reverseTransitionDuration;
  final bool _fullscreenDialog;

  void _onMiniChanged() {
    if (isActive) {
      changedInternalState();
    }
  }

  @override
  Duration get transitionDuration => _transitionDuration;

  @override
  Duration get reverseTransitionDuration => _reverseTransitionDuration;

  @override
  bool get fullscreenDialog => _fullscreenDialog;

  @override
  bool get opaque => !InAppMiniPlayerController.instance.isActive;

  @override
  bool get barrierDismissible => false;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return builder(context);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final custom = transitionsBuilder;
    if (custom != null) {
      return custom(context, animation, secondaryAnimation, child);
    }
    return child;
  }

  @override
  void dispose() {
    InAppMiniPlayerController.instance.active.removeListener(_onMiniChanged);
    super.dispose();
  }
}
