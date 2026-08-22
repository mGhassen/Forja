import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/shared/player/controls/player_sources_panel.dart';
import 'package:forja/shared/player/controls/player_torrent_file_panel.dart';
import 'package:forja/shared/telemetry/product_analytics.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:forja/shared/widgets/media_details/sources_panel_tv.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

/// Navigator layered over [ShellBody] - media details and other in-shell routes.
final GlobalKey<NavigatorState> shellOverlayNavigatorKey =
    GlobalKey<NavigatorState>();

class _ShellOverlayObserver extends NavigatorObserver {
  _ShellOverlayObserver(this.onStackChanged);

  final VoidCallback onStackChanged;

  void _notify() => onStackChanged();

  void _notifyAfterDismissed(Route<dynamic> route) {
    if (route is! ModalRoute) {
      _notify();
      return;
    }
    final animation = route.animation;
    if (animation == null || animation.status == AnimationStatus.dismissed) {
      _notify();
      return;
    }
    void listener(AnimationStatus status) {
      if (status == AnimationStatus.dismissed) {
        animation.removeStatusListener(listener);
        _notify();
      }
    }

    animation.addStatusListener(listener);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _notify();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _notifyAfterDismissed(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _notifyAfterDismissed(route);

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
  late final PosthogObserver _posthogObserver;
  bool _overlayHasPage = false;

  @override
  void initState() {
    super.initState();
    _observer = _ShellOverlayObserver(_syncOverlayStack);
    _posthogObserver = PosthogObserver(
      nameExtractor: ProductAnalytics.routeScreenName,
    );
  }

  void _syncOverlayStack() {
    if (!mounted) return;
    // Lift [ExcludeFocus] in the same frame as push/pop so overlay pages can
    // receive focus on first entry (hub search, details, etc.).
    final hasPage = shellOverlayNavigatorKey.currentState?.canPop() ?? false;
    if (hasPage != ShellBus.shellOverlayHasPage.value) {
      ShellBus.shellOverlayHasPage.value = hasPage;
      ShellBus.notifyShellChromeChanged();
    }
    if (hasPage != _overlayHasPage) {
      setState(() => _overlayHasPage = hasPage);
      if (!hasPage) {
        // Hub catalog Sources inserts OverlayEntry into this navigator's
        // Overlay. After pop-to-root, IgnorePointer blocks hits so the panel
        // stays painted and uncancellable — tear it down with the route.
        dismissShellOverlaySourcePanels();
        ShellBus.finishOverlayAndRestoreShellTab();
        final tabId = ShellBus.activeShellTabId ?? ShellTvFocus.currentNavTabId;
        if (tabId != null && tabId.isNotEmpty) {
          unawaited(ProductAnalytics.screenTab(tabId));
        }
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final settled = shellOverlayNavigatorKey.currentState?.canPop() ?? false;
      if (settled != ShellBus.shellOverlayHasPage.value) {
        ShellBus.shellOverlayHasPage.value = settled;
        ShellBus.notifyShellChromeChanged();
      }
      if (settled == _overlayHasPage) return;
      setState(() => _overlayHasPage = settled);
      if (!settled) {
        dismissShellOverlaySourcePanels();
        ShellBus.finishOverlayAndRestoreShellTab();
        final tabId = ShellBus.activeShellTabId ?? ShellTvFocus.currentNavTabId;
        if (tabId != null && tabId.isNotEmpty) {
          unawaited(ProductAnalytics.screenTab(tabId));
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !_overlayHasPage,
      child: ExcludeFocus(
        excluding: !_overlayHasPage,
        child: Navigator(
          key: shellOverlayNavigatorKey,
          observers: [_observer, _posthogObserver],
          onGenerateInitialRoutes:
              (NavigatorState navigator, String initialRoute) {
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
      ),
    );
  }
}

void _noteFirstOverlayPush({String? shellTabId}) {
  final overlay = shellOverlayNavigatorKey.currentState;
  if (overlay == null || overlay.canPop()) return;
  final resolved =
      shellTabId ?? ShellBus.activeShellTabId ?? ShellTvFocus.currentNavTabId;
  ShellBus.noteOverlayPushOrigin(resolved);
  ShellTvFocus.captureOverlayReturnFocus(tabId: resolved);
}

/// Push [route] on the shell overlay when available; otherwise fall back to [context].
///
/// [shellTabId] — hub tab that owns this overlay (`anime`, `asian_drama`, …).
/// When omitted, [ShellBus.activeShellTabId] from [MainScreen] is used.
Future<T?> pushShellRoute<T>(
  BuildContext context,
  Route<T> route, {
  String? shellTabId,
}) {
  final overlay = shellOverlayNavigatorKey.currentState;
  if (overlay != null) {
    _noteFirstOverlayPush(shellTabId: shellTabId);
    return overlay.push(route);
  }
  return Navigator.of(context).push(route);
}

Future<T?> pushReplacementShellRoute<T, TO>(
  BuildContext context,
  Route<T> route, {
  TO? result,
  String? shellTabId,
}) {
  final overlay = shellOverlayNavigatorKey.currentState;
  if (overlay != null) {
    if (!overlay.canPop()) {
      _noteFirstOverlayPush(shellTabId: shellTabId);
    }
    return overlay.pushReplacement(route, result: result);
  }
  return Navigator.of(context).pushReplacement(route, result: result);
}

bool shellOverlayCanPop() {
  final overlay = shellOverlayNavigatorKey.currentState;
  return overlay?.canPop() ?? false;
}

/// Pop the top overlay route. Uses [NavigatorState.pop] (not maybePop) so
/// TV [PopScope] on shell routes cannot swallow intentional dismiss.
void maybePopShellOverlay<T extends Object?>([T? result]) {
  final overlay = shellOverlayNavigatorKey.currentState;
  if (overlay?.canPop() ?? false) {
    overlay!.pop(result);
    if (overlay.canPop()) {
      ShellTvFocus.discardOverlayReturnFocus();
    } else {
      ShellTvFocusCoordinator.unfocusShellNav();
      ShellTvFocus.restoreOverlayReturnFocus();
    }
  }
}

void popShellOverlayUntilRoot() {
  final overlay = shellOverlayNavigatorKey.currentState;
  if (overlay == null || !overlay.canPop()) return;
  ShellBus.clearOverlayShellTabId();
  // Dismiss before pop: IgnorePointer arms as soon as canPop is false, so a
  // leftover Sources OverlayEntry would paint and ignore all close taps.
  dismissShellOverlaySourcePanels();
  overlay.popUntil((route) => route.isFirst);
}

/// Hub details (Asian Drama / Anime) open catalog Sources via
/// [PlayerSourcesPanel] OverlayEntry on this navigator. Nav / back to root
/// must remove it — the entry is not owned by the details route.
void dismissShellOverlaySourcePanels() {
  SourcesPanelTv.dismissFiltersIfOpen();
  if (PlayerSourcesPanel.isShowing) {
    PlayerSourcesPanel.dismiss();
  }
  if (PlayerTorrentFilePanel.isShowing) {
    PlayerTorrentFilePanel.dismiss();
  }
}
