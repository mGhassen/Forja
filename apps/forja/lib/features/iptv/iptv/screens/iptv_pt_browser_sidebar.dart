part of 'iptv_pt_screen.dart';

class _CategorySidebarRow extends StatefulWidget {
  const _CategorySidebarRow({
    super.key,
    required this.label,
    required this.selected,
    required this.compact,
    required this.listIndex,
    required this.onTap,
    this.icon,
    this.pinnable = false,
    this.pinned = false,
    this.onTogglePin,
    this.reorderIndex,
    this.floating = false,
    this.onEnterFloating,
    this.onExitFloating,
    this.onTvReorderUp,
    this.onTvReorderDown,
    this.onUpEdge,
    this.onRightEdge,
    this.onTvFocusChange,
  });

  final String label;
  final bool selected;
  final bool compact;
  final int listIndex;
  final VoidCallback onTap;
  final IconData? icon;
  final bool pinnable;
  final bool pinned;
  final VoidCallback? onTogglePin;
  /// Non-null → whole row is a reorder drag target.
  final int? reorderIndex;
  /// Parent-owned TV floating-reorder session (sticky across ↑/↓ moves).
  final bool floating;
  final VoidCallback? onEnterFloating;
  final VoidCallback? onExitFloating;
  /// TV floating-reorder: move this row up / down in the movable list.
  final VoidCallback? onTvReorderUp;
  final VoidCallback? onTvReorderDown;
  final VoidCallback? onUpEdge;
  final VoidCallback? onRightEdge;
  /// TV: report focus so the channel pane can stay lazy until OK / →.
  final ValueChanged<bool>? onTvFocusChange;

  @override
  State<_CategorySidebarRow> createState() => _CategorySidebarRowState();
}

class _CategorySidebarRowState extends State<_CategorySidebarRow> {
  /// Row with pin focus or floating reorder — Back returns here (HardwareKeyboard
  /// steals Focus onKey for goBack).
  static _CategorySidebarRowState? _chromeOwner;

  static bool tryConsumeBack() {
    final s = _chromeOwner;
    if (s == null || !s.mounted) return false;
    if (s._pinFocus.hasFocus) {
      s._focusRow();
      return true;
    }
    if (s.widget.floating) {
      s._exitFloating();
      return true;
    }
    return false;
  }

  bool _focused = false;
  bool _hovered = false;
  bool _okHoldFired = false;
  Timer? _okHoldTimer;

  late final FocusNode _rowFocus;
  late final FocusNode _pinFocus;

  static const Duration _okHoldDelay = Duration(seconds: 1);

  bool get _floating => widget.floating;

  bool get _chromeLit =>
      _focused || _pinFocus.hasFocus || _floating;

  bool get _tvFocused => iptvTvFocused(context, focused: _chromeLit);

  bool get _active =>
      iptvFocusActive(context, hovered: _hovered, focused: _chromeLit);

  bool get _showPin =>
      widget.pinnable &&
      widget.onTogglePin != null &&
      (widget.pinned || _hovered || _tvFocused);

  bool get _canTvReorder =>
      widget.reorderIndex != null &&
      (widget.onTvReorderUp != null || widget.onTvReorderDown != null);

  bool get _canTvPin =>
      widget.pinnable && widget.onTogglePin != null;

  @override
  void initState() {
    super.initState();
    _rowFocus = FocusNode(debugLabel: 'iptv-category-row-${widget.listIndex}');
    _pinFocus = FocusNode(debugLabel: 'iptv-category-pin-${widget.listIndex}');
    _pinFocus.addListener(_onPinFocusChanged);
    if (_floating || _pinFocus.hasFocus) _claimChrome();
  }

  @override
  void didUpdateWidget(covariant _CategorySidebarRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_floating != oldWidget.floating) {
      _syncChromeClaim();
    }
    // Sticky float: after ↑/↓ reorder the row moves — keep focus on it.
    if (_floating &&
        (widget.listIndex != oldWidget.listIndex ||
            widget.reorderIndex != oldWidget.reorderIndex)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_floating) return;
        _focusRow();
      });
    }
  }

  @override
  void dispose() {
    _cancelOkGestures();
    _releaseChrome();
    _pinFocus.removeListener(_onPinFocusChanged);
    _pinFocus.dispose();
    _rowFocus.dispose();
    super.dispose();
  }

  void _onPinFocusChanged() {
    if (!mounted) return;
    if (_pinFocus.hasFocus) {
      _claimChrome();
    } else {
      _syncChromeClaim();
    }
    setState(() {});
  }

  void _claimChrome() => _chromeOwner = this;

  void _releaseChrome() {
    if (_chromeOwner == this) _chromeOwner = null;
  }

  void _syncChromeClaim() {
    if (_pinFocus.hasFocus || _floating || _focused) {
      _claimChrome();
    } else {
      _releaseChrome();
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

  void _focusPin() {
    if (!_canTvPin || !_pinFocus.canRequestFocus) return;
    // Ensure pin is built (visible) before requesting focus.
    if (!_showPin) setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _pinFocus.requestFocus();
    });
  }

  void _cancelOkGestures() {
    _okHoldTimer?.cancel();
    _okHoldTimer = null;
    _okHoldFired = false;
  }

  void _enterFloating() {
    if (!_canTvReorder || _floating) return;
    _cancelOkGestures();
    _claimChrome();
    widget.onEnterFloating?.call();
  }

  void _exitFloating() {
    if (!_floating) return;
    widget.onExitFloating?.call();
    _syncChromeClaim();
  }

  void _onRowFocusChange(bool focused) {
    if (focused) {
      _cancelOkGestures();
      setState(() => _focused = true);
      _claimChrome();
      widget.onTvFocusChange?.call(true);
      return;
    }
    _cancelOkGestures();
    // Pin / floating may claim focus next frame — keep rail chrome until then.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_pinFocus.hasFocus || _floating) return;
      setState(() => _focused = false);
      _releaseChrome();
      widget.onTvFocusChange?.call(false);
    });
  }

  void _fireOpen() {
    _cancelOkGestures();
    widget.onTap();
  }

  KeyEventResult _onRowKey(FocusNode node, KeyEvent event) {
    if (!iptvUseTvFocus(context)) return KeyEventResult.ignored;

    if (_floating) {
      if (event is KeyRepeatEvent) return KeyEventResult.handled;
      if (event is! KeyDownEvent) return KeyEventResult.ignored;
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.arrowUp) {
        widget.onTvReorderUp?.call();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowDown) {
        widget.onTvReorderDown?.call();
        return KeyEventResult.handled;
      }
      if (shellTvIsActivateLogicalKey(key) ||
          key == LogicalKeyboardKey.arrowLeft) {
        _exitFloating();
        return KeyEventResult.handled;
      }
      // Trap → while floating (drop with OK / ← / Back).
      if (key == LogicalKeyboardKey.arrowRight) {
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    // → focuses pin when pinnable (channels open via OK).
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.arrowRight &&
        _canTvPin) {
      _cancelOkGestures();
      _focusPin();
      return KeyEventResult.handled;
    }

    // Long-press OK → floating reorder. Short OK → open channels.
    if (_canTvReorder || _canTvPin) {
      if (event is KeyDownEvent &&
          shellTvIsActivateLogicalKey(event.logicalKey)) {
        _okHoldFired = false;
        _okHoldTimer?.cancel();
        if (_canTvReorder) {
          _okHoldTimer = Timer(_okHoldDelay, () {
            if (!mounted) return;
            _okHoldFired = true;
            _enterFloating();
          });
        }
        return KeyEventResult.handled;
      }
      if (event is KeyUpEvent &&
          shellTvIsActivateLogicalKey(event.logicalKey)) {
        _okHoldTimer?.cancel();
        _okHoldTimer = null;
        if (_okHoldFired) {
          _okHoldFired = false;
          return KeyEventResult.handled;
        }
        _fireOpen();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  Widget _buildPin(BuildContext context) {
    final tv = iptvUseTvFocus(context);
    final pinFocused = tv && _pinFocus.hasFocus;
    final icon = Icon(
      widget.pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
      size: widget.compact ? 16 : 17,
      color: pinFocused
          ? ForjaShellColors.brandGreen
          : ForjaShellColors.iconMuted,
    );

    if (!tv) {
      return Tooltip(
        message: widget.pinned ? 'Unpin category' : 'Pin category',
        waitDuration: const Duration(milliseconds: 400),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: widget.onTogglePin,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: icon,
            ),
          ),
        ),
      );
    }

    return iptvTap(
      context: context,
      onTap: () {
        // Stay on the pin — refocusing the row would ensureVisible-scroll.
        widget.onTogglePin?.call();
      },
      borderRadius: 6,
      focusNode: _pinFocus,
      // Nested chrome — not a catalog row item (Back handled via tryConsumeBack).
      ensureVisibleMode: ShellTvEnsureVisibleMode.off,
      onLeftEdge: _focusRow,
      onUpEdge: _focusRow,
      onDownEdge: _focusRow,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: icon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final highlight = selected || _tvFocused;
    final emphatic = selected || _active || _tvFocused;
    final iconColor = _tvFocused || selected
        ? ForjaShellColors.brandGreen
        : _active
            ? Colors.white
            : ForjaShellColors.textSecondary;
    final titleColor = _tvFocused
        ? ForjaShellColors.brandGreen
        : emphatic
            ? Colors.white
            : ForjaShellColors.textSecondary;
    final tv = iptvUseTvFocus(context);

    // Floating = same row chrome, slightly brighter green (no card / border lift).
    final fillColor = _floating
        ? ForjaShellColors.brandGreen.withValues(alpha: 0.28)
        : _tvFocused
            ? ForjaShellColors.brandGreen.withValues(alpha: 0.14)
            : selected
                ? ForjaShellColors.inkHover
                : _active
                    ? ForjaShellColors.inkHover
                    : Colors.transparent;

    Widget rowBody = AnimatedContainer(
      duration: tv ? Duration.zero : const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      height: widget.compact ? 42 : 46,
      padding: EdgeInsets.only(
        left: widget.compact ? 10 : 12,
        right: widget.compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: fillColor,
        border: Border(
          left: BorderSide(
            color: highlight || _floating
                ? ForjaShellColors.brandGreen
                : _active
                    ? ForjaShellColors.brandGreen.withValues(alpha: 0.55)
                    : Colors.transparent,
            width: 2.5,
          ),
        ),
      ),
      child: Row(
        children: [
          if (widget.icon != null) ...[
            Icon(widget.icon, size: widget.compact ? 18 : 20, color: iconColor),
            SizedBox(width: widget.compact ? 10 : 12),
          ],
          Expanded(
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                color: titleColor,
                fontSize: widget.compact ? 13 : 14,
                fontWeight: emphatic || _floating
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
            ),
          ),
          if (_showPin) _buildPin(context),
        ],
      ),
    );

    Widget row = iptvTap(
      context: context,
      onTap: () {
        _cancelOkGestures();
        if (_floating) {
          _exitFloating();
          return;
        }
        widget.onTap();
      },
      borderRadius: 0,
      listIndex: widget.listIndex,
      // Vertical category column is the catalog's left edge - Left → nav rail
      // (not only listIndex 0; vertical rows otherwise trap ←).
      navLeftAlways: true,
      tvRowId: 'browser-categories',
      tvItemIndex: widget.listIndex,
      focusNode: _rowFocus,
      allowNestedFocus: tv && _canTvPin,
      // Vertical list — skip hub-row lift; keepVisible only in this scroll view.
      ensureVisibleMode: ShellTvEnsureVisibleMode.item,
      onKeyEvent: tv ? _onRowKey : null,
      onUpEdge: widget.onUpEdge,
      onRightEdge: () {
        _cancelOkGestures();
        if (_floating) {
          _exitFloating();
          return;
        }
        if (_canTvPin) {
          _focusPin();
          return;
        }
        widget.onRightEdge?.call();
      },
      onFocusChange: _onRowFocusChange,
      onHoverChange: (hovered) => setState(() => _hovered = hovered),
      child: rowBody,
    );

    final reorderIndex = widget.reorderIndex;
    if (reorderIndex == null) return row;
    return _CategoryReorderDragStartListener(
      index: reorderIndex,
      child: row,
    );
  }
}

/// Hold ~1.5s before category reorder begins (tap/scroll stay normal).
class _CategoryReorderDragStartListener extends ReorderableDragStartListener {
  const _CategoryReorderDragStartListener({
    required super.child,
    required super.index,
  });

  static const Duration _delay = Duration(milliseconds: 1500);

  @override
  MultiDragGestureRecognizer createRecognizer() {
    return DelayedMultiDragGestureRecognizer(
      delay: _delay,
      debugOwner: this,
    );
  }
}

/// Floating drag proxy: lifted card, elevated surface, brand-green accent.
Widget _iptvCategoryReorderProxy(
  Widget child,
  int index,
  Animation<double> animation,
) {
  return AnimatedBuilder(
    animation: animation,
    builder: (context, child) {
      final t = Curves.easeOutCubic.transform(animation.value);
      return Transform.translate(
        offset: Offset(6 * t, -6 * t),
        child: Transform.scale(
          scale: 1 + 0.04 * t,
          alignment: Alignment.centerLeft,
          child: Material(
            elevation: 12 * t,
            color: Colors.transparent,
            shadowColor: Colors.black.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                fit: StackFit.passthrough,
                children: [
                  Positioned.fill(
                    child: ColoredBox(
                      color: Color.lerp(
                        ForjaShellColors.surfaceElevated,
                        const Color(0xFF1E2A22),
                        t,
                      )!,
                    ),
                  ),
                  child!,
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: ForjaShellColors.brandGreen
                                .withValues(alpha: 0.28 + 0.52 * t),
                            width: 1.5,
                          ),
                          color: ForjaShellColors.brandGreen
                              .withValues(alpha: 0.10 * t),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
    child: child,
  );
}

IconData? _iptvCategoryIcon(String categoryId) {
  if (categoryId == IptvLiveCatalog.favoritesId) return Icons.star_rounded;
  if (categoryId == IptvLiveCatalog.watchedId) {
    return Icons.history_rounded;
  }
  return null;
}
