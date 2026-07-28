import 'package:flutter/material.dart';

import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:flutter/services.dart';

/// Tab-scoped TV focus graph — declarative facade over [ShellTvFocusCoordinator].
///
/// Feature screens wrap content in [TvFocusGraph] and use recipes
/// ([TvCatalogRow], [TvChipStrip], [TvHeroActions]) instead of calling
/// `shellTvRegisterRow` / chip edge helpers directly.
class TvFocusGraph extends InheritedWidget {
  const TvFocusGraph({
    super.key,
    required this.tabId,
    required super.child,
  });

  final String tabId;

  static TvFocusGraph? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TvFocusGraph>();

  static TvFocusGraph of(BuildContext context) {
    final graph = maybeOf(context);
    assert(
      graph != null,
      'TvFocusGraph.of() called with no TvFocusGraph ancestor',
    );
    return graph!;
  }

  static String tabIdOf(BuildContext context, {String? fallback}) {
    return maybeOf(context)?.tabId ??
        fallback ??
        ShellTvFocus.currentNavTabId ??
        'home';
  }

  void registerRow({
    required String rowId,
    required int sortOrder,
    required int itemCount,
    VoidCallback? onFocusUp,
    VoidCallback? onFocusDown,
    ShellTvRowOrientation orientation = ShellTvRowOrientation.horizontal,
  }) {
    shellTvRegisterRow(
      tabId: tabId,
      rowId: rowId,
      sortOrder: sortOrder,
      itemCount: itemCount,
      onFocusUp: onFocusUp,
      onFocusDown: onFocusDown,
      orientation: orientation,
    );
  }

  void unregisterRow(String rowId) {
    shellTvUnregisterRow(tabId: tabId, rowId: rowId);
  }

  void updateRowCount({required String rowId, required int itemCount}) {
    shellTvUpdateRowCount(tabId: tabId, rowId: rowId, itemCount: itemCount);
  }

  @override
  bool updateShouldNotify(TvFocusGraph oldWidget) => tabId != oldWidget.tabId;
}

/// Thin bind for hero / tab default focus (Play autofocus, hero reveal).
abstract final class TvHeroActions {
  static void bind(
    String tabId, {
    FocusNode? Function()? defaultFocus,
    VoidCallback? heroReveal,
    VoidCallback? enterFromNavFocus,
    bool Function()? restoreFocus,
    bool Function()? pageBack,
  }) {
    ShellTvFocusCoordinator.registerTabDefaults(
      tabId,
      defaultFocus: defaultFocus,
      heroReveal: heroReveal,
      enterFromNavFocus: enterFromNavFocus,
      restoreFocus: restoreFocus,
      pageBack: pageBack,
    );
  }

  static void unbind(String tabId) {
    ShellTvFocusCoordinator.unregisterTabDefaults(tabId);
  }
}

/// Provides [tabId] / [rowId] to descendants built inside a catalog row.
class TvCatalogRowScope extends InheritedWidget {
  const TvCatalogRowScope({
    super.key,
    required this.tabId,
    required this.rowId,
    required super.child,
  });

  final String tabId;
  final String rowId;

  static TvCatalogRowScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TvCatalogRowScope>();

  @override
  bool updateShouldNotify(TvCatalogRowScope oldWidget) =>
      tabId != oldWidget.tabId || rowId != oldWidget.rowId;
}

bool tvFocusGraphShouldRegister(BuildContext context) {
  final policy = ShellScope.maybeOf(context)?.inputPolicy;
  return policy?.useFocusableMoodChips ??
      resolveShellProfile(context) == ShellProfile.tv;
}

/// Owns coordinator row register/unregister for a horizontal (or vertical) catalog row.
class TvCatalogRow extends StatefulWidget {
  const TvCatalogRow({
    super.key,
    required this.rowId,
    required this.sortOrder,
    required this.itemCount,
    required this.child,
    this.tabId,
    this.onFocusUp,
    this.onFocusDown,
    this.orientation = ShellTvRowOrientation.horizontal,
    this.registerWhen = tvFocusGraphShouldRegister,
  });

  final String? tabId;
  final String rowId;
  final int sortOrder;
  final int itemCount;
  final VoidCallback? onFocusUp;
  final VoidCallback? onFocusDown;
  final ShellTvRowOrientation orientation;
  final bool Function(BuildContext context) registerWhen;
  final Widget child;

  @override
  State<TvCatalogRow> createState() => _TvCatalogRowState();
}

class _TvCatalogRowState extends State<TvCatalogRow> {
  String? _registeredTabId;
  String? _registeredRowId;

  String get _tabId =>
      widget.tabId ?? TvFocusGraph.tabIdOf(context, fallback: 'home');

  bool get _shouldRegister =>
      widget.itemCount > 0 && widget.registerWhen(context);

  void _syncRegistration() {
    if (!_shouldRegister) {
      _unregisterIfNeeded();
      return;
    }
    final tabId = _tabId;
    final graph = TvFocusGraph.maybeOf(context);
    if (graph != null) {
      graph.registerRow(
        rowId: widget.rowId,
        sortOrder: widget.sortOrder,
        itemCount: widget.itemCount,
        onFocusUp: widget.onFocusUp,
        onFocusDown: widget.onFocusDown,
        orientation: widget.orientation,
      );
    } else {
      shellTvRegisterRow(
        tabId: tabId,
        rowId: widget.rowId,
        sortOrder: widget.sortOrder,
        itemCount: widget.itemCount,
        onFocusUp: widget.onFocusUp,
        onFocusDown: widget.onFocusDown,
        orientation: widget.orientation,
      );
    }
    _registeredTabId = tabId;
    _registeredRowId = widget.rowId;
  }

  void _unregisterIfNeeded() {
    final tabId = _registeredTabId;
    final rowId = _registeredRowId;
    if (tabId == null || rowId == null) return;
    shellTvUnregisterRow(tabId: tabId, rowId: rowId);
    _registeredTabId = null;
    _registeredRowId = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncRegistration();
  }

  @override
  void didUpdateWidget(TvCatalogRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rowId != widget.rowId ||
        oldWidget.tabId != widget.tabId ||
        (_registeredRowId != null && _registeredRowId != widget.rowId)) {
      _unregisterIfNeeded();
    }
    _syncRegistration();
  }

  @override
  void dispose() {
    _unregisterIfNeeded();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TvCatalogRowScope(
      tabId: _tabId,
      rowId: widget.rowId,
      child: widget.child,
    );
  }
}

/// Edge callbacks for a chip in a [TvChipStrip].
class TvChipEdges {
  const TvChipEdges({
    required this.onLeft,
    required this.onRight,
    required this.onUp,
    required this.onDown,
    required this.onSelectAlreadySelected,
  });

  final VoidCallback? onLeft;
  final VoidCallback? onRight;
  final VoidCallback onUp;
  final VoidCallback onDown;
  final VoidCallback onSelectAlreadySelected;
}

/// Chip-strip recipe: registers the strip row and builds chip edge handlers.
class TvChipStrip extends StatefulWidget {
  const TvChipStrip({
    super.key,
    required this.rowId,
    required this.sortOrder,
    required this.itemCount,
    required this.resultsRowId,
    required this.builder,
    this.tabId,
    this.registerWhen = tvFocusGraphShouldRegister,
  });

  final String? tabId;
  final String rowId;
  final int sortOrder;
  final int itemCount;
  final String resultsRowId;
  final bool Function(BuildContext context) registerWhen;

  /// Builds the strip UI; use [edgesFor] for each chip index.
  final Widget Function(
    BuildContext context,
    TvChipEdges Function(int index) edgesFor,
  ) builder;

  @override
  State<TvChipStrip> createState() => _TvChipStripState();
}

class _TvChipStripState extends State<TvChipStrip> {
  String? _registeredTabId;
  String? _registeredRowId;

  String get _tabId =>
      widget.tabId ?? TvFocusGraph.tabIdOf(context, fallback: 'home');

  bool get _shouldRegister =>
      widget.itemCount > 0 && widget.registerWhen(context);

  TvChipEdges _edgesFor(int index) {
    final tabId = _tabId;
    return TvChipEdges(
      onLeft: shellTvChipLeftEdge(
        context,
        tabId: tabId,
        rowId: widget.rowId,
        index: index,
      ),
      onRight: shellTvChipRightEdge(
        tabId: tabId,
        rowId: widget.rowId,
        index: index,
        itemCount: widget.itemCount,
      ),
      onUp: () {
        ShellTvFocusCoordinator.moveVerticalInTab(
          tabId: tabId,
          rowId: widget.rowId,
          currentIndex: index,
          down: false,
        );
      },
      onDown: shellTvChipDownToRow(
        tabId: tabId,
        chipRowId: widget.rowId,
        resultsRowId: widget.resultsRowId,
      ),
      onSelectAlreadySelected: () {
        ShellTvFocusCoordinator.focusFromChipStripDown(
          tabId: tabId,
          chipRowId: widget.rowId,
          resultsRowId: widget.resultsRowId,
        );
      },
    );
  }

  void _syncRegistration() {
    if (!_shouldRegister) {
      _unregisterIfNeeded();
      return;
    }
    final tabId = _tabId;
    shellTvRegisterRow(
      tabId: tabId,
      rowId: widget.rowId,
      sortOrder: widget.sortOrder,
      itemCount: widget.itemCount,
    );
    _registeredTabId = tabId;
    _registeredRowId = widget.rowId;
  }

  void _unregisterIfNeeded() {
    final tabId = _registeredTabId;
    final rowId = _registeredRowId;
    if (tabId == null || rowId == null) return;
    shellTvUnregisterRow(tabId: tabId, rowId: rowId);
    _registeredTabId = null;
    _registeredRowId = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncRegistration();
  }

  @override
  void didUpdateWidget(TvChipStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rowId != widget.rowId || oldWidget.tabId != widget.tabId) {
      _unregisterIfNeeded();
    }
    _syncRegistration();
  }

  @override
  void dispose() {
    _unregisterIfNeeded();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TvCatalogRowScope(
      tabId: _tabId,
      rowId: widget.rowId,
      child: widget.builder(context, _edgesFor),
    );
  }
}

/// UP from a results row under a chip strip → last focused chip.
VoidCallback tvResultsUpToChips(
  BuildContext context, {
  String chipRowId = 'mood-chips',
}) {
  final tabId = TvFocusGraph.tabIdOf(context, fallback: 'home');
  return shellTvResultsUpToChips(tabId: tabId, chipRowId: chipRowId);
}

/// Provides grid meta to descendants inside a [TvGrid].
class TvGridScope extends InheritedWidget {
  const TvGridScope({
    super.key,
    required this.tabId,
    required this.rowId,
    required this.columns,
    required super.child,
  });

  final String tabId;
  final String rowId;
  final int columns;

  static TvGridScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TvGridScope>();

  /// Args for [shellFocusableTap] on a grid cell.
  ({
    String tvTabId,
    String tvRowId,
    ShellTvZone tvZone,
    int gridIndex,
    int gridColumns,
    int tvItemIndex,
  }) metaFor(int index) => (
        tvTabId: tabId,
        tvRowId: rowId,
        tvZone: ShellTvZone.grid,
        gridIndex: index,
        gridColumns: columns,
        tvItemIndex: index,
      );

  @override
  bool updateShouldNotify(TvGridScope oldWidget) =>
      tabId != oldWidget.tabId ||
      rowId != oldWidget.rowId ||
      columns != oldWidget.columns;
}

/// Owns coordinator registration for a multi-column results grid (`ShellTvZone.grid`).
///
/// Interior D-pad moves use [ShellTvFocusCoordinator.moveInGrid] via cell meta;
/// first-column Left / first-row Up stay as optional per-cell edge overrides.
class TvGrid extends StatefulWidget {
  const TvGrid({
    super.key,
    required this.rowId,
    required this.sortOrder,
    required this.itemCount,
    required this.columns,
    required this.child,
    this.tabId,
    this.onFocusUp,
    this.onFocusDown,
    this.registerWhen = tvFocusGraphShouldRegister,
  });

  final String? tabId;
  final String rowId;
  final int sortOrder;
  final int itemCount;
  final int columns;
  final VoidCallback? onFocusUp;
  final VoidCallback? onFocusDown;
  final bool Function(BuildContext context) registerWhen;
  final Widget child;

  static bool focusItem(
    BuildContext context,
    int index, {
    String? tabId,
    String? rowId,
  }) {
    final scope = TvGridScope.maybeOf(context);
    final tid = tabId ?? scope?.tabId ?? TvFocusGraph.tabIdOf(context);
    final rid = rowId ?? scope?.rowId ?? 'results';
    return ShellTvFocusCoordinator.focusRowItem(tid, rid, index);
  }

  @override
  State<TvGrid> createState() => _TvGridState();
}

class _TvGridState extends State<TvGrid> {
  String? _registeredTabId;
  String? _registeredRowId;

  String get _tabId =>
      widget.tabId ?? TvFocusGraph.tabIdOf(context, fallback: 'search');

  bool get _shouldRegister =>
      widget.itemCount > 0 &&
      widget.columns > 0 &&
      widget.registerWhen(context);

  void _syncRegistration() {
    if (!_shouldRegister) {
      _unregisterIfNeeded();
      return;
    }
    final tabId = _tabId;
    final graph = TvFocusGraph.maybeOf(context);
    if (graph != null) {
      graph.registerRow(
        rowId: widget.rowId,
        sortOrder: widget.sortOrder,
        itemCount: widget.itemCount,
        onFocusUp: widget.onFocusUp,
        onFocusDown: widget.onFocusDown,
      );
    } else {
      shellTvRegisterRow(
        tabId: tabId,
        rowId: widget.rowId,
        sortOrder: widget.sortOrder,
        itemCount: widget.itemCount,
        onFocusUp: widget.onFocusUp,
        onFocusDown: widget.onFocusDown,
      );
    }
    _registeredTabId = tabId;
    _registeredRowId = widget.rowId;
  }

  void _unregisterIfNeeded() {
    final tabId = _registeredTabId;
    final rowId = _registeredRowId;
    if (tabId == null || rowId == null) return;
    shellTvUnregisterRow(tabId: tabId, rowId: rowId);
    _registeredTabId = null;
    _registeredRowId = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncRegistration();
  }

  @override
  void didUpdateWidget(TvGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rowId != widget.rowId ||
        oldWidget.tabId != widget.tabId ||
        (_registeredRowId != null && _registeredRowId != widget.rowId)) {
      _unregisterIfNeeded();
    }
    _syncRegistration();
  }

  @override
  void dispose() {
    _unregisterIfNeeded();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TvGridScope(
      tabId: _tabId,
      rowId: widget.rowId,
      columns: widget.columns,
      child: widget.child,
    );
  }
}

/// Overlay D-pad host for player menus / sources / dialogs.
///
/// FocusScope traps arrows inside the overlay (not player chrome), marks the
/// subtree for linear ↑← / ↓→, and focuses the first control on open.
/// [PlayerTvKeyScope] stays separate — chrome-hidden seek is not this recipe.
///
/// Keep [debugLabel] as `player-tv-menu` so [playerTvChromeHasFocus] still
/// treats the overlay as chrome.
class TvOverlayScope extends StatelessWidget {
  const TvOverlayScope({
    super.key,
    required this.child,
    this.onDismiss,
    this.autofocusFirst = true,
    this.debugLabel = 'player-tv-menu',
    this.policy,
    this.enabled,
  });

  final Widget child;
  final VoidCallback? onDismiss;
  final bool autofocusFirst;
  final String debugLabel;
  final FocusTraversalPolicy? policy;

  /// When null, enables only under TV input policy.
  final bool? enabled;

  static bool _isTv(BuildContext context) {
    final policy = ShellScope.maybeOf(context)?.inputPolicy;
    return policy?.useFocusableMoodChips ??
        resolveShellProfile(context) == ShellProfile.tv;
  }

  @override
  Widget build(BuildContext context) {
    final active = enabled ?? _isTv(context);
    if (!active) return child;

    return FocusScope(
      debugLabel: debugLabel,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (onDismiss == null) return KeyEventResult.ignored;
        if (!shellTvIsNavigationKey(event)) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.escape ||
            key == LogicalKeyboardKey.goBack) {
          onDismiss!();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: ShellTvLinearFocusScope(
        child: FocusTraversalGroup(
          policy: policy ?? ReadingOrderTraversalPolicy(),
          child: autofocusFirst
              ? _TvOverlayFocusOnOpen(child: child)
              : child,
        ),
      ),
    );
  }
}

class _TvOverlayFocusOnOpen extends StatefulWidget {
  const _TvOverlayFocusOnOpen({required this.child});

  final Widget child;

  @override
  State<_TvOverlayFocusOnOpen> createState() => _TvOverlayFocusOnOpenState();
}

class _TvOverlayFocusOnOpenState extends State<_TvOverlayFocusOnOpen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Episode / subtitle panels own initial focus via ShellTvDisableLinearFocus.
      if (ShellTvDisableLinearFocus.activeOf(context)) return;
      final scope = FocusScope.of(context);
      if (scope.focusedChild != null) return;
      scope.nextFocus();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
