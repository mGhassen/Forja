import 'package:flutter/material.dart';
import 'package:forja/shared/foundation/primitives/shell/forja_shell_profile.dart';
import 'package:forja/shared/foundation/primitives/shell/forja_shell_scope.dart';
import 'package:forja/shared/foundation/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/foundation/tv/shell_tv_focus.dart';
import 'package:forja/shared/foundation/tv/tv_focus_graph.dart';

/// Isolated TV focus graph for details + in-player Sources (and torrent files).
abstract final class SourcesPanelTv {
  static const tabId = 'sources-panel';
  static const headerRowId = 'sources-header';
  static const kindRowId = 'sources-kind';
  static const providersRowId = 'sources-providers';
  static const listRowId = 'sources-list';
  /// Above kind tabs so ↑ from Providers lands on reload/close.
  static const headerSort = -1;
  static const kindSort = 0;
  static const providersSort = 1;
  static const listSort = 2;

  /// Isolated graph for the Filters side panel (rows = Category / Quality / …).
  static const filtersTabId = 'sources-filters';
  static const filtersHeaderRowId = 'filters-header';

  static bool isTv(BuildContext context) {
    final policy = ShellScope.maybeOf(context)?.inputPolicy;
    return policy?.useFocusableMoodChips ??
        resolveShellProfile(context) == ShellProfile.tv;
  }

  static bool _tryFocus(FocusNode? node) {
    if (node == null) return false;
    try {
      if (!node.canRequestFocus) return false;
    } catch (_) {
      return false;
    }
    final ctx = node.context;
    // Skip disposing tiles from the previous wrapBody remount — treating
    // those as success cancelled retries and left the overlay empty.
    if (ctx == null || !ctx.mounted) return false;
    FocusScope.of(ctx).requestFocus(node);
    return true;
  }

  static bool _tryRow(String rowId, int index, {String? forTabId}) {
    final tid = forTabId ?? tabId;
    if (ShellTvFocusCoordinator.focusRowItem(tid, rowId, index)) return true;
    return _tryFocus(ShellTvFocusCoordinator.itemNode(tid, rowId, index));
  }

  static bool Function()? _dismissFilters;

  static void setFiltersDismiss(bool Function()? dismiss) {
    _dismissFilters = dismiss;
  }

  /// Close Filters if that overlay is up. Does not close Sources.
  static bool dismissFiltersIfOpen() {
    final cb = _dismissFilters;
    if (cb == null) return false;
    return cb();
  }

  /// True when a Sources-panel item node currently has focus.
  static bool get hasItemFocus =>
      ShellTvFocusCoordinator.tabHasAttachedFocus(tabId);

  /// Put D-pad on a panel control. Retries while kind/list nodes mount
  /// (reopen after player, ExcludeFocus lift, lazy ListView).
  ///
  /// When [listIndex] is set, keeps retrying that row (and index 0) before
  /// falling back to kind tabs — off-screen ListView tiles need scroll time.
  static void claimFocus({
    int? listIndex,
    FocusNode? search,
    FocusNode? filters,
    FocusNode? close,
    int maxTries = 20,
    bool listOnly = false,
    String? forTabId,
  }) {
    var tries = 0;
    void attempt() {
      if (listIndex != null &&
          _tryRow(listRowId, listIndex, forTabId: forTabId)) {
        return;
      }
      if (listIndex != null &&
          listIndex != 0 &&
          _tryRow(listRowId, 0, forTabId: forTabId)) {
        return;
      }
      final waitingForList = listIndex != null && tries < maxTries;
      if (waitingForList) {
        tries++;
        WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
        return;
      }
      if (listOnly) return;
      // Prefer kind tabs on open; providers / search are ↓ from there.
      if (_tryRow(kindRowId, 0, forTabId: forTabId)) return;
      if (_tryRow(providersRowId, 0, forTabId: forTabId)) return;
      if (_tryFocus(search)) return;
      if (_tryFocus(filters)) return;
      if (_tryFocus(close)) return;
      if (tries++ < maxTries) {
        WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
      }
    }

    attempt();
  }

  /// Sync try — used by search ↓ before scheduling [focusListItem] retries.
  static bool tryFocusListItem({int index = 0, String? forTabId}) =>
      _tryRow(listRowId, index, forTabId: forTabId);

  /// Claim a registered list tile (retries until [ListView] builds the node).
  ///
  /// Pass [forTabId] when the list lives under another graph (e.g. match
  /// details [MediaDetailsTv.tabId] instead of [SourcesPanelTv.tabId]).
  static void focusListItem({
    int index = 0,
    int maxTries = 20,
    bool listOnly = false,
    String? forTabId,
  }) {
    claimFocus(
      listIndex: index,
      maxTries: maxTries,
      listOnly: listOnly,
      forTabId: forTabId,
    );
  }

  static void focusKindItem({int index = 0, int maxTries = 12}) {
    var tries = 0;
    void attempt() {
      if (_tryRow(kindRowId, index)) return;
      if (tries++ < maxTries) {
        WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
        return;
      }
      _tryRow(providersRowId, 0);
    }

    attempt();
  }

  static void focusHeaderItem({int index = 0, int maxTries = 12}) {
    var tries = 0;
    void attempt() {
      if (_tryRow(headerRowId, index)) return;
      if (tries++ < maxTries) {
        WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
        return;
      }
      focusKindItem();
    }

    attempt();
  }

  static void focusProvidersItem({int index = 0}) {
    if (_tryRow(providersRowId, index)) return;
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
    void dismiss() {
      if (dismissFiltersIfOpen()) return;
      onClose();
    }

    Widget body = ShellTvDisableLinearFocus(child: child);
    body = TvFocusGraph(tabId: tabId, child: body);
    body = _SourcesTvBackBinder(onClose: onClose, child: body);
    if (!includeOverlayScope) return body;
    return TvOverlayScope(
      onDismiss: dismiss,
      autofocusFirst: autofocusFirst,
      debugLabel: 'sources-panel-tv',
      child: body,
    );
  }
}

/// HardwareKeyboard steals goBack before [TvOverlayScope] — register close.
class _SourcesTvBackBinder extends StatefulWidget {
  const _SourcesTvBackBinder({required this.onClose, required this.child});

  final VoidCallback onClose;
  final Widget child;

  @override
  State<_SourcesTvBackBinder> createState() => _SourcesTvBackBinderState();
}

class _SourcesTvBackBinderState extends State<_SourcesTvBackBinder> {
  @override
  void initState() {
    super.initState();
    ShellTvFocusCoordinator.setSourcesPanelDismiss(_dismiss);
  }

  @override
  void dispose() {
    ShellTvFocusCoordinator.setSourcesPanelDismiss(null);
    super.dispose();
  }

  bool _dismiss() {
    if (SourcesPanelTv.dismissFiltersIfOpen()) return true;
    widget.onClose();
    return true;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
