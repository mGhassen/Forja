import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja_foundation/blocks/shell/catalog_density.dart';
import 'package:forja_foundation/components/empty.dart';
import 'package:forja_foundation/tokens/forja_motion_theme.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:forja_foundation/widgets/focus/list_letter_jump_scope.dart';
import 'package:forja_foundation/widgets/guide/guide_chrome_style.dart';
import 'package:google_fonts/google_fonts.dart';

/// One category rail row — props only (pack / host supply state).
class CatalogCategoryItem {
  const CatalogCategoryItem({
    required this.id,
    required this.label,
    this.icon,
    this.pinnable = false,
    this.pinned = false,
    this.fixed = false,
  });

  final String id;
  final String label;
  final IconData? icon;
  final bool pinnable;
  final bool pinned;

  /// Synthetic / non-draggable (Favorites, Already watched, All).
  final bool fixed;
}

/// Vertical category rail with hover, pin, and delayed drag-reorder.
///
/// TV: hold OK ~2s reveals pin or enters floating reorder when [canReorder].
/// Hold works on desktop hybrid keyboard too ([ShellPaintScope.useTvFocusOf]).
class CatalogCategoryRail extends StatefulWidget {
  const CatalogCategoryRail({
    super.key,
    required this.items,
    required this.selectedId,
    this.onSelect,
    this.onTogglePin,
    this.onReorder,
    this.canReorder = false,
    this.width,
    this.compact = false,
    this.rowHeight,
    this.fontSize,
    this.iconSize,
    this.rowPadH,
    this.listPadV = ShellTokens.categoryRailListPadV,
    this.pinSlotWidth = ShellTokens.categoryRailPinSlotWidth,
    this.header,
    this.onTvEnterRight,
    this.onTvFocusUp,
    this.onScrollJumpReady,
  });

  final List<CatalogCategoryItem> items;
  final String? selectedId;
  final ValueChanged<String>? onSelect;
  final ValueChanged<String>? onTogglePin;

  /// Movable-slice indices (excludes [CatalogCategoryItem.fixed]).
  /// [newIndex] already accounts for the removed item ([onReorderItem]).
  final void Function(int oldIndex, int newIndex)? onReorder;
  final bool canReorder;

  /// Null → [catalogSideRailWidth] (TV denser).
  final double? width;
  final bool compact;

  /// Row extent override. Null → compact 42 / desktop 46.
  final double? rowHeight;
  final double? fontSize;
  final double? iconSize;

  /// Horizontal row padding (left & right). Null → compact 10/6 / desktop 12/8.
  final double? rowPadH;
  final double listPadV;
  final double pinSlotWidth;

  /// Optional first row above categories (e.g. always-open search field).
  final Widget? header;

  /// TV: → from a category row (after select) — e.g. enter channel catalog.
  final VoidCallback? onTvEnterRight;

  /// TV: ↑ from the first category — e.g. Live/Movies/Series shelf.
  final VoidCallback? onTvFocusUp;

  /// Host registers scroll-into-view for lazy TV focus (jump then focus).
  final ValueChanged<void Function(int index)>? onScrollJumpReady;

  static const double rowExtentDesktop = ShellTokens.categoryRailRowExtent;
  static const double rowExtentCompact =
      ShellTokens.categoryRailRowExtentCompact;

  /// Host Back handlers may call this to dismiss pin / floating chrome.
  static bool tryConsumeBack() => _CatalogCategoryRowState.tryConsumeBack();

  @override
  State<CatalogCategoryRail> createState() => _CatalogCategoryRailState();
}

class _CatalogCategoryRailState extends State<CatalogCategoryRail> {
  String? _floatingId;
  final ScrollController _scroll = ScrollController();
  bool _scrollJumpRegistered = false;
  bool _floatingKeysBound = false;

  /// Swallow the OK KeyUp that ends hold-to-enter (must not drop float).
  bool _swallowFloatingActivateUp = false;

  /// Type-to-jump highlight only — never commits [selectedId] / onSelect.
  String? _jumpHighlightId;

  /// After pin/unpin, follow the row to its new list index (scroll + focus).
  String? _pendingFocusId;

  double _listPadV(BuildContext context) => catalogUsesTvDensity(context)
      ? catalogCategoryRailListPadV(context)
      : widget.listPadV;

  double _rowExtent(BuildContext context) =>
      widget.rowHeight ??
      catalogCategoryRailRowExtent(context, compact: widget.compact);

  List<CatalogCategoryItem> get _fixed => [
    for (final e in widget.items)
      if (e.fixed) e,
  ];

  List<CatalogCategoryItem> get _movable => [
    for (final e in widget.items)
      if (!e.fixed) e,
  ];

  /// Favorites / Already watched stay out of type-to-jump (old IPTV).
  List<CatalogCategoryItem> get _jumpItems => _movable;

  bool get _leanbackOnly =>
      ShellPaintScope.usesTvDensityOf(context) &&
      !ShellPaintScope.scaleOnHoverOf(context);

  bool get _letterJumpEnabled =>
      !_leanbackOnly && _floatingId == null && _jumpItems.isNotEmpty;

  bool get _tvFloatingReorder => _floatingId != null;

  @override
  void initState() {
    super.initState();
    _offerScrollJump();
  }

  @override
  void didUpdateWidget(covariant CatalogCategoryRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onScrollJumpReady != widget.onScrollJumpReady) {
      _scrollJumpRegistered = false;
      _offerScrollJump();
    }
    final canReorder =
        widget.canReorder && widget.onReorder != null && _movable.length > 1;
    if (_tvFloatingReorder && !canReorder) {
      _setFloating(null);
    }
    final pending = _pendingFocusId;
    if (pending != null) {
      final oldIdx = oldWidget.items.indexWhere((e) => e.id == pending);
      final newIdx = widget.items.indexWhere((e) => e.id == pending);
      final oldPinned =
          oldIdx >= 0 ? oldWidget.items[oldIdx].pinned : null;
      final newPinned =
          newIdx >= 0 ? widget.items[newIdx].pinned : null;
      if (newIdx >= 0 && (oldIdx != newIdx || oldPinned != newPinned)) {
        _scheduleScrollAndFocus(pending);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncFloatingKeys();
  }

  void _offerScrollJump() {
    final ready = widget.onScrollJumpReady;
    if (ready == null || _scrollJumpRegistered) return;
    _scrollJumpRegistered = true;
    ready((index) => _scrollToIndex(index));
  }

  @override
  void dispose() {
    _unbindFloatingKeys();
    _scroll.dispose();
    super.dispose();
  }

  void _setFloating(String? categoryId) {
    if (_floatingId == categoryId) return;
    if (categoryId != null) {
      _swallowFloatingActivateUp = true;
    } else {
      _swallowFloatingActivateUp = false;
    }
    setState(() => _floatingId = categoryId);
    _syncFloatingKeys();
  }

  void _bindFloatingKeys() {
    if (_floatingKeysBound) return;
    HardwareKeyboard.instance.addHandler(_onFloatingReorderKey);
    _floatingKeysBound = true;
  }

  void _unbindFloatingKeys() {
    if (!_floatingKeysBound) return;
    HardwareKeyboard.instance.removeHandler(_onFloatingReorderKey);
    _floatingKeysBound = false;
  }

  void _syncFloatingKeys() {
    final want =
        _tvFloatingReorder && ShellPaintScope.useTvFocusOf(context);
    if (want) {
      _bindFloatingKeys();
    } else {
      _unbindFloatingKeys();
    }
  }

  /// Parent owns ↑/↓ while floating — survives focus flicker to neighbors.
  bool _onFloatingReorderKey(KeyEvent event) {
    if (!mounted || !_tvFloatingReorder) return false;
    if (!ShellPaintScope.useTvFocusOf(context)) return false;

    final key = event.logicalKey;
    final up = key == LogicalKeyboardKey.arrowUp;
    final down = key == LogicalKeyboardKey.arrowDown;
    final left = key == LogicalKeyboardKey.arrowLeft;
    final right = key == LogicalKeyboardKey.arrowRight;
    final activate = key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.numpadEnter;
    if (!up && !down && !left && !right && !activate) return false;

    if (activate) {
      if (event is KeyUpEvent) {
        if (_swallowFloatingActivateUp) {
          _swallowFloatingActivateUp = false;
        }
        return true;
      }
      if (event is KeyDownEvent && !_swallowFloatingActivateUp) {
        _setFloating(null);
      }
      return true;
    }
    if (left) {
      if (event is KeyDownEvent) _setFloating(null);
      return true;
    }
    if (right) {
      // Focused row handles → (pin).
      return false;
    }

    // One category per KeyDown / KeyRepeat — never HoldAccel strides.
    if (event is KeyUpEvent) return true;
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      _moveFloating(up ? -1 : 1);
      return true;
    }
    return true;
  }

  int _letterJumpAnchor() {
    final jump = _jumpItems;
    if (jump.isEmpty) return -1;
    final highlight = (_jumpHighlightId ?? '').trim();
    if (highlight.isNotEmpty) {
      final hi = jump.indexWhere((e) => e.id == highlight);
      if (hi >= 0) return hi;
    }
    final selected = (widget.selectedId ?? '').trim();
    if (selected.isEmpty) return -1;
    return jump.indexWhere((e) => e.id == selected);
  }

  void _letterJump(int jumpIndex) {
    final jump = _jumpItems;
    if (jumpIndex < 0 || jumpIndex >= jump.length) return;
    final id = jump[jumpIndex].id;
    final fullIdx = widget.items.indexWhere((e) => e.id == id);
    if (fullIdx < 0) return;
    // Highlight + scroll only — same contract as channel cards. Do not
    // onSelect (that reloads the catalog page).
    setState(() => _jumpHighlightId = id);
    void go() {
      if (!mounted) return;
      _scrollToIndex(fullIdx);
    }

    go();
    WidgetsBinding.instance.addPostFrameCallback((_) => go());
  }

  void _scrollToIndex(int index, {int keepAbove = 1}) {
    if (!_scroll.hasClients || index < 0 || !mounted) return;
    final position = _scroll.position;
    final viewport = position.viewportDimension;
    if (viewport <= 0) return;
    final rowExtent = _rowExtent(context);
    final pad = _listPadV(context);
    final itemTop = pad + index * rowExtent;
    final itemBottom = itemTop + rowExtent;
    final viewTop = position.pixels;
    final viewBottom = viewTop + viewport;
    // Keep-visible only — nudge by the clipped edge so ↑/↓ tracks one row at
    // a time. Always-pin-to-keepAbove jumped the list away from focus.
    double? target;
    if (itemTop < viewTop + keepAbove * rowExtent) {
      target = (itemTop - keepAbove * rowExtent).clamp(
        0.0,
        position.maxScrollExtent,
      );
    } else if (itemBottom > viewBottom - rowExtent * 0.5) {
      target = (itemBottom - viewport + rowExtent * 0.5).clamp(
        0.0,
        position.maxScrollExtent,
      );
    } else {
      return;
    }
    if ((position.pixels - target).abs() < 0.5) return;
    _scroll.jumpTo(target);
  }

  void _handleTogglePin(String id) {
    // Drop float / pin-reveal chrome so focus lands on the category row.
    if (_floatingId == id) _setFloating(null);
    final owner = _CatalogCategoryRowState._chromeOwner;
    if (owner != null && owner.mounted && owner.widget.item.id == id) {
      if (owner._tvPinRevealed) {
        owner.setState(() => owner._tvPinRevealed = false);
      }
      owner._releaseChrome();
    }
    // Wait for host items rebuild ([didUpdateWidget]) before scroll+focus —
    // scheduling here would still see the pre-pin order.
    _pendingFocusId = id;
    widget.onTogglePin?.call(id);
  }

  void _scheduleScrollAndFocus(String id) {
    void go({required bool clear}) {
      if (!mounted || _pendingFocusId != id) return;
      _scrollAndFocusId(id);
      if (clear) _pendingFocusId = null;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      go(clear: false);
      // Second frame: row must be mounted after lazy sliver jump.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        go(clear: true);
      });
    });
  }

  void _scrollAndFocusId(String id) {
    final idx = widget.items.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    // Keep Favorites / Already watched above when the pin sits under them.
    final keepAbove = math.min(idx, math.max(_fixed.length, 1));
    _scrollToIndex(idx, keepAbove: keepAbove);
    final row = _CatalogCategoryRowState._byId[id];
    if (row == null || !row.mounted) return;
    row._clearPinReveal();
    row._focusRow();
  }

  @override
  Widget build(BuildContext context) {
    final railW = widget.width ?? catalogSideRailWidth(context);
    if (widget.items.isEmpty) {
      final empty = const Empty(title: 'No categories', size: EmptySize.sm);
      if (widget.header == null) {
        return SizedBox(width: railW, child: empty);
      }
      return SizedBox(
        width: railW,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                widget.rowPadH ??
                    catalogCategoryRailRowPadH(
                      context,
                      compact: widget.compact,
                    ),
                _listPadV(context),
                widget.rowPadH ??
                    catalogCategoryRailRowPadH(
                      context,
                      compact: widget.compact,
                    ),
                ShellTokens.topBarActionsGap,
              ),
              child: widget.header!,
            ),
            Expanded(child: empty),
          ],
        ),
      );
    }

    final fixed = _fixed;
    final movable = _movable;
    final jump = _jumpItems;
    final canReorder =
        widget.canReorder && widget.onReorder != null && movable.length > 1;

    Widget rowFor(
      CatalogCategoryItem item,
      int listIndex, {
      int? reorderIndex,
    }) {
      return _CatalogCategoryRow(
        key: ValueKey(item.id),
        item: item,
        selected: item.id == widget.selectedId,
        jumpHighlighted: item.id == _jumpHighlightId,
        compact: widget.compact,
        listIndex: listIndex,
        reorderIndex: canReorder ? reorderIndex : null,
        floating: _floatingId == item.id,
        rowExtent: _rowExtent(context),
        fontSize:
            widget.fontSize ??
            catalogCategoryRailFontSize(context, compact: widget.compact),
        iconSize:
            widget.iconSize ??
            catalogCategoryRailIconSize(context, compact: widget.compact),
        rowPadH: widget.rowPadH,
        rowPadV: widget.rowPadH == null
            ? catalogCategoryRailRowPadV(context, compact: widget.compact)
            : null,
        pinSlotWidth:
            widget.pinSlotWidth == ShellTokens.categoryRailPinSlotWidth
            ? catalogCategoryRailPinSlotWidth(context)
            : widget.pinSlotWidth,
        onSelect: widget.onSelect == null
            ? null
            : () {
                if (_jumpHighlightId != null) {
                  setState(() => _jumpHighlightId = null);
                }
                widget.onSelect!(item.id);
              },
        onTogglePin: item.pinnable && widget.onTogglePin != null
            ? () => _handleTogglePin(item.id)
            : null,
        onEnterFloating: canReorder && reorderIndex != null
            ? () => _setFloating(item.id)
            : null,
        onExitFloating: () {
          if (_floatingId == item.id) _setFloating(null);
        },
        onTvReorderUp: canReorder && reorderIndex != null
            ? () => _moveFloating(-1)
            : null,
        onTvReorderDown: canReorder && reorderIndex != null
            ? () => _moveFloating(1)
            : null,
        onTvEnterRight: widget.onTvEnterRight,
        onTvFocusUp: listIndex == 0 ? widget.onTvFocusUp : null,
      );
    }

    final list = LiveTvScrollbar(
      controller: _scroll,
      child: ColoredBox(
        color: ForjaShellColors.bgDark,
        child: SizedBox(
          width: railW,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollUpdateNotification &&
                  (notification.scrollDelta ?? 0) != 0) {
                _CatalogCategoryRowState.clearHover();
              }
              return false;
            },
            child: CustomScrollView(
              controller: _scroll,
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.symmetric(vertical: _listPadV(context)),
                  sliver: SliverMainAxisGroup(
                    slivers: [
                      if (fixed.isNotEmpty)
                        SliverFixedExtentList(
                          itemExtent: _rowExtent(context),
                          delegate: SliverChildBuilderDelegate(
                            (context, i) => rowFor(fixed[i], i),
                            childCount: fixed.length,
                            addAutomaticKeepAlives: false,
                          ),
                        ),
                      if (movable.isNotEmpty)
                        canReorder
                            ? SliverReorderableList(
                                itemCount: movable.length,
                                itemExtent: _rowExtent(context),
                                proxyDecorator: _reorderProxy,
                                onReorderItem: (oldIndex, newIndex) {
                                  widget.onReorder?.call(oldIndex, newIndex);
                                },
                                itemBuilder: (context, i) => rowFor(
                                  movable[i],
                                  fixed.length + i,
                                  reorderIndex: i,
                                ),
                              )
                            : SliverFixedExtentList(
                                itemExtent: _rowExtent(context),
                                delegate: SliverChildBuilderDelegate(
                                  (context, i) =>
                                      rowFor(movable[i], fixed.length + i),
                                  childCount: movable.length,
                                  addAutomaticKeepAlives: false,
                                ),
                              ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return ListLetterJumpScope(
      enabled: _letterJumpEnabled,
      itemCount: jump.length,
      anchorIndex: _letterJumpAnchor(),
      labelAt: (i) {
        final name = jump[i].label.trim();
        return name.isEmpty ? jump[i].id : name;
      },
      onJump: _letterJump,
      child: widget.header == null
          ? list
          : SizedBox(
              width: railW,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      widget.rowPadH ??
                          catalogCategoryRailRowPadH(
                            context,
                            compact: widget.compact,
                          ),
                      _listPadV(context),
                      widget.rowPadH ??
                          catalogCategoryRailRowPadH(
                            context,
                            compact: widget.compact,
                          ),
                      ShellTokens.topBarActionsGap,
                    ),
                    child: widget.header!,
                  ),
                  Expanded(child: list),
                ],
              ),
            ),
    );
  }

  void _moveFloating(int delta) {
    final id = _floatingId;
    if (id == null || widget.onReorder == null) return;
    final movable = _movable;
    final oldIndex = movable.indexWhere((e) => e.id == id);
    if (oldIndex < 0) return;
    final newIndex = (oldIndex + delta).clamp(0, movable.length - 1);
    if (newIndex == oldIndex) return;

    // Predict list index + scroll *before* notify paints — post-frame jump
    // flashes the row at the wrong viewport slot.
    final listIdx = widget.items.indexWhere((e) => e.id == id);
    final predictedListIdx =
        listIdx < 0 ? -1 : listIdx + (newIndex - oldIndex);
    final scrollTarget = predictedListIdx < 0
        ? null
        : _floatingMoveScrollTarget(
            listIndex: predictedListIdx,
            delta: delta,
          );

    widget.onReorder!(oldIndex, newIndex);
    if (scrollTarget != null && _scroll.hasClients) {
      final max = _scroll.position.maxScrollExtent;
      final target = scrollTarget.clamp(0.0, max);
      if ((_scroll.offset - target).abs() > 0.5) {
        _scroll.jumpTo(target);
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _floatingId != id) return;
      if (scrollTarget != null && _scroll.hasClients) {
        final max = _scroll.position.maxScrollExtent;
        final target = scrollTarget.clamp(0.0, max);
        if ((_scroll.offset - target).abs() > 0.5) {
          _scroll.jumpTo(target);
        }
      }
      // Rebuild can drop primary focus onto a neighbor — re-stick to float.
      final row = _CatalogCategoryRowState._chromeOwner;
      if (row != null && row.mounted && row.widget.item.id == id) {
        row._focusRow();
      }
    });
  }

  /// Scroll offset to pin [listIndex] at the edge band, or null if in band.
  ///
  /// Dragging up — **2nd** visible row. Dragging down — 2nd-from-bottom.
  double? _floatingMoveScrollTarget({
    required int listIndex,
    required int delta,
  }) {
    if (!_scroll.hasClients || listIndex < 0 || !mounted) return null;
    final rowH = _rowExtent(context);
    final pos = _scroll.position;
    final max = pos.maxScrollExtent;
    final viewH = pos.viewportDimension;
    final current = pos.pixels;
    final itemTop = _listPadV(context) + listIndex * rowH;

    late final double target;
    if (delta < 0) {
      target = (itemTop - rowH).clamp(0.0, max);
      if (current <= target + 0.5) return null;
    } else {
      target = (itemTop - viewH + 2 * rowH).clamp(0.0, max);
      if (current >= target - 0.5) return null;
    }
    return target;
  }

  static Widget _reorderProxy(
    Widget child,
    int index,
    Animation<double> animation,
  ) {
    return _CategoryDragProxyScope(child: child);
  }
}

/// Marks the SliverReorderableList drag overlay so the row paints lift chrome.
///
/// Must **not** be an [InheritedWidget]. The overlay reparents / tears down the
/// proxy subtree; `dependOnInheritedWidgetOfExactType` leaves stale dependents
/// and trips `'_dependents.isEmpty'` in [InheritedElement.debugDeactivated].
class _CategoryDragProxyScope extends StatelessWidget {
  const _CategoryDragProxyScope({required this.child});

  final Widget child;

  static bool isProxy(BuildContext context) =>
      context.findAncestorWidgetOfExactType<_CategoryDragProxyScope>() != null;

  @override
  Widget build(BuildContext context) => child;
}

class _CatalogCategoryRow extends StatefulWidget {
  const _CatalogCategoryRow({
    super.key,
    required this.item,
    required this.selected,
    this.jumpHighlighted = false,
    required this.compact,
    required this.listIndex,
    required this.rowExtent,
    required this.pinSlotWidth,
    this.fontSize,
    this.iconSize,
    this.rowPadH,
    this.rowPadV,
    this.reorderIndex,
    this.floating = false,
    this.onSelect,
    this.onTogglePin,
    this.onEnterFloating,
    this.onExitFloating,
    this.onTvReorderUp,
    this.onTvReorderDown,
    this.onTvEnterRight,
    this.onTvFocusUp,
  });

  final CatalogCategoryItem item;
  final bool selected;

  /// Type-to-jump chrome — hover look without committing selection.
  final bool jumpHighlighted;
  final bool compact;
  final int listIndex;
  final double rowExtent;
  final double pinSlotWidth;
  final double? fontSize;
  final double? iconSize;
  final double? rowPadH;
  final double? rowPadV;
  final int? reorderIndex;
  final bool floating;
  final VoidCallback? onSelect;
  final VoidCallback? onTogglePin;
  final VoidCallback? onEnterFloating;
  final VoidCallback? onExitFloating;
  final VoidCallback? onTvReorderUp;
  final VoidCallback? onTvReorderDown;
  final VoidCallback? onTvEnterRight;
  final VoidCallback? onTvFocusUp;

  @override
  State<_CatalogCategoryRow> createState() => _CatalogCategoryRowState();
}

class _CatalogCategoryRowState extends State<_CatalogCategoryRow>
    with SingleTickerProviderStateMixin {
  static _CatalogCategoryRowState? _chromeOwner;

  /// Mounted rows by category id — pin/unpin scroll+focus after list rebuild.
  static final Map<String, _CatalogCategoryRowState> _byId = {};

  /// Only one row paints hover — MouseRegion onExit is often skipped when a
  /// sibling enters, a Tooltip overlays, or the list scrolls under the cursor.
  static _CatalogCategoryRowState? _hoverOwner;

  static void clearHover() {
    final s = _hoverOwner;
    if (s == null) return;
    _hoverOwner = null;
    if (s.mounted) s._hoveredN.value = false;
  }

  /// Host Back handlers may call this to dismiss pin / floating chrome.
  static bool tryConsumeBack() {
    final s = _chromeOwner;
    if (s == null || !s.mounted) return false;
    if (s._pinFocus.hasFocus) {
      s._rowFocus.requestFocus();
      return true;
    }
    if (s.widget.floating) {
      s.widget.onExitFloating?.call();
      return true;
    }
    if (s._tvPinRevealed) {
      s.setState(() => s._tvPinRevealed = false);
      s._releaseChrome();
      return true;
    }
    return false;
  }

  bool _okHoldFired = false;
  bool _tvPinRevealed = false;
  Timer? _okHoldTimer;
  late final FocusNode _rowFocus;
  late final FocusNode _pinFocus;
  late final AnimationController _holdSunrise;
  final ValueNotifier<Offset?> _holdOriginN = ValueNotifier<Offset?>(null);

  /// Never setState on hover — rebuilding MouseRegion/FocusableControl mid
  /// hit-test sticks hover and stops following the pointer (pack choice cards).
  final ValueNotifier<bool> _hoveredN = ValueNotifier(false);
  Offset? _pointerDownGlobal;

  static const _okHoldDelay = Duration(seconds: 2);
  static const _dragHoldDelay = Duration(milliseconds: 1500);

  bool get _leanbackOnly =>
      ShellPaintScope.usesTvDensityOf(context) &&
      !ShellPaintScope.scaleOnHoverOf(context);

  /// Focus / float / pin-reveal — mirrors pre-wipe `_chromeLit`.
  bool get _chromeLit =>
      _rowFocus.hasFocus ||
      _pinFocus.hasFocus ||
      widget.floating ||
      _tvPinRevealed;

  bool get _tvFocused =>
      ShellPaintScope.focusStyledOf(context, focused: _chromeLit);

  bool _activeFor(bool hovered) => ShellPaintScope.interactiveActive(
    context,
    hovered: hovered,
    focused: _chromeLit,
  );

  bool get _canTvReorder =>
      widget.reorderIndex != null &&
      (widget.onTvReorderUp != null || widget.onTvReorderDown != null);

  bool get _canTvPin => widget.onTogglePin != null && widget.item.pinnable;

  bool _showPinFor(bool hovered) {
    if (!_canTvPin) return false;
    if (_leanbackOnly) {
      return widget.floating || _tvPinRevealed || _pinFocus.hasFocus;
    }
    return widget.item.pinned || hovered || _tvFocused;
  }

  @override
  void initState() {
    super.initState();
    _holdSunrise = AnimationController(vsync: this);
    _rowFocus = FocusNode(debugLabel: 'catalog-cat-${widget.listIndex}');
    _pinFocus = FocusNode(debugLabel: 'catalog-cat-pin-${widget.listIndex}');
    _byId[widget.item.id] = this;
    if (widget.floating) _claimChrome();
  }

  @override
  void didUpdateWidget(covariant _CatalogCategoryRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      if (_byId[oldWidget.item.id] == this) {
        _byId.remove(oldWidget.item.id);
      }
      _byId[widget.item.id] = this;
    }
    if (widget.floating != oldWidget.floating && widget.floating) {
      _claimChrome();
    }
    // Sticky float: after ↑/↓ reorder the row moves — keep focus on it.
    if (widget.floating &&
        (widget.listIndex != oldWidget.listIndex ||
            widget.reorderIndex != oldWidget.reorderIndex)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !widget.floating) return;
        _focusRow();
      });
    }
  }

  void _focusRow() {
    if (!_rowFocus.canRequestFocus) return;
    _rowFocus.requestFocus();
    if (!_rowFocus.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _rowFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _okHoldTimer?.cancel();
    if (_hoverOwner == this) _hoverOwner = null;
    if (_byId[widget.item.id] == this) _byId.remove(widget.item.id);
    _holdOriginN.dispose();
    _hoveredN.dispose();
    _holdSunrise.dispose();
    _releaseChrome();
    _pinFocus.dispose();
    _rowFocus.dispose();
    super.dispose();
  }

  void _claimChrome() {
    final prev = _chromeOwner;
    if (prev != null && prev != this && prev.mounted) {
      if (prev._tvPinRevealed) {
        prev.setState(() => prev._tvPinRevealed = false);
      }
      prev._releaseChrome();
    }
    _chromeOwner = this;
  }

  void _releaseChrome() {
    if (_chromeOwner == this) _chromeOwner = null;
  }

  void _clearPinReveal() {
    if (!_tvPinRevealed) return;
    setState(() => _tvPinRevealed = false);
    _releaseChrome();
  }

  void _setHovered(bool hovered) {
    if (hovered) {
      final prev = _hoverOwner;
      if (prev != null && prev != this && prev.mounted) {
        prev._hoveredN.value = false;
      }
      _hoverOwner = this;
      if (_hoveredN.value) return;
      _hoveredN.value = true;
      return;
    }
    if (_hoverOwner == this) _hoverOwner = null;
    if (!_hoveredN.value) return;
    _hoveredN.value = false;
  }

  void _cancelHold() {
    _okHoldTimer?.cancel();
    _okHoldTimer = null;
    // PointerUp can land after remount (shelf Live↔Movies/Series) disposed us.
    if (!mounted) return;
    _holdOriginN.value = null;
    _holdSunrise.stop();
    _holdSunrise.value = 0;
  }

  KeyEventResult _onRowKey(FocusNode node, KeyEvent event) {
    // Desktop hybrid + leanback both use the TV focus graph. Gate on that —
    // usesTvDensity alone left hold-OK / pin / reorder dead on macOS.
    final tvFocus = ShellPaintScope.useTvFocusOf(context);
    final activateDown = event is KeyDownEvent && _isActivateLogical(event);
    final activateUp = event is KeyUpEvent && _isActivateLogical(event);

    if (widget.floating) {
      // Parent HardwareKeyboard owns ↑/↓ / OK drop. Trap here if a KeyEvent
      // still reaches the row — do NOT call onTvReorder* (would double-step).
      if (event is KeyDownEvent || event is KeyRepeatEvent) {
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.arrowUp ||
            key == LogicalKeyboardKey.arrowDown) {
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowLeft) {
          if (event is KeyDownEvent) widget.onExitFloating?.call();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowRight) {
          if (_canTvPin) _pinFocus.requestFocus();
          return KeyEventResult.handled;
        }
        if (activateDown && !_okHoldFired) {
          widget.onExitFloating?.call();
          return KeyEventResult.handled;
        }
      }
      if (activateUp && _okHoldFired) {
        _okHoldFired = false;
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }

    if (_tvPinRevealed) {
      if ((event is KeyDownEvent || event is KeyRepeatEvent) &&
          event.logicalKey == LogicalKeyboardKey.arrowRight &&
          _canTvPin) {
        _pinFocus.requestFocus();
        return KeyEventResult.handled;
      }
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        setState(() => _tvPinRevealed = false);
        _releaseChrome();
        return KeyEventResult.handled;
      }
    }

    if (tvFocus && (_canTvReorder || _canTvPin)) {
      if (activateDown) {
        _okHoldFired = false;
        _okHoldTimer?.cancel();
        _holdOriginN.value = Offset(
          (context.size?.width ?? 100) / 2,
          (context.size?.height ?? 40) / 2,
        );
        _holdSunrise
          ..duration = _okHoldDelay
          ..forward(from: 0);
        _okHoldTimer = Timer(_okHoldDelay, () {
          if (!mounted) return;
          _okHoldFired = true;
          _cancelHold();
          // Last-release contract: reorderable → float (↑/↓ move); pin-only
          // → reveal pin. Floating still allows → to the pin.
          if (_canTvReorder) {
            _claimChrome();
            widget.onEnterFloating?.call();
          } else if (_canTvPin) {
            setState(() => _tvPinRevealed = true);
            _claimChrome();
          }
        });
        return KeyEventResult.handled;
      }
      if (activateUp) {
        _okHoldTimer?.cancel();
        _okHoldTimer = null;
        if (_okHoldFired) {
          _okHoldFired = false;
          return KeyEventResult.handled;
        }
        _cancelHold();
        widget.onSelect?.call();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  static bool _isActivateLogical(KeyEvent event) {
    final key = event.logicalKey;
    return key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.numpadEnter;
  }

  @override
  Widget build(BuildContext context) {
    final leanback = _leanbackOnly;
    final selected = widget.selected;
    // Desktop drag proxy wraps the row — same brighter green as TV floating.
    final lifted = widget.floating || _CategoryDragProxyScope.isProxy(context);

    Widget paintRow({required bool hovered}) {
      final active = _activeFor(hovered || widget.jumpHighlighted);
      // Focus / hover / lift own the “lit” look. Selected alone = faint open
      // tick (not brand-green icon) — leanback skim mutes selected via policy.
      final lit = _tvFocused || lifted || active;
      final iconColor = _tvFocused || lifted
          ? ForjaShellColors.brandGreen
          : active
          ? Colors.white
          : selected
          ? (leanback
                ? ForjaShellColors.textSecondary
                : ForjaShellColors.brandGreen.withValues(alpha: 0.7))
          : ForjaShellColors.textSecondary;
      final titleColor = _tvFocused || lifted
          ? ForjaShellColors.brandGreen
          : active
          ? ForjaShellColors.brandGreen
          : selected
          ? ForjaShellColors.brandGreen
          : ForjaShellColors.textSecondary;
      final leftBar = lifted || _tvFocused
          ? ForjaShellColors.brandGreen
          : active
          ? ForjaShellColors.brandGreen.withValues(alpha: 0.55)
          : selected
          ? ForjaShellColors.brandGreen.withValues(alpha: leanback ? 0.22 : 0.4)
          : Colors.transparent;
      // Fill only for focus / hover / floating. Snap colors — no fade trail.
      final fillColor = lifted
          ? ForjaShellColors.brandGreen.withValues(alpha: 0.28)
          : _tvFocused
          ? ForjaShellColors.brandGreen.withValues(alpha: 0.14)
          : (!leanback && active)
          ? ForjaShellColors.inkHover
          : Colors.transparent;

      return Container(
        width: double.infinity,
        height: widget.rowExtent,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: fillColor,
          border: Border(
            left: BorderSide(
              color: leftBar,
              width: ShellTokens.categoryRailLeftBarWidth,
            ),
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: EdgeInsets.only(
                left:
                    widget.rowPadH ??
                    catalogCategoryRailRowPadH(
                      context,
                      compact: widget.compact,
                    ),
                right:
                    widget.rowPadV ??
                    catalogCategoryRailRowPadV(
                      context,
                      compact: widget.compact,
                    ),
              ),
              child: Row(
                children: [
                  if (widget.item.icon != null) ...[
                    Icon(
                      widget.item.icon,
                      size:
                          widget.iconSize ??
                          catalogCategoryRailIconSize(
                            context,
                            compact: widget.compact,
                          ),
                      color: iconColor,
                    ),
                    SizedBox(
                      width: catalogUsesTvDensity(context)
                          ? ShellTokens.categoryRailItemGapTv
                          : widget.compact
                          ? ShellTokens.categoryRailItemGapCompact
                          : ShellTokens.categoryRailItemGap,
                    ),
                  ],
                  Expanded(
                    child: Text(
                      widget.item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: titleColor,
                        fontSize:
                            widget.fontSize ??
                            catalogCategoryRailFontSize(
                              context,
                              compact: widget.compact,
                            ),
                        fontWeight: lit || selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  // Reserve pin slot so hover pin does not reflow the label.
                  if (_canTvPin)
                    SizedBox(
                      width: widget.pinSlotWidth,
                      child: _showPinFor(hovered) ? _buildPin(leanback) : null,
                    ),
                ],
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_holdSunrise, _holdOriginN]),
                  builder: (context, _) {
                    final origin = _holdOriginN.value;
                    final progress = _holdSunrise.value;
                    if (origin == null || progress <= 0) {
                      return const SizedBox.shrink();
                    }
                    return CustomPaint(
                      painter: _HoldSunrisePainter(
                        origin: origin,
                        progress: progress,
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Paint listens to hover/focus — outer focusableTap stays put (no setState).
    final rowBody = ListenableBuilder(
      listenable: Listenable.merge([_hoveredN, _rowFocus, _pinFocus]),
      builder: (context, _) => paintRow(hovered: _hoveredN.value),
    );

    // Sync MouseRegion — shellFocusableTap defers hover via post-frame, which
    // races Tooltip overlays / sibling enter and leaves hover stuck.
    final hoveredBody = MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: rowBody,
    );

    // Flat rail: no FocusableControl scale, no Material ink fade — row paints
    // snap hover/selection itself (pre-wipe category sidebar contract).
    // allowNestedFocus: pin is a nested focusableTap — without this,
    // descendantsAreFocusable:false makes → after hold-OK a silent no-op.
    final tvFocus = ShellPaintScope.useTvFocusOf(context);
    Widget row = ShellPaintScope.focusableTap(
      context: context,
      onTap: () {
        _cancelHold();
        if (widget.floating) {
          widget.onExitFloating?.call();
          return;
        }
        widget.onSelect?.call();
      },
      borderRadius: 0,
      motion: ForjaMotionPreset.fillOnly,
      showFocusFill: false,
      suppressInkHover: true,
      listIndex: widget.listIndex,
      navLeftAlways: true,
      tvItemIndex: widget.listIndex,
      focusNode: _rowFocus,
      ensureVisibleMode: ShellPaintEnsureVisible.off,
      allowNestedFocus: _canTvPin && tvFocus,
      onKeyEvent: tvFocus ? _onRowKey : null,
      onUpEdge: widget.onTvFocusUp,
      onFocusChange: (focused) {
        if (focused) return;
        // Pin may take focus in the same frame after → from the row.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_rowFocus.hasFocus || _pinFocus.hasFocus) return;
          _clearPinReveal();
        });
      },
      onRightEdge: () {
        if (widget.floating || _tvPinRevealed) {
          if (_canTvPin) _pinFocus.requestFocus();
          return;
        }
        // → only moves focus into the channel grid. Never onSelect — that
        // reloads the catalog. OK / click selects; → focuses last/first channel.
        widget.onTvEnterRight?.call();
      },
      child: hoveredBody,
    );

    final reorderIndex = widget.reorderIndex;
    if (reorderIndex == null) return row;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) {
        _pointerDownGlobal = e.position;
        _holdOriginN.value = e.localPosition;
        _holdSunrise
          ..duration = _dragHoldDelay
          ..forward(from: 0);
      },
      onPointerMove: (e) {
        final start = _pointerDownGlobal;
        if (start == null) return;
        if ((e.position - start).distance > 12) _cancelHold();
      },
      onPointerUp: (_) => _cancelHold(),
      onPointerCancel: (_) => _cancelHold(),
      child: _DelayedReorderDragStartListener(index: reorderIndex, child: row),
    );
  }

  Widget _buildPin(bool leanback) {
    // Desktop hybrid (useTvFocus + hover) also needs a focusable pin so
    // hold-OK → can land on it — InkWell alone leaves _pinFocus detached.
    final tvFocus = ShellPaintScope.useTvFocusOf(context);
    final pinFocused = tvFocus && _pinFocus.hasFocus;
    final pinHovered = !leanback && _hoveredN.value;
    final icon = Icon(
      widget.item.pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
      size: widget.compact ? 16 : 17,
      color: pinFocused || pinHovered
          ? ForjaShellColors.brandGreen
          : ForjaShellColors.iconMuted,
    );
    if (!tvFocus) {
      // No Tooltip — hover-triggered overlay steals MouseRegion and sticks hover.
      return Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: widget.onTogglePin,
          borderRadius: BorderRadius.circular(
            ShellTokens.categoryRailPinRadius,
          ),
          child: Padding(
            padding: const EdgeInsets.all(ShellTokens.categoryRailPinPad),
            child: icon,
          ),
        ),
      );
    }
    return ShellPaintScope.focusableTap(
      context: context,
      onTap: widget.onTogglePin,
      borderRadius: ShellTokens.categoryRailPinRadius,
      motion: ForjaMotionPreset.fillOnly,
      showFocusFill: false,
      suppressInkHover: true,
      focusNode: _pinFocus,
      ensureVisibleMode: ShellPaintEnsureVisible.off,
      onLeftEdge: () => _rowFocus.requestFocus(),
      onUpEdge: () => _rowFocus.requestFocus(),
      onDownEdge: () => _rowFocus.requestFocus(),
      onRightEdge: () {},
      child: Padding(
        padding: const EdgeInsets.all(ShellTokens.categoryRailPinPad),
        child: icon,
      ),
    );
  }
}

class _DelayedReorderDragStartListener extends ReorderableDragStartListener {
  const _DelayedReorderDragStartListener({
    required super.child,
    required super.index,
  });

  @override
  MultiDragGestureRecognizer createRecognizer() {
    return DelayedMultiDragGestureRecognizer(
      delay: const Duration(milliseconds: 1500),
      debugOwner: this,
    );
  }
}

class _HoldSunrisePainter extends CustomPainter {
  _HoldSunrisePainter({required this.origin, required this.progress});

  final Offset origin;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || size.isEmpty) return;
    final t = Curves.easeOut.transform(progress.clamp(0.0, 1.0));
    var maxR = 0.0;
    for (final c in <Offset>[
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ]) {
      maxR = math.max(maxR, (c - origin).distance);
    }
    if (maxR <= 0) return;
    canvas.drawCircle(
      origin,
      maxR * t,
      Paint()..color = Colors.white.withValues(alpha: 0.08 + 0.14 * t),
    );
  }

  @override
  bool shouldRepaint(covariant _HoldSunrisePainter old) =>
      old.origin != origin || old.progress != progress;
}

/// Default icons for synthetic Live catalog rows.
IconData? catalogCategoryIconForId(String id) {
  switch (id) {
    case '__favorites__':
      return Icons.star_rounded;
    case '__watched__':
      return Icons.history_rounded;
    case 'all':
      return Icons.grid_view_rounded;
    default:
      return null;
  }
}
