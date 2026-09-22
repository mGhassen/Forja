import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_motion_theme.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:flutter/services.dart';

/// TV focus zone tokens for paint widgets (host maps to its coordinator).
enum ShellPaintTvZone { nav, hero, topBar, chipStrip, row, grid, settings }

/// Scroll-into-view mode when a paint widget takes focus.
enum ShellPaintEnsureVisible { off, row, item }

/// Ancestor whose render extent should be scrolled into view instead of the
/// focused chrome alone (e.g. Popular rank digit left of the poster focus ring).
class ShellPaintEnsureVisibleExtent extends InheritedWidget {
  const ShellPaintEnsureVisibleExtent({super.key, required super.child});

  /// Element context for [Scrollable.ensureVisible] — includes siblings outside
  /// focus chrome. Null when no ancestor is mounted.
  static BuildContext? maybeContext(BuildContext context) =>
      context.getElementForInheritedWidgetOfExactType<
          ShellPaintEnsureVisibleExtent>();

  @override
  bool updateShouldNotify(covariant ShellPaintEnsureVisibleExtent oldWidget) =>
      false;
}

/// Row axis for host [TvKitRow] registration (vertical lists vs rails).
enum ShellPaintTvRowAxis { horizontal, vertical }

/// Page/surface tab id for composites that invent private chrome rows.
class ShellPaintTvTabScope extends InheritedWidget {
  const ShellPaintTvTabScope({
    super.key,
    required this.tabId,
    required super.child,
  });

  final String tabId;

  static ShellPaintTvTabScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellPaintTvTabScope>();

  static String? tabIdOf(BuildContext context) {
    final s = maybeOf(context);
    if (s == null) return null;
    final t = s.tabId.trim();
    return t.isEmpty ? null : t;
  }

  @override
  bool updateShouldNotify(ShellPaintTvTabScope old) => tabId != old.tabId;
}

/// Current TV row coordinates. Mounted by [ShellPaintScope.tvRow] / host TvKitRow.
class ShellPaintTvRowScope extends InheritedWidget {
  const ShellPaintTvRowScope({
    super.key,
    required this.tabId,
    required this.rowId,
    required super.child,
  });

  final String tabId;
  final String rowId;

  static ShellPaintTvRowScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellPaintTvRowScope>();

  @override
  bool updateShouldNotify(ShellPaintTvRowScope old) =>
      tabId != old.tabId || rowId != old.rowId;
}

/// Host-provided focus tap (typically wraps app `shellFocusableTap`).
typedef ShellPaintFocusableTap = Widget Function({
  required BuildContext context,
  required Widget child,
  VoidCallback? onTap,
  double borderRadius,
  double scaleOnFocus,
  VoidCallback? onLeftEdge,
  VoidCallback? onUpEdge,
  VoidCallback? onDownEdge,
  VoidCallback? onRightEdge,
  ValueChanged<bool>? onFocusChange,
  ValueChanged<bool>? onHoverChange,
  FocusNode? focusNode,
  bool autoFocus,
  int? listIndex,
  bool navLeftAlways,
  int? gridIndex,
  int? gridColumns,
  String? tvTabId,
  String? tvRowId,
  int? tvItemIndex,
  ShellPaintTvZone? tvZone,
  ShellPaintEnsureVisible ensureVisibleMode,
  bool showFocusBorder,
  bool showFocusFill,
  bool showFocusRail,
  bool suppressInkHover,
  bool allowNestedFocus,
  FocusOnKeyEventCallback? onKeyEvent,
});

/// Host TV row registration (typically wraps app `TvKitRow`).
typedef ShellPaintTvRowWrap = Widget Function({
  required String tabId,
  required String rowId,
  required int sortOrder,
  required int itemCount,
  VoidCallback? onFocusUp,
  VoidCallback? onFocusDown,
  ShellPaintTvRowAxis axis,
  required Widget child,
});

/// Host policy + focus injection so foundation paint never imports `package:forja`.
///
/// Mount under the app [ShellScope] (or equivalent) and pass [focusableTap] that
/// delegates to host TV/focus chrome.
class ShellPaintScope extends InheritedWidget {
  const ShellPaintScope({
    super.key,
    required this.useTvFocus,
    required this.scaleOnHover,
    required this.focusStyled,
    required this.usesTvDensity,
    this.focusableTapBuilder,
    this.wrapTvRow,
    this.wrapHorizontalScroller,
    this.absorbHorizontalScroll,
    this.isActivateKey,
    required super.child,
  });

  final bool useTvFocus;
  final bool scaleOnHover;
  final bool Function(BuildContext context, {required bool focused}) focusStyled;
  final bool usesTvDensity;
  final ShellPaintFocusableTap? focusableTapBuilder;
  final ShellPaintTvRowWrap? wrapTvRow;

  /// Optional host wrap (e.g. desktop swipe-back ignore).
  final Widget Function(Widget child)? wrapHorizontalScroller;

  final bool Function(ScrollNotification notification)? absorbHorizontalScroll;

  final bool Function(KeyEvent event)? isActivateKey;

  static ShellPaintScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellPaintScope>();

  static ShellPaintScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'ShellPaintScope not found in context');
    return scope!;
  }

  /// Defaults when no host scope is mounted (gallery / tests).
  static bool useTvFocusOf(BuildContext context) =>
      maybeOf(context)?.useTvFocus ?? false;

  static bool scaleOnHoverOf(BuildContext context) =>
      maybeOf(context)?.scaleOnHover ?? true;

  static bool focusStyledOf(
    BuildContext context, {
    required bool focused,
  }) {
    final scope = maybeOf(context);
    if (scope == null) return focused;
    return scope.focusStyled(context, focused: focused);
  }

  static bool usesTvDensityOf(BuildContext context) =>
      maybeOf(context)?.usesTvDensity ?? false;

  /// Desktop icon px → leanback via [ShellTokens.iconSizeFor].
  static double iconOf(BuildContext context, [double desktop = ShellTokens.iconSize]) =>
      ShellTokens.iconSizeFor(desktop, tv: usesTvDensityOf(context));

  static bool interactiveActive(
    BuildContext context, {
    required bool hovered,
    required bool focused,
  }) {
    final scope = maybeOf(context);
    if (scope == null) return hovered || focused;
    if (scope.useTvFocus) {
      return scope.focusStyled(context, focused: focused) || hovered;
    }
    return hovered;
  }

  static Widget focusableTap({
    required BuildContext context,
    required Widget child,
    VoidCallback? onTap,
    double borderRadius = ShellTokens.focusBorderRadius,
    /// Prefer [motion]; raw scale kept for host call sites during migration.
    double? scaleOnFocus,
    ForjaMotionPreset? motion,
    VoidCallback? onLeftEdge,
    VoidCallback? onUpEdge,
    VoidCallback? onDownEdge,
    VoidCallback? onRightEdge,
    ValueChanged<bool>? onFocusChange,
    ValueChanged<bool>? onHoverChange,
    FocusNode? focusNode,
    bool autoFocus = false,
    int? listIndex,
    bool navLeftAlways = false,
    int? gridIndex,
    int? gridColumns,
    String? tvTabId,
    String? tvRowId,
    int? tvItemIndex,
    ShellPaintTvZone? tvZone,
    ShellPaintEnsureVisible ensureVisibleMode = ShellPaintEnsureVisible.row,
    bool showFocusBorder = false,
    bool showFocusFill = false,
    bool showFocusRail = false,
    bool suppressInkHover = false,
    bool allowNestedFocus = false,
    FocusOnKeyEventCallback? onKeyEvent,
  }) {
    final resolvedScale = scaleOnFocus ??
        (motion != null
            ? ForjaMotionTheme.of(context).resolve(motion).focusScale
            : ForjaMotionTheme.of(context)
                .resolve(ForjaMotionPreset.chipLift)
                .focusScale);
    final rowScope = ShellPaintTvRowScope.maybeOf(context);
    final resolvedTab =
        (tvTabId ?? rowScope?.tabId ?? ShellPaintTvTabScope.tabIdOf(context))
            ?.trim();
    final resolvedRow = (tvRowId ?? rowScope?.rowId)?.trim();
    final scope = maybeOf(context);
    final tap = scope?.focusableTapBuilder;
    if (tap != null) {
      return tap(
        context: context,
        child: child,
        onTap: onTap,
        borderRadius: borderRadius,
        scaleOnFocus: resolvedScale,
        onLeftEdge: onLeftEdge,
        onUpEdge: onUpEdge,
        onDownEdge: onDownEdge,
        onRightEdge: onRightEdge,
        onFocusChange: onFocusChange,
        onHoverChange: onHoverChange,
        focusNode: focusNode,
        autoFocus: autoFocus,
        listIndex: listIndex,
        navLeftAlways: navLeftAlways,
        gridIndex: gridIndex,
        gridColumns: gridColumns,
        tvTabId: (resolvedTab == null || resolvedTab.isEmpty) ? null : resolvedTab,
        tvRowId: (resolvedRow == null || resolvedRow.isEmpty) ? null : resolvedRow,
        tvItemIndex: tvItemIndex,
        tvZone: tvZone,
        ensureVisibleMode: ensureVisibleMode,
        showFocusBorder: showFocusBorder,
        showFocusFill: showFocusFill,
        showFocusRail: showFocusRail,
        suppressInkHover: suppressInkHover,
        allowNestedFocus: allowNestedFocus,
        onKeyEvent: onKeyEvent,
      );
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        focusNode: focusNode,
        autofocus: autoFocus,
        borderRadius: BorderRadius.circular(borderRadius),
        onFocusChange: onFocusChange,
        onHover: onHoverChange == null
            ? null
            : (v) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  onHoverChange(v);
                });
              },
        child: child,
      ),
    );
  }

  static bool isActivateKeyOf(BuildContext context, KeyEvent event) {
    final check = maybeOf(context)?.isActivateKey;
    if (check != null) return check(event);
    if (event is! KeyDownEvent) return false;
    final key = event.logicalKey;
    return key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space;
  }

  static Widget tvRow({
    required BuildContext context,
    required String tabId,
    required String rowId,
    required int sortOrder,
    required int itemCount,
    VoidCallback? onFocusUp,
    VoidCallback? onFocusDown,
    ShellPaintTvRowAxis axis = ShellPaintTvRowAxis.horizontal,
    required Widget child,
  }) {
    final scoped = ShellPaintTvRowScope(
      tabId: tabId,
      rowId: rowId,
      child: child,
    );
    final wrap = maybeOf(context)?.wrapTvRow;
    if (wrap == null) return scoped;
    return wrap(
      tabId: tabId,
      rowId: rowId,
      sortOrder: sortOrder,
      itemCount: itemCount,
      onFocusUp: onFocusUp,
      onFocusDown: onFocusDown,
      axis: axis,
      child: scoped,
    );
  }

  @override
  bool updateShouldNotify(ShellPaintScope oldWidget) =>
      useTvFocus != oldWidget.useTvFocus ||
      scaleOnHover != oldWidget.scaleOnHover ||
      usesTvDensity != oldWidget.usesTvDensity ||
      focusableTapBuilder != oldWidget.focusableTapBuilder ||
      wrapTvRow != oldWidget.wrapTvRow;
}
