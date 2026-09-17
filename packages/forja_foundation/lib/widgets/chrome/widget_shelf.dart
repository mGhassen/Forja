import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/tokens/forja_motion_theme.dart';
import 'package:flutter/services.dart';
import 'package:forja_foundation/widgets/chrome/shell_chip.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:google_fonts/google_fonts.dart';

/// One tab in a [WidgetShelf] (pack supplies label / icon / gradient).
class WidgetShelfItem {
  const WidgetShelfItem({
    required this.id,
    required this.label,
    this.icon,
    this.gradientColors = const [],
  });

  final String id;
  final String label;
  final IconData? icon;

  /// Selected / hover fill. Empty → muted idle only.
  final List<Color> gradientColors;
}

/// Grouped section tabs (e.g. Live / Movies / Series) — old IPTV shelf paint.
class WidgetShelf extends StatelessWidget {
  const WidgetShelf({
    super.key,
    required this.items,
    required this.selectedId,
    required this.onSelect,
    this.onReload,
    this.height = ShellTokens.widgetShelfHeight,
    this.radius = ShellTokens.widgetShelfRadius,
    this.fontSize = ShellTokens.widgetShelfFontSize,
    this.iconSize = ShellTokens.widgetShelfIconSize,
    this.pad = ShellTokens.widgetShelfGap,
    this.onDownEdge,
  });

  final List<WidgetShelfItem> items;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  /// Per-tab reload (hover / hold OK). Null → no reload chip.
  final ValueChanged<String>? onReload;
  final double height;
  final double radius;
  final double fontSize;
  final double iconSize;
  final double pad;
  final VoidCallback? onDownEdge;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final resolvedHeight =
        tv ? ShellTokens.widgetShelfHeightTv : height;
    final resolvedFontSize =
        tv ? ShellTokens.widgetShelfFontSizeTv : fontSize;
    final resolvedIconSize =
        tv ? ShellTokens.widgetShelfIconSizeTv : iconSize;
    final resolvedPad = tv ? ShellTokens.widgetShelfGapTv : pad;
    return Container(
      height: resolvedHeight,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < items.length; i++)
            _WidgetShelfTab(
              item: items[i],
              selected: selectedId == items[i].id,
              listIndex: i,
              isFirst: i == 0,
              isLast: i == items.length - 1,
              height: resolvedHeight,
              radius: radius,
              fontSize: resolvedFontSize,
              iconSize: resolvedIconSize,
              pad: resolvedPad,
              onTap: () => onSelect(items[i].id),
              onReload: onReload == null
                  ? null
                  : () => onReload!(items[i].id),
              onDownEdge: onDownEdge,
            ),
        ],
      ),
    );
  }
}

class _WidgetShelfTab extends StatefulWidget {
  const _WidgetShelfTab({
    required this.item,
    required this.selected,
    required this.listIndex,
    required this.isFirst,
    required this.isLast,
    required this.height,
    required this.radius,
    required this.fontSize,
    required this.iconSize,
    required this.pad,
    required this.onTap,
    this.onReload,
    this.onDownEdge,
  });

  final WidgetShelfItem item;
  final bool selected;
  final int listIndex;
  final bool isFirst;
  final bool isLast;
  final double height;
  final double radius;
  final double fontSize;
  final double iconSize;
  final double pad;
  final VoidCallback onTap;
  final VoidCallback? onReload;
  final VoidCallback? onDownEdge;

  @override
  State<_WidgetShelfTab> createState() => _WidgetShelfTabState();
}

class _WidgetShelfTabState extends State<_WidgetShelfTab> {
  static const _tvReloadHoldDelay = Duration(seconds: 1);

  bool _hover = false;
  bool _focused = false;
  bool _reloadChipFocused = false;
  bool _reloadArmed = false;
  bool _tvReloadRevealed = false;
  bool _okHoldFired = false;
  Timer? _revealTimer;
  Timer? _okHoldTimer;

  bool get _tv => ShellPaintScope.useTvFocusOf(context);

  bool get _paintActive =>
      ShellPaintScope.interactiveActive(
        context,
        hovered: _hover,
        focused: _focused,
      ) ||
      _reloadChipFocused ||
      _tvReloadRevealed;

  bool get _expandActive =>
      ShellPaintScope.interactiveActive(
        context,
        hovered: _hover,
        focused: _focused,
      ) ||
      (_tv && (_tvReloadRevealed || _reloadChipFocused));

  bool get _revealReload =>
      widget.onReload != null &&
      _expandActive &&
      (_reloadArmed || _tvReloadRevealed || _reloadChipFocused);

  List<Color> get _gradient {
    final c = widget.item.gradientColors;
    if (c.length >= 2) return c;
    if (c.length == 1) return [c.first, c.first];
    return const [Color(0xFF64748B), Color(0xFF334155)];
  }

  void _setHover(bool value) {
    if (_hover == value) return;
    setState(() {
      _hover = value;
      _syncReveal();
    });
  }

  void _setFocused(bool value) {
    if (_focused == value) return;
    setState(() {
      _focused = value;
      if (!value) {
        _cancelOkHold();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_focused || _reloadChipFocused) return;
          _hideTvReload();
        });
      }
      _syncReveal();
    });
  }

  void _setReloadChipFocused(bool value) {
    if (_reloadChipFocused == value) return;
    setState(() {
      _reloadChipFocused = value;
      if (!value) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_focused || _reloadChipFocused) return;
          _hideTvReload();
        });
      } else {
        _tvReloadRevealed = true;
        _reloadArmed = true;
      }
      _syncReveal();
    });
  }

  void _cancelOkHold() {
    _okHoldTimer?.cancel();
    _okHoldTimer = null;
    _okHoldFired = false;
  }

  void _hideTvReload() {
    _cancelOkHold();
    if (!_tvReloadRevealed && !_reloadArmed) return;
    setState(() {
      _tvReloadRevealed = false;
      if (_tv) _reloadArmed = false;
      _syncReveal();
    });
  }

  void _syncReveal() {
    if (widget.onReload == null) return;
    if (_expandActive) {
      if (_reloadArmed || _tvReloadRevealed) return;
      _revealTimer?.cancel();
      _revealTimer = Timer(
        Duration(
          milliseconds: ForjaMotionTheme.of(context).shelfRevealDelayMs,
        ),
        () {
        if (mounted && _expandActive) setState(() => _reloadArmed = true);
      });
    } else {
      _revealTimer?.cancel();
      _revealTimer = null;
      if (_reloadArmed) _reloadArmed = false;
    }
  }

  bool _isActivateLogical(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.gameButtonA;
  }

  KeyEventResult _onShelfKey(FocusNode node, KeyEvent event) {
    if (!_tv || widget.onReload == null) return KeyEventResult.ignored;
    if (!_isActivateLogical(event.logicalKey)) return KeyEventResult.ignored;
    if (event is KeyDownEvent) {
      _okHoldFired = false;
      _okHoldTimer?.cancel();
      _okHoldTimer = Timer(_tvReloadHoldDelay, () {
        if (!mounted || !_focused) return;
        _okHoldFired = true;
        setState(() {
          _tvReloadRevealed = true;
          _reloadArmed = true;
        });
        widget.onReload!();
      });
      return KeyEventResult.handled;
    }
    if (event is KeyUpEvent) {
      _okHoldTimer?.cancel();
      _okHoldTimer = null;
      if (_okHoldFired) {
        _okHoldFired = false;
        return KeyEventResult.handled;
      }
      widget.onTap();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    _cancelOkHold();
    super.dispose();
  }

  BorderRadius get _radius {
    final r = Radius.circular(widget.radius - 1);
    if (widget.isFirst && widget.isLast) return BorderRadius.all(r);
    if (widget.isFirst) {
      return BorderRadius.only(topLeft: r, bottomLeft: r);
    }
    if (widget.isLast) {
      return BorderRadius.only(topRight: r, bottomRight: r);
    }
    return BorderRadius.zero;
  }

  @override
  Widget build(BuildContext context) {
    final shelfRow = ShellPaintTvRowScope.maybeOf(context)?.rowId;
    final accent = _gradient.first;
    final invert = widget.selected && _paintActive;
    final showGradient = !invert && (widget.selected || _paintActive);

    final Color ink;
    if (invert) {
      ink = accent;
    } else if (showGradient) {
      ink = Colors.white;
    } else {
      ink = Colors.white60;
    }

    final tabBody = SizedBox(
      height: widget.height,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: widget.pad),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (widget.item.icon != null) ...[
              Icon(widget.item.icon, size: widget.iconSize, color: ink),
              const SizedBox(width: ShellTokens.shellChipGap),
            ],
            Text(
              widget.item.label,
              style: GoogleFonts.plusJakartaSans(
                color: ink,
                fontSize: widget.fontSize,
                fontWeight:
                    invert || showGradient ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );

    final tab = ShellPaintScope.focusableTap(
      context: context,
      onTap: widget.onTap,
      borderRadius: widget.radius,
      motion: ForjaMotionPreset.fillOnly,
      suppressInkHover: true,
      showFocusFill: false,
      listIndex: widget.listIndex,
      tvItemIndex: widget.listIndex,
      tvZone: ShellPaintTvZone.topBar,
      onDownEdge: widget.onDownEdge,
      onFocusChange: _setFocused,
      onKeyEvent: _tv && widget.onReload != null ? _onShelfKey : null,
      child: tabBody,
    );

    final desktopTab = !_tv
        ? shellRoundedInkHost(
            radius: widget.radius,
            onTap: widget.onTap,
            suppressInkHover: true,
            child: tabBody,
          )
        : tab;

    return MouseRegion(
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          gradient: showGradient
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _gradient,
                )
              : null,
          color: invert
              ? Colors.white
              : (showGradient ? null : Colors.transparent),
          borderRadius: _radius,
          boxShadow: showGradient
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _tv ? tab : desktopTab,
            if (widget.onReload != null)
              ClipRect(
                child: AnimatedAlign(
                  duration: ForjaMotionTheme.of(context).shelfExpand.duration,
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.centerLeft,
                  widthFactor: _revealReload ? 1 : 0,
                  child: SizedBox(
                    height: widget.height,
                    child: ShellPaintScope.focusableTap(
                      context: context,
                      onTap: widget.onReload!,
                      borderRadius: ShellTokens.widgetShelfRadius,
                      motion: ForjaMotionPreset.fillOnly,
                      suppressInkHover: true,
                      showFocusFill: false,
                      listIndex: widget.listIndex,
                      tvRowId:
                          shelfRow == null ? null : '$shelfRow-reload',
                      tvItemIndex: widget.listIndex,
                      tvZone: ShellPaintTvZone.topBar,
                      onDownEdge: widget.onDownEdge,
                      onFocusChange: _setReloadChipFocused,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Tooltip(
                            message: 'Reload ${widget.item.label}',
                            child: Icon(
                              Icons.refresh_rounded,
                              size: widget.iconSize,
                              color: invert
                                  ? accent
                                  : (showGradient || _revealReload
                                      ? Colors.white.withValues(alpha: 0.95)
                                      : Colors.white60),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
