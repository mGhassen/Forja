import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';

/// Isolated TV focus graph for details + in-player Sources (and torrent files).
abstract final class SourcesPanelTv {
  static const tabId = 'sources-panel';
  static const kindRowId = 'sources-kind';
  static const providersRowId = 'sources-providers';
  static const listRowId = 'sources-list';
  static const kindSort = 0;
  static const providersSort = 1;
  static const listSort = 2;

  static bool isTv(BuildContext context) {
    final policy = ShellScope.maybeOf(context)?.inputPolicy;
    return policy?.useFocusableMoodChips ??
        resolveShellProfile(context) == ShellProfile.tv;
  }

  /// Claim a registered list tile (retries until [ListView] builds the node).
  static void focusListItem({
    int index = 0,
    int maxTries = 12,
  }) {
    var tries = 0;
    void attempt() {
      final node = ShellTvFocusCoordinator.itemNode(tabId, listRowId, index);
      if (node != null && node.canRequestFocus) {
        node.requestFocus();
        return;
      }
      if (tries++ < maxTries) {
        WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
      } else {
        focusKindItem();
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
  }

  static void focusKindItem({int index = 0}) {
    final node = ShellTvFocusCoordinator.itemNode(tabId, kindRowId, index);
    if (node != null && node.canRequestFocus) {
      node.requestFocus();
      return;
    }
    final providers =
        ShellTvFocusCoordinator.itemNode(tabId, providersRowId, 0);
    if (providers != null && providers.canRequestFocus) {
      providers.requestFocus();
    }
  }

  static void focusProvidersItem({int index = 0}) {
    final node = ShellTvFocusCoordinator.itemNode(tabId, providersRowId, index);
    if (node != null && node.canRequestFocus) {
      node.requestFocus();
      return;
    }
    focusKindItem();
  }

  /// Wraps panel body: contain D-pad, spatial (not linear), isolated tab graph.
  ///
  /// Set [includeOverlayScope] false when the host already provides
  /// [TvOverlayScope] (in-player overlays via [playerOverlayShell]).
  static Widget wrapBody({
    required BuildContext context,
    required VoidCallback onClose,
    required Widget child,
    bool autofocusFirst = false,
    bool includeOverlayScope = true,
  }) {
    if (!isTv(context)) return child;
    Widget body = ShellTvDisableLinearFocus(child: child);
    body = TvFocusGraph(tabId: tabId, child: body);
    if (!includeOverlayScope) return body;
    return TvOverlayScope(
      onDismiss: onClose,
      autofocusFirst: autofocusFirst,
      debugLabel: 'sources-panel-tv',
      child: body,
    );
  }
}
