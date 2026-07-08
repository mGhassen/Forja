import 'package:flutter/material.dart';
import 'package:forja/shell/shell_bus.dart';

/// Navigator layered over [ShellBody] — media details and other in-shell routes.
final GlobalKey<NavigatorState> shellOverlayNavigatorKey =
    GlobalKey<NavigatorState>();

class _ShellOverlayObserver extends NavigatorObserver {
  _ShellOverlayObserver(this.onStackChanged);

  final VoidCallback onStackChanged;

  void _notify() => onStackChanged();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _notify();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _notify();

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _notify();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _notify();
}

/// Transparent root route so tab content stays interactive until a page is pushed.
class ShellOverlayNavigator extends StatefulWidget {
  const ShellOverlayNavigator({super.key});

  @override
  State<ShellOverlayNavigator> createState() => _ShellOverlayNavigatorState();
}

class _ShellOverlayNavigatorState extends State<ShellOverlayNavigator> {
  late final _ShellOverlayObserver _observer;
  bool _overlayHasPage = false;

  @override
  void initState() {
    super.initState();
    _observer = _ShellOverlayObserver(_syncOverlayStack);
  }

  void _syncOverlayStack() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final hasPage = shellOverlayNavigatorKey.currentState?.canPop() ?? false;
      if (hasPage != ShellBus.shellOverlayHasPage.value) {
        ShellBus.shellOverlayHasPage.value = hasPage;
        ShellBus.notifyShellChromeChanged();
      }
      if (hasPage == _overlayHasPage) return;
      setState(() => _overlayHasPage = hasPage);
    });
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !_overlayHasPage,
      child: Navigator(
        key: shellOverlayNavigatorKey,
        observers: [_observer],
        onGenerateInitialRoutes: (NavigatorState navigator, String initialRoute) {
          return [
            PageRouteBuilder<void>(
              settings: const RouteSettings(name: '/'),
              opaque: false,
              barrierDismissible: false,
              pageBuilder: (context, animation, secondaryAnimation) {
                return const SizedBox.expand();
              },
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
          ];
        },
      ),
    );
  }
}

/// Push [route] on the shell overlay when available; otherwise fall back to [context].
Future<T?> pushShellRoute<T>(BuildContext context, Route<T> route) {
  final overlay = shellOverlayNavigatorKey.currentState;
  if (overlay != null) {
    return overlay.push(route);
  }
  return Navigator.of(context).push(route);
}

Future<T?> pushReplacementShellRoute<T, TO>(
  BuildContext context,
  Route<T> route, {
  TO? result,
}) {
  final overlay = shellOverlayNavigatorKey.currentState;
  if (overlay != null) {
    return overlay.pushReplacement(route, result: result);
  }
  return Navigator.of(context).pushReplacement(route, result: result);
}

bool shellOverlayCanPop() {
  final overlay = shellOverlayNavigatorKey.currentState;
  return overlay?.canPop() ?? false;
}

void maybePopShellOverlay<T extends Object?>([T? result]) {
  final overlay = shellOverlayNavigatorKey.currentState;
  if (overlay?.canPop() ?? false) {
    overlay!.maybePop(result);
  }
}

void popShellOverlayUntilRoot() {
  final overlay = shellOverlayNavigatorKey.currentState;
  if (overlay == null || !overlay.canPop()) return;
  overlay.popUntil((route) => route.isFirst);
}
