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
/// TV: hold OK ~1s reveals pin or enters floating reorder when [canReorder].
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

  static const double rowExtentDesktop = ShellTokens.categoryRailRowExtent;
  static const double rowExtentCompact = ShellTokens.categoryRailRowExtentCompact;

  /// Host Back handlers may call this to dismiss pin / floating chrome.
  static bool tryConsumeBack() => _CatalogCategoryRowState.tryConsumeBack();

  @override
  State<CatalogCategoryRail> createState() => _CatalogCategoryRailState();
}

class _CatalogCategoryRailState extends State<CatalogCategoryRail> {
  String? _floatingId;
  final ScrollController _scroll = ScrollController();

  double _listPadV(BuildContext context) => catalogUsesTvDensity(context)
      ? catalogCategoryRailListPadV(context)
      : widget.listPadV;

  double _rowExtent(BuildContext context) =>
      widget.rowHeight ??
      catalogCategoryRailRowExtent(context, compact: widget.compact);

  List<CatalogCategoryItem> get _fixed =>
      [for (final e in widget.items) if (e.fixed) e];

  List<CatalogCategoryItem> get _movable =>
      [for (final e in widget.items) if (!e.fixed) e];

  /// Favorites / Already watched stay out of type-to-jump (old IPTV).
  List<CatalogCategoryItem> get _jumpItems => _movable;

  bool get _leanbackOnly =>
      ShellPaintScope.usesTvDensityOf(context) &&
      !ShellPaintScope.scaleOnHoverOf(context);

  bool get _letterJumpEnabled =>
      !_leanbackOnly && _floatingId == null && _jumpItems.isNotEmpty;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  int _letterJumpAnchor() {
    final jump = _jumpItems;
    if (jump.isEmpty) return -1;
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
    widget.onSelect?.call(id);
    void go() {
      if (!mounted) return;
      _scrollToIndex(fullIdx);
    }

    go();
    WidgetsBinding.instance.addPostFrameCallback((_) => go());
  }

  void _scrollToIndex(int index, {int keepAbove = 2}) {
    if (!_scroll.hasClients || index < 0 || !mounted) return;
    final position = _scroll.position;
    final viewport = position.viewportDimension;
    if (viewport <= 0) return;
    final rowExtent = _rowExtent(context);
    final itemTop = _listPadV(context) + index * rowExtent;
    final target = (itemTop - keepAbove * rowExtent).clamp(
      0.0,
      position.maxScrollExtent,
    );
    if ((_scroll.offset - target).abs() < 0.5) return;
    _scroll.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    final railW = widget.width ?? catalogSideRailWidth(context);
    if (widget.items.isEmpty) {
      return SizedBox(
        width: railW,
        child: const Empty(title: 'No categories', size: EmptySize.sm),
      );
    }

    final fixed = _fixed;
    final movable = _movable;
    final jump = _jumpItems;
    final canReorder = widget.canReorder &&
        widget.onReorder != null &&
        movable.length > 1;

    Widget rowFor(CatalogCategoryItem item, int listIndex, {int? reorderIndex}) {
      return _CatalogCategoryRow(
        key: ValueKey(item.id),
        item: item,
        selected: item.id == widget.selectedId,
        compact: widget.compact,
        listIndex: listIndex,
        reorderIndex: canReorder ? reorderIndex : null,
        floating: _floatingId == item.id,
        rowExtent: _rowExtent(context),
        fontSize: widget.fontSize ??
            catalogCategoryRailFontSize(context, compact: widget.compact),
        iconSize: widget.iconSize ??
            catalogCategoryRailIconSize(context, compact: widget.compact),
        rowPadH: widget.rowPadH,
        rowPadV: widget.rowPadH == null
            ? catalogCategoryRailRowPadV(context, compact: widget.compact)
            : null,
        pinSlotWidth: widget.pinSlotWidth == ShellTokens.categoryRailPinSlotWidth
            ? catalogCategoryRailPinSlotWidth(context)
            : widget.pinSlotWidth,
        onSelect: widget.onSelect == null
            ? null
            : () => widget.onSelect!(item.id),
        onTogglePin: item.pinnable && widget.onTogglePin != null
            ? () => widget.onTogglePin!(item.id)
            : null,
        onEnterFloating: canReorder && reorderIndex != null
            ? () => setState(() => _floatingId = item.id)
            : null,
        onExitFloating: () {
          if (_floatingId == item.id) setState(() => _floatingId = null);
        },
        onTvReorderUp: canReorder && reorderIndex != null
            ? () => _moveFloating(-1)
            : null,
        onTvReorderDown: canReorder && reorderIndex != null
            ? () => _moveFloating(1)
            : null,
      );
    }

    final list = ColoredBox(
      color: ForjaShellColors.bgDark,
      child: SizedBox(
        width: railW,
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
      child: list,
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
    widget.onReorder!(oldIndex, newIndex);
  }

  static Widget _reorderProxy(
    Widget child,
    int index,
    Animation<double> animation,
  ) {
    return _CategoryDragProxyScope(child: child);
  }
}

class _CategoryDragProxyScope extends InheritedWidget {
  const _CategoryDragProxyScope({required super.child});

  static bool isProxy(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_CategoryDragProxyScope>() !=
      null;

  @override
  bool updateShouldNotify(covariant _CategoryDragProxyScope oldWidget) => false;
}

class _CatalogCategoryRow extends StatefulWidget {
  const _CatalogCategoryRow({
    super.key,
    required this.item,
    required this.selected,
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
  });

  final CatalogCategoryItem item;
  final bool selected;
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

  @override
  State<_CatalogCategoryRow> createState() => _CatalogCategoryRowState();
}

class _CatalogCategoryRowState extends State<_CatalogCategoryRow>
    with SingleTickerProviderStateMixin {
  static _CatalogCategoryRowState? _chromeOwner;

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

  bool _hovered = false;
  bool _okHoldFired = false;
  bool _tvPinRevealed = false;
  Timer? _okHoldTimer;
  late final FocusNode _rowFocus;
  late final FocusNode _pinFocus;
  late final AnimationController _holdSunrise;
  final ValueNotifier<Offset?> _holdOriginN = ValueNotifier<Offset?>(null);
  Offset? _pointerDownGlobal;

  static const _okHoldDelay = Duration(seconds: 1);
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

  bool get _active => ShellPaintScope.interactiveActive(
        context,
        hovered: _hovered,
        focused: _chromeLit,
      );

  bool get _canTvReorder =>
      widget.reorderIndex != null &&
      (widget.onTvReorderUp != null || widget.onTvReorderDown != null);

  bool get _canTvPin => widget.onTogglePin != null && widget.item.pinnable;

  bool get _showPin {
    if (!_canTvPin) return false;
    if (_leanbackOnly) {
      return widget.floating || _tvPinRevealed || _pinFocus.hasFocus;
    }
    return widget.item.pinned || _hovered || _tvFocused;
  }

  @override
  void initState() {
    super.initState();
    _holdSunrise = AnimationController(vsync: this);
    _rowFocus = FocusNode(debugLabel: 'catalog-cat-${widget.listIndex}');
    _pinFocus = FocusNode(debugLabel: 'catalog-cat-pin-${widget.listIndex}');
    // Paint from FocusNode — do not lag behind FocusableControl.onFocusChange.
    _rowFocus.addListener(_onChromeFocusChanged);
    _pinFocus.addListener(_onChromeFocusChanged);
  }

  void _onChromeFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _okHoldTimer?.cancel();
    _holdOriginN.dispose();
    _holdSunrise.dispose();
    _releaseChrome();
    _pinFocus.removeListener(_onChromeFocusChanged);
    _rowFocus.removeListener(_onChromeFocusChanged);
    _pinFocus.dispose();
    _rowFocus.dispose();
    super.dispose();
  }

  void _claimChrome() => _chromeOwner = this;

  void _releaseChrome() {
    if (_chromeOwner == this) _chromeOwner = null;
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
    final activate = ShellPaintScope.isActivateKeyOf(context, event);
    final leanback = ShellPaintScope.usesTvDensityOf(context);

    if (widget.floating) {
      if (event is KeyDownEvent || event is KeyRepeatEvent) {
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.arrowUp) {
          widget.onTvReorderUp?.call();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowDown) {
          widget.onTvReorderDown?.call();
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
        if (activate && event is KeyDownEvent && !_okHoldFired) {
          widget.onExitFloating?.call();
          return KeyEventResult.handled;
        }
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

    if (leanback && (_canTvReorder || _canTvPin)) {
      if (event is KeyDownEvent && activate) {
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
      if (event is KeyUpEvent && activate) {
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

  @override
  Widget build(BuildContext context) {
    final leanback = _leanbackOnly;
    final selected = widget.selected;
    // Desktop drag proxy wraps the row — same brighter green as TV floating.
    final lifted =
        widget.floating || _CategoryDragProxyScope.isProxy(context);
    // Focus / hover / lift own the “lit” look. Selected alone = faint open
    // tick (not brand-green icon) — leanback skim mutes selected via policy.
    final lit = _tvFocused || lifted || _active;
    final iconColor = _tvFocused || lifted
        ? ForjaShellColors.brandGreen
        : _active
            ? Colors.white
            : selected
                ? (leanback
                    ? ForjaShellColors.textSecondary
                    : ForjaShellColors.brandGreen.withValues(alpha: 0.7))
                : ForjaShellColors.textSecondary;
    final titleColor = _tvFocused || lifted
        ? ForjaShellColors.brandGreen
        : _active
            ? Colors.white
            : selected
                ? Colors.white.withValues(alpha: leanback ? 0.7 : 0.88)
                : ForjaShellColors.textSecondary;
    final leftBar = lifted || _tvFocused
        ? ForjaShellColors.brandGreen
        : _active
            ? ForjaShellColors.brandGreen.withValues(alpha: 0.55)
            : selected
                ? ForjaShellColors.brandGreen
                    .withValues(alpha: leanback ? 0.22 : 0.4)
                : Colors.transparent;
    // Fill only for focus / hover / floating. Snap colors — no fade trail.
    final fillColor = lifted
        ? ForjaShellColors.brandGreen.withValues(alpha: 0.28)
        : _tvFocused
            ? ForjaShellColors.brandGreen.withValues(alpha: 0.14)
            : (!leanback && _active)
                ? ForjaShellColors.inkHover
                : Colors.transparent;

    Widget rowBody = Container(
      width: double.infinity,
      height: widget.rowExtent,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: fillColor,
        border: Border(left: BorderSide(color: leftBar, width: ShellTokens.categoryRailLeftBarWidth)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Padding(
            padding: EdgeInsets.only(
              left: widget.rowPadH ??
                  catalogCategoryRailRowPadH(context, compact: widget.compact),
              right: widget.rowPadV ??
                  catalogCategoryRailRowPadV(context, compact: widget.compact),
            ),
            child: Row(
              children: [
                if (widget.item.icon != null) ...[
                  Icon(
                    widget.item.icon,
                    size: widget.iconSize ??
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
                      fontSize: widget.fontSize ??
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
                    child: _showPin ? _buildPin(leanback) : null,
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

    // Flat rail: no FocusableControl scale, no Material ink fade — row paints
    // snap hover/selection itself (pre-wipe category sidebar contract).
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
      onKeyEvent: ShellPaintScope.useTvFocusOf(context) ? _onRowKey : null,
      onHoverChange: (h) {
        if (_hovered == h) return;
        setState(() => _hovered = h);
      },
      onRightEdge: () {
        if (widget.floating || _tvPinRevealed) {
          if (_canTvPin) _pinFocus.requestFocus();
          return;
        }
        widget.onSelect?.call();
      },
      child: rowBody,
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
      child: _DelayedReorderDragStartListener(
        index: reorderIndex,
        child: row,
      ),
    );
  }

  Widget _buildPin(bool leanback) {
    final pinFocused = leanback && _pinFocus.hasFocus;
    final icon = Icon(
      widget.item.pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
      size: widget.compact ? 16 : 17,
      color: pinFocused
          ? ForjaShellColors.brandGreen
          : ForjaShellColors.iconMuted,
    );
    if (!leanback) {
      return Tooltip(
        message: widget.item.pinned ? 'Unpin category' : 'Pin category',
        waitDuration: const Duration(milliseconds: 400),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: widget.onTogglePin,
            borderRadius: BorderRadius.circular(ShellTokens.categoryRailPinRadius),
            child: Padding(padding: const EdgeInsets.all(ShellTokens.categoryRailPinPad), child: icon),
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
      child: Padding(padding: const EdgeInsets.all(ShellTokens.categoryRailPinPad), child: icon),
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
