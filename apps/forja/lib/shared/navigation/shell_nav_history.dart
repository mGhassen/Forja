import 'package:flutter/material.dart';

/// One shell-overlay page that can be restored via trackpad / mouse Forward.
class ShellHistoryEntry {
  const ShellHistoryEntry({
    required this.rebuild,
    this.settings,
    this.shellTabId,
  });

  final WidgetBuilder rebuild;
  final RouteSettings? settings;
  final String? shellTabId;
}

/// Browser-style LIFO forward stack for shell overlay routes.
///
/// Player routes are never recorded. New user pushes clear the stack;
/// [reopening] skips that clear so Forward can restore multiple steps.
abstract final class ShellNavHistory {
  static final List<ShellHistoryEntry> _forward = <ShellHistoryEntry>[];
  static bool reopening = false;
  static int _suppressPopRecord = 0;

  static bool get canForward => _forward.isNotEmpty;

  static bool get isSuppressingPopRecord => _suppressPopRecord > 0;

  static void clearForward() => _forward.clear();

  static void pushForward(ShellHistoryEntry entry) {
    if (_suppressPopRecord > 0) return;
    _forward.add(entry);
  }

  static ShellHistoryEntry? popForward() {
    if (_forward.isEmpty) return null;
    return _forward.removeLast();
  }

  /// Wipe overlay without stashing popped pages onto Forward.
  static void runWithoutRecording(VoidCallback fn) {
    _suppressPopRecord++;
    try {
      fn();
    } finally {
      _suppressPopRecord--;
    }
  }

  static void onOverlayPush() {
    if (reopening) return;
    clearForward();
  }

  static void onOverlayPop(ShellHistoryPageRoute<dynamic> route) {
    if (_suppressPopRecord > 0) return;
    pushForward(route.toHistoryEntry());
  }
}

/// Overlay [PageRoute] that keeps a reopen factory for [ShellNavHistory].
class ShellHistoryPageRoute<T> extends PageRouteBuilder<T> {
  ShellHistoryPageRoute({
    required this.rebuild,
    super.settings,
    required super.pageBuilder,
    required super.transitionDuration,
    required super.reverseTransitionDuration,
    required super.transitionsBuilder,
    super.opaque = true,
  });

  /// Page builder without TV back guard — used when reopening.
  final WidgetBuilder rebuild;

  /// Hub tab that owned this overlay when it was first pushed.
  String? shellTabId;

  ShellHistoryEntry toHistoryEntry() => ShellHistoryEntry(
        rebuild: rebuild,
        settings: settings,
        shellTabId: shellTabId,
      );
}

/// Records overlay push/pop for [ShellNavHistory].
class ShellHistoryNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is ShellHistoryPageRoute) {
      ShellNavHistory.onOverlayPush();
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is ShellHistoryPageRoute) {
      ShellNavHistory.onOverlayPop(route);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (ShellNavHistory.reopening) return;
    ShellNavHistory.clearForward();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (ShellNavHistory.isSuppressingPopRecord) return;
    if (route is ShellHistoryPageRoute) {
      ShellNavHistory.clearForward();
    }
  }
}
