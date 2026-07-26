import 'package:flutter/material.dart';

import 'package:forja/shared/design/src/shell_tokens.dart';

/// Tabs that support stale-while-revalidate when re-selected or on app resume.
///
/// [MainScreen] also drives [shellTabVisible]: when the user leaves a mounted
/// tab, [onShellTabHidden] must cancel / invalidate in-flight tab-scoped work
/// so other tabs are not paying for it (lazy shell — work stays in its space).
mixin ShellTabRefresh<T extends StatefulWidget> on State<T> {
  DateTime? _lastShellRefreshAt;
  bool _shellTabVisible = true;

  /// Whether this tab is the currently selected shell tab.
  ///
  /// Prefer this over [mounted] when deciding to continue background fetches —
  /// keep-alive / [Visibility.maintainState] leaves [mounted] true while hidden.
  bool get shellTabVisible => _shellTabVisible;

  /// Override per tab when needed.
  Duration get shellStaleAfter => ShellTokens.tabStaleDefault;

  /// Fetch fresh data. Called when stale or [force] is true.
  Future<void> onShellTabRefresh({required bool force});

  /// When true, [MainScreen] skips LRU eviction for this tab (e.g. playback active).
  bool get shellBlocksEviction => false;

  /// Called when the user leaves this tab while it stays mounted.
  /// Override to bump generation tokens / cancel timers / drop listeners.
  @mustCallSuper
  void onShellTabHidden() {
    _shellTabVisible = false;
  }

  /// Called when this tab becomes the selected shell tab.
  /// Override to resume deferred work that was paused on hide.
  @mustCallSuper
  void onShellTabShown() {
    _shellTabVisible = true;
  }

  void markShellTabFresh() {
    _lastShellRefreshAt = DateTime.now();
  }

  Future<void> refreshIfStale({bool force = false}) async {
    if (!mounted) return;
    if (!force &&
        _lastShellRefreshAt != null &&
        DateTime.now().difference(_lastShellRefreshAt!) < shellStaleAfter) {
      return;
    }
    await onShellTabRefresh(force: force);
    if (mounted) markShellTabFresh();
  }
}
