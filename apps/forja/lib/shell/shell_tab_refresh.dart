import 'package:flutter/material.dart';

import 'package:forja/shared/design/src/shell_tokens.dart';

/// Tabs that support stale-while-revalidate when re-selected or on app resume.
mixin ShellTabRefresh<T extends StatefulWidget> on State<T> {
  DateTime? _lastShellRefreshAt;

  /// Override per tab when needed.
  Duration get shellStaleAfter => ShellTokens.tabStaleDefault;

  /// Fetch fresh data. Called when stale or [force] is true.
  Future<void> onShellTabRefresh({required bool force});

  /// When true, [MainScreen] skips LRU eviction for this tab (e.g. playback active).
  bool get shellBlocksEviction => false;

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
