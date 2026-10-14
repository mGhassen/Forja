import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/shared/player/in_app_mini/in_app_mini_player_controller.dart';
import 'package:forja/shared/player/platform/pip_service.dart';

/// Player route that becomes non-opaque while in-app mini or desktop PiP float
/// is active so the shell under the route receives hits and paints through.
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
    InAppMiniPlayerController.instance.active.addListener(_onShellThroughChanged);
    _pipSub = PipService.instance.desktopPipChanges.listen((_) {
      _onShellThroughChanged();
    });
  }

  final WidgetBuilder builder;
  final RouteTransitionsBuilder? transitionsBuilder;
  final Duration _transitionDuration;
  final Duration _reverseTransitionDuration;
  final bool _fullscreenDialog;
  StreamSubscription<bool>? _pipSub;

  bool get _shellThrough =>
      InAppMiniPlayerController.instance.isActive ||
      PipService.instance.isDesktopActive;

  void _onShellThroughChanged() {
    if (!isActive) return;
    // TransitionRoute only writes OverlayEntry.opaque on animation
    // completed. Without this, routes under the player stay Theater-
    // skipped after [opaque] flips → full-window black behind chrome.
    if (overlayEntries.isNotEmpty) {
      overlayEntries.first.opaque = opaque;
    }
    changedInternalState();
  }

  @override
  Duration get transitionDuration => _transitionDuration;

  @override
  Duration get reverseTransitionDuration => _reverseTransitionDuration;

  @override
  bool get fullscreenDialog => _fullscreenDialog;

  @override
  bool get opaque => !_shellThrough;

  @override
  bool get barrierDismissible => false;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  /// [ModalRoute] always inserts a barrier. Even with [barrierColor] null it
  /// uses [HitTestBehavior.opaque] and eats every miss under the page — so the
  /// shell never gets clicks while mini/PiP shows only a corner / placeholder.
  @override
  Widget buildModalBarrier() {
    if (_shellThrough) {
      return const SizedBox.shrink();
    }
    return super.buildModalBarrier();
  }

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
    InAppMiniPlayerController.instance.active
        .removeListener(_onShellThroughChanged);
    unawaited(_pipSub?.cancel());
    super.dispose();
  }
}
