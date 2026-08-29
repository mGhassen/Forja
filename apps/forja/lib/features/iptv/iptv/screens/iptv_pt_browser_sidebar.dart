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
    this.onDownEdge,
    this.onRightEdge,
    this.onTvFocusChange,
    this.onPinFocusChange,
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
  final VoidCallback? onDownEdge;
  final VoidCallback? onRightEdge;
  /// TV: report focus so the channel pane can stay lazy until OK / →.
  final ValueChanged<bool>? onTvFocusChange;
  /// TV: pin chrome focused — parent ExcludeFocus on channels.
  final ValueChanged<bool>? onPinFocusChange;

  @override
  State<_CategorySidebarRow> createState() => _CategorySidebarRowState();
}

class _CategorySidebarRowState extends State<_CategorySidebarRow>
    with SingleTickerProviderStateMixin {
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
    if (s._tvPinRevealed) {
      s._hideTvPinReveal();
      return true;
    }
    return false;
  }

  bool _focused = false;
  bool _hovered = false;
  bool _okHoldFired = false;
  bool _disposed = false;
  Timer? _okHoldTimer;
  /// TV: pin chrome after hold-OK when reorder is unavailable.
  bool _tvPinRevealed = false;

  late final FocusNode _rowFocus;
  late final FocusNode _pinFocus;
  late final AnimationController _holdSunrise;
  /// Hold-ring origin — ValueNotifier so we never setState mid-pointer (kills tap).
  final ValueNotifier<Offset?> _holdOriginN = ValueNotifier<Offset?>(null);
  Offset? _pointerDownGlobal;

  static const Duration _okHoldDelay = Duration(seconds: 1);

  bool get _floating => widget.floating;

  bool get _chromeLit =>
      _focused || _pinFocus.hasFocus || _floating || _tvPinRevealed;

  bool get _tvFocused => iptvTvFocused(context, focused: _chromeLit);

  bool get _active =>
      iptvFocusActive(context, hovered: _hovered, focused: _chromeLit);

  bool get _showPin {
    if (!widget.pinnable || widget.onTogglePin == null) return false;
    // Leanback: pin only after hold-OK (float / reveal) — normal browse hides it.
    // Desktop hybrid must show pin on hover even though D-pad focus is on.
    if (iptvLeanbackOnly(context)) {
      return _floating || _tvPinRevealed || _pinFocus.hasFocus;
    }
    return widget.pinned || _hovered || _tvFocused;
  }

  bool get _canTvReorder =>
      widget.reorderIndex != null &&
      (widget.onTvReorderUp != null || widget.onTvReorderDown != null);

  bool get _canTvPin =>
      widget.pinnable && widget.onTogglePin != null;

  @override
  void initState() {
    super.initState();
    _holdSunrise = AnimationController(vsync: this)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          _clearHoldSunrise();
        }
      });
    _rowFocus = FocusNode(debugLabel: 'iptv-category-row-${widget.listIndex}');
    _pinFocus = FocusNode(
      debugLabel: 'iptv-category-pin-${widget.listIndex}',
      onKeyEvent: (node, event) {
        // Belt-and-suspenders — FocusableControl can still spatial → to channels.
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
    );
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
    _disposed = true;
    _okHoldTimer?.cancel();
    _okHoldTimer = null;
    _pointerDownGlobal = null;
    _holdOriginN.value = null;
    _holdOriginN.dispose();
    _holdSunrise.dispose();
    _releaseChrome();
    // Pin chrome only — floating is parent-owned (`_tvFloatingCategoryId`).
    // Never sync-notify here: finalizeTree locks the framework (reorder remount).
    final clearPinChrome = _pinFocus.hasFocus || _tvPinRevealed;
    final onPinFocusChange = widget.onPinFocusChange;
    _pinFocus.removeListener(_onPinFocusChanged);
    _pinFocus.dispose();
    _rowFocus.dispose();
    super.dispose();
    if (clearPinChrome && onPinFocusChange != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onPinFocusChange(false);
      });
    }
  }

  void _startHoldSunrise(Offset origin, Duration duration) {
    if (_disposed) return;
    _holdOriginN.value = origin;
    _holdSunrise
      ..duration = duration
      ..forward(from: 0);
  }

  void _clearHoldSunrise() {
    // PointerUp can hit a disposed Listener after the row unmounts (reorder/exit).
    if (_disposed) return;
    final had = _holdOriginN.value != null || _holdSunrise.value > 0;
    if (!had) return;
    if (_holdSunrise.isAnimating || _holdSunrise.value > 0) {
      _holdSunrise.stop();
      _holdSunrise.value = 0;
    }
    _holdOriginN.value = null;
    _pointerDownGlobal = null;
  }

  RenderBox? _cardBox() {
    // No GlobalKey — reorder proxy + list slot would duplicate it.
    return context.findRenderObject() as RenderBox?;
  }

  Offset _rowCenterLocal() {
    final box = _cardBox();
    if (box == null || !box.hasSize) return Offset.zero;
    return box.size.center(Offset.zero);
  }

  void _onDesktopHoldPointerDown(PointerDownEvent e) {
    if (_disposed || _floating) return;
    if (e.kind == PointerDeviceKind.mouse && e.buttons != kPrimaryButton) {
      return;
    }
    final box = _cardBox();
    if (box == null || !box.hasSize) return;
    _pointerDownGlobal = e.position;
    _startHoldSunrise(
      box.globalToLocal(e.position),
      _CategoryReorderDragStartListener._delay,
    );
  }

  void _onDesktopHoldPointerMove(PointerMoveEvent e) {
    if (_disposed) return;
    final down = _pointerDownGlobal;
    if (down == null || _holdOriginN.value == null) return;
    if ((e.position - down).distance > kTouchSlop) {
      _clearHoldSunrise();
    }
  }

  void _onPinFocusChanged() {
    if (!mounted) return;
    final pinFocused = _pinFocus.hasFocus;
    if (pinFocused) {
      _claimChrome();
    } else {
      _syncChromeClaim();
    }
    setState(() {});
    widget.onPinFocusChange?.call(
      pinFocused || _tvPinRevealed || _floating,
    );
  }

  void _claimChrome() => _chromeOwner = this;

  void _releaseChrome() {
    if (_chromeOwner == this) _chromeOwner = null;
  }

  void _syncChromeClaim() {
    if (_pinFocus.hasFocus || _floating || _focused || _tvPinRevealed) {
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
    if (!_showPin) {
      setState(() => _tvPinRevealed = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _pinFocus.requestFocus();
      });
      return;
    }
    if (_pinFocus.context != null) {
      _pinFocus.requestFocus();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _pinFocus.requestFocus();
    });
  }

  void _hideTvPinReveal() {
    if (!_tvPinRevealed && !_pinFocus.hasFocus) return;
    if (_pinFocus.hasFocus) _focusRow();
    setState(() => _tvPinRevealed = false);
    _syncChromeClaim();
    widget.onPinFocusChange?.call(_pinFocus.hasFocus || _floating);
  }

  void _cancelOkGestures({bool clearHoldFired = true}) {
    _okHoldTimer?.cancel();
    _okHoldTimer = null;
    if (clearHoldFired) _okHoldFired = false;
    _clearHoldSunrise();
  }

  void _enterFloating() {
    if (!_canTvReorder || _floating) return;
    // Cancel the timer only — keep _okHoldFired so the OK KeyUp after
    // hold-to-enter is swallowed (otherwise float drops on release).
    // Don't clear sunrise here — timer callback already did (or desktop drag owns it).
    _okHoldTimer?.cancel();
    _okHoldTimer = null;
    _tvPinRevealed = false;
    _claimChrome();
    widget.onEnterFloating?.call();
    widget.onPinFocusChange?.call(true);
  }

  void _exitFloating() {
    if (!_floating) return;
    widget.onExitFloating?.call();
    _syncChromeClaim();
    widget.onPinFocusChange?.call(_pinFocus.hasFocus || _tvPinRevealed);
  }

  void _onRowFocusChange(bool focused) {
    if (focused) {
      // Don't clear hold-fired mid enter-float (OK KeyUp still coming).
      if (!_floating && !_okHoldFired) _cancelOkGestures();
      setState(() => _focused = true);
      _claimChrome();
      widget.onTvFocusChange?.call(true);
      return;
    }
    _cancelOkGestures();
    // Sync-clear hover chrome — deferred clear left a ghost row lit for a
    // frame during ↑/↓ (looked like 2–3 hovers with selected + next focus).
    // Pin / float still keep chrome via _chromeLit without _focused.
    if (_focused) setState(() => _focused = false);
    widget.onTvFocusChange?.call(false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_pinFocus.hasFocus || _floating || _rowFocus.hasFocus) return;
      if (_tvPinRevealed) {
        setState(() => _tvPinRevealed = false);
        widget.onPinFocusChange?.call(false);
      }
      _releaseChrome();
    });
  }

  void _fireOpen() {
    _cancelOkGestures();
    widget.onTap();
  }

  KeyEventResult _onRowKey(FocusNode node, KeyEvent event) {
    if (!iptvUseTvFocus(context)) return KeyEventResult.ignored;

    if (_floating) {
      // Parent HardwareKeyboard owns ↑/↓ / OK drop. Keep trapping here if a
      // KeyEvent still reaches the row (e.g. handler unbound mid-frame).
      final key = event.logicalKey;
      final nav = key == LogicalKeyboardKey.arrowUp ||
          key == LogicalKeyboardKey.arrowDown ||
          key == LogicalKeyboardKey.arrowLeft ||
          key == LogicalKeyboardKey.arrowRight;
      final activate = shellTvIsActivateLogicalKey(key);
      if (!nav && !activate) return KeyEventResult.ignored;

      if (event is KeyDownEvent || event is KeyRepeatEvent) {
        // ↑/↓: trap only — HardwareKeyboard already moved once. Calling
        // onTvReorder* here doubles the step (HW return true ≠ Focus skip).
        if (key == LogicalKeyboardKey.arrowUp ||
            key == LogicalKeyboardKey.arrowDown) {
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowLeft) {
          if (event is KeyDownEvent) _exitFloating();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowRight) {
          // Hold-OK session: → focuses pin (not channels).
          if (_canTvPin) _focusPin();
          return KeyEventResult.handled;
        }
        if (activate) {
          // Fresh OK KeyDown drops; ignore while enter-hold flag still set.
          if (event is KeyDownEvent && !_okHoldFired) {
            _exitFloating();
          }
          return KeyEventResult.handled;
        }
        return KeyEventResult.handled;
      }
      if (event is KeyUpEvent && activate) {
        // Release after hold-to-enter — stay floating.
        if (_okHoldFired) _okHoldFired = false;
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }

    // Pin revealed (hold without reorder): → focuses pin; ← hides.
    if (_tvPinRevealed) {
      final key = event.logicalKey;
      if ((event is KeyDownEvent || event is KeyRepeatEvent) &&
          key == LogicalKeyboardKey.arrowRight &&
          _canTvPin) {
        _focusPin();
        return KeyEventResult.handled;
      }
      if (event is KeyDownEvent && key == LogicalKeyboardKey.arrowLeft) {
        _hideTvPinReveal();
        return KeyEventResult.handled;
      }
    }

    // Long-press OK → float (reorder) or reveal pin. Short OK → open channels.
    // Normal → is ignored here → onRightEdge opens channels.
    // ↑/↓ stay ignored so FocusableControl can HoldAccel + parent jump-focus.
    if (_canTvReorder || _canTvPin) {
      if (event is KeyDownEvent &&
          shellTvIsActivateLogicalKey(event.logicalKey)) {
        _okHoldFired = false;
        _okHoldTimer?.cancel();
        _startHoldSunrise(_rowCenterLocal(), _okHoldDelay);
        _okHoldTimer = Timer(_okHoldDelay, () {
          if (!mounted) return;
          _okHoldFired = true;
          _clearHoldSunrise();
          if (_canTvReorder) {
            _enterFloating();
          } else if (_canTvPin) {
            setState(() => _tvPinRevealed = true);
            _claimChrome();
            widget.onPinFocusChange?.call(true);
          }
        });
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
        _clearHoldSunrise();
        _fireOpen();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  Widget _buildPin(BuildContext context) {
    final leanback = iptvLeanbackOnly(context);
    final pinFocused = leanback && _pinFocus.hasFocus;
    final icon = Icon(
      widget.pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
      size: widget.compact ? 16 : 17,
      color: pinFocused
          ? ForjaShellColors.brandGreen
          : ForjaShellColors.iconMuted,
    );

    if (!leanback) {
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
        // Parent scrolls + focuses the row at its new index after pin/unpin.
        widget.onTogglePin?.call();
      },
      borderRadius: 6,
      focusNode: _pinFocus,
      // Nested chrome — not a catalog row item (Back handled via tryConsumeBack).
      ensureVisibleMode: ShellTvEnsureVisibleMode.off,
      onLeftEdge: _focusRow,
      onUpEdge: _focusRow,
      onDownEdge: _focusRow,
      // Trap → — spatial would jump into the channel pane (right-left-right bug).
      onRightEdge: () {},
      onKeyEvent: (node, event) {
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.arrowRight) {
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: icon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final tv = iptvUseTvFocus(context);
    final leanback = iptvLeanbackOnly(context);
    // Desktop drag proxy wraps the row — same brighter green as TV floating.
    final lifted =
        _floating || _IptvCategoryDragProxyScope.isProxy(context);
    // Focus / hover / lift own the “lit” look. Selected alone = faint open
    // tick (not brand-green icon) — leanback skim mutes selected entirely via
    // parent pending-commit so ↓ never paints two focus-strength rows.
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
                ? ForjaShellColors.brandGreen.withValues(alpha: leanback ? 0.22 : 0.4)
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
      height: widget.compact ? 42 : 46,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: fillColor,
        border: Border(
          left: BorderSide(
            color: leftBar,
            width: 2.5,
          ),
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Padding(
            padding: EdgeInsets.only(
              left: widget.compact ? 10 : 12,
              right: widget.compact ? 6 : 8,
            ),
            child: Row(
              children: [
                if (widget.icon != null) ...[
                  Icon(
                    widget.icon,
                    size: widget.compact ? 18 : 20,
                    color: iconColor,
                  ),
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
                      fontWeight: lit || selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
                if (_showPin) _buildPin(context),
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
                    painter: _CategoryHoldSunrisePainter(
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
      allowNestedFocus: leanback && _canTvPin && _showPin,
      // Vertical list: keepVisible only — never snap the rail to put the row
      // at the top (`.item` does that for Settings labels).
      // Floating / pin chrome: parent freezes scroll — ensureVisible fights it.
      ensureVisibleMode: (_floating || _pinFocus.hasFocus)
          ? ShellTvEnsureVisibleMode.off
          : ShellTvEnsureVisibleMode.row,
      onKeyEvent: tv ? _onRowKey : null,
      onUpEdge: widget.onUpEdge,
      onDownEdge: widget.onDownEdge,
      onRightEdge: () {
        _cancelOkGestures();
        if (_floating || _tvPinRevealed) {
          if (_canTvPin) {
            _focusPin();
            return;
          }
          return;
        }
        // Normal browse: → opens channels.
        widget.onRightEdge?.call();
      },
      onFocusChange: _onRowFocusChange,
      onHoverChange: (hovered) => setState(() => _hovered = hovered),
      child: rowBody,
    );

    final reorderIndex = widget.reorderIndex;
    if (reorderIndex == null) return row;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onDesktopHoldPointerDown,
      onPointerMove: _onDesktopHoldPointerMove,
      onPointerUp: (_) => _clearHoldSunrise(),
      onPointerCancel: (_) => _clearHoldSunrise(),
      child: _CategoryReorderDragStartListener(
        index: reorderIndex,
        child: row,
      ),
    );
  }
}

/// Neutral expanding circle clipped inside the category row while holding.
class _CategoryHoldSunrisePainter extends CustomPainter {
  _CategoryHoldSunrisePainter({
    required this.origin,
    required this.progress,
  });

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
  bool shouldRepaint(covariant _CategoryHoldSunrisePainter old) =>
      old.origin != origin || old.progress != progress;
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

/// Marks the drag overlay so [_CategorySidebarRow] paints TV floating chrome.
class _IptvCategoryDragProxyScope extends InheritedWidget {
  const _IptvCategoryDragProxyScope({required super.child});

  static bool isProxy(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<_IptvCategoryDragProxyScope>() !=
        null;
  }

  @override
  bool updateShouldNotify(covariant _IptvCategoryDragProxyScope oldWidget) =>
      false;
}

/// Drag proxy: same brighter-green rail chrome as TV floating (no card lift).
Widget _iptvCategoryReorderProxy(
  Widget child,
  int _,
  Animation<double> _,
) {
  return _IptvCategoryDragProxyScope(child: child);
}

IconData? _iptvCategoryIcon(String categoryId) {
  if (categoryId == IptvLiveCatalog.favoritesId) return Icons.star_rounded;
  if (categoryId == IptvLiveCatalog.watchedId) {
    return Icons.history_rounded;
  }
  return null;
}
