part of 'iptv_catalog_workspace.dart';

class _IptvPortalDialogField extends StatefulWidget {
  const _IptvPortalDialogField({
    required this.controller,
    required this.focusNode,
    required this.onArrowUp,
    required this.onArrowDown,
    this.onArrowRight,
    this.onSubmit,
    this.obscureText = false,
    this.style,
    this.hintText,
    this.hintStyle,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onArrowUp;
  final VoidCallback onArrowDown;
  final VoidCallback? onArrowRight;
  final VoidCallback? onSubmit;
  final bool obscureText;
  final TextStyle? style;
  final String? hintText;
  final TextStyle? hintStyle;
  final Widget? suffixIcon;

  @override
  State<_IptvPortalDialogField> createState() => _IptvPortalDialogFieldState();
}

class _IptvPortalDialogFieldState extends State<_IptvPortalDialogField> {
  FocusOnKeyEventCallback? _previousHandler;
  bool _editing = false;

  bool get _tvBrowse => iptvLeanbackOnly(context) && !_editing;

  @override
  void initState() {
    super.initState();
    _attachKeyHandler();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant _IptvPortalDialogField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChange);
      widget.focusNode.addListener(_onFocusChange);
      oldWidget.focusNode.onKeyEvent = _previousHandler;
      _attachKeyHandler();
    }
  }

  void _onFocusChange() {
    if (!widget.focusNode.hasFocus && _editing && mounted) {
      setState(() => _editing = false);
    } else if (mounted) {
      setState(() {});
    }
    if (widget.focusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !widget.focusNode.hasFocus) return;
        Scrollable.ensureVisible(
          context,
          alignment: 0.15,
          duration: Duration.zero,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      });
    }
  }

  void _attachKeyHandler() {
    _previousHandler = widget.focusNode.onKeyEvent;
    widget.focusNode.onKeyEvent = _handleKey;
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    widget.focusNode.onKeyEvent = _previousHandler;
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (_tvBrowse && shellTvIsActivateKey(event)) {
      setState(() => _editing = true);
      return KeyEventResult.handled;
    }
    if (_tvBrowse && event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        widget.onArrowDown();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        widget.onArrowUp();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
          widget.onArrowRight != null) {
        widget.onArrowRight!();
        return KeyEventResult.handled;
      }
    }
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        _editing) {
      setState(() => _editing = false);
      return KeyEventResult.handled;
    }
    return _previousHandler?.call(node, event) ?? KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final leanback = iptvLeanbackOnly(context);
    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      obscureText: widget.obscureText,
      readOnly: leanback && !_editing,
      enableInteractiveSelection: !leanback || _editing,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => widget.onSubmit?.call(),
      style: widget.style,
      decoration: iptvDialogFieldDecoration(
        focused: widget.focusNode.hasFocus,
        hintText: widget.hintText,
        hintStyle: widget.hintStyle,
        suffixIcon: widget.suffixIcon,
      ),
    );
  }
}

class _PortalHoverTile extends StatefulWidget {
  const _PortalHoverTile({
    required this.portal,
    required this.ctrl,
    required this.isActive,
    required this.listIndex,
    required this.onEdit,
    this.onUpEdge,
    this.onDownEdge,
  });

  final VerifiedPortal portal;
  final IptvController ctrl;
  final bool isActive;
  final int listIndex;
  final VoidCallback onEdit;
  final VoidCallback? onUpEdge;
  final VoidCallback? onDownEdge;

  @override
  State<_PortalHoverTile> createState() => _PortalHoverTileState();
}

class _PortalHoverTileState extends State<_PortalHoverTile> {
  static const _actionW = 108.0;
  static const _statusSlot = 18.0;
  static const _rowH = 98.0;
  static const _detailHoverDelay = Duration(seconds: 1);

  bool _lineHover = false;
  bool _focused = false;
  bool _sharing = false;
  bool _showShareCode = false;
  bool _confirmingDelete = false;
  String? _shareCode;
  late final FocusNode _favoriteFocus;
  late final FocusNode _copyFocus;
  late final FocusNode _editFocus;
  late final FocusNode _deleteFocus;
  late final FocusNode _confirmYesFocus;
  late final FocusNode _confirmNoFocus;
  late final FocusNode _rowFocus;
  final LayerLink _detailLink = LayerLink();
  Timer? _detailTimer;
  OverlayEntry? _detailOverlay;

  /// Stay open while D-pad is on favorite / rail actions (TV has no hover).
  bool get _actionChromeFocused =>
      _favoriteFocus.hasFocus ||
      _copyFocus.hasFocus ||
      _editFocus.hasFocus ||
      _deleteFocus.hasFocus ||
      _confirmYesFocus.hasFocus ||
      _confirmNoFocus.hasFocus;

  /// Desktop: reveal on hover/focus. Leanback: keep closed while D-pad scrolls
  /// the list — expand only when action chrome / delete is active so ↑/↓ does
  /// not reflow every row. Desktop hybrid still has D-pad focus but must hover.
  bool get _reveal {
    if (_confirmingDelete || _actionChromeFocused) return true;
    if (_lineHover || (_focused && !_tvListScrollMode)) return true;
    return false;
  }

  bool get _tvListScrollMode =>
      mounted && iptvLeanbackOnly(context);

  double get _rowHeight => _rowH;

  @override
  void initState() {
    super.initState();
    _rowFocus = FocusNode(debugLabel: 'iptv-portal-row');
    _favoriteFocus = FocusNode(debugLabel: 'iptv-portal-favorite');
    _copyFocus = FocusNode(debugLabel: 'iptv-portal-copy');
    _editFocus = FocusNode(debugLabel: 'iptv-portal-edit');
    _deleteFocus = FocusNode(debugLabel: 'iptv-portal-delete');
    _confirmYesFocus = FocusNode(debugLabel: 'iptv-portal-delete-yes');
    _confirmNoFocus = FocusNode(debugLabel: 'iptv-portal-delete-no');
    for (final node in [
      _favoriteFocus,
      _copyFocus,
      _editFocus,
      _deleteFocus,
      _confirmYesFocus,
      _confirmNoFocus,
    ]) {
      node.addListener(_onActionFocusChanged);
    }
  }

  @override
  void dispose() {
    _hideDetailCard();
    for (final node in [
      _favoriteFocus,
      _copyFocus,
      _editFocus,
      _deleteFocus,
      _confirmYesFocus,
      _confirmNoFocus,
    ]) {
      node.removeListener(_onActionFocusChanged);
      node.dispose();
    }
    _rowFocus.dispose();
    super.dispose();
  }

  void _onActionFocusChanged() {
    if (mounted) setState(() {});
  }

  /// Desktop: keep `_focused` one frame so action focus can land.
  /// TV: sync-clear — deferred clear leaves a ghost hover fill during ↑/↓.
  void _onRowFocusChange(bool focused) {
    final ctrl = widget.ctrl;
    final v = widget.portal;
    final leanback = iptvLeanbackOnly(context);
    if (focused) {
      // Desktop hover/focus dismisses NEW. Leanback: skim ↑/↓ must not — that
      // notifyListeners rebuilds the panel mid-scroll (hover chrome flash).
      if (!leanback && ctrl.isNewPortal(v.key)) {
        ctrl.markPortalSeen(v.key);
      }
      // Leanback: 2s dwell before probe — instant focus probes stutter D-pad
      // scroll through long lists (notifyListeners rebuilds the IPTV shell).
      // Local setState (not ctrl.notify) paints the checking spinner during the
      // dwell; [isPortalHealthChecking] includes the pending debounce timer.
      if (leanback) {
        ctrl.schedulePortalHealthCheck(
          v,
          delay: const Duration(seconds: 2),
        );
      }
      if (!_focused || leanback) {
        setState(() => _focused = true);
      }
      return;
    }
    void clear() {
      if (!mounted) return;
      if (_focused) setState(() => _focused = false);
      ctrl.cancelPortalHealthCheck(v.key);
    }

    // Leanback: sync-clear like the category rail — deferred clear leaves a
    // ghost hover fill on the previous row for a frame during ↑/↓.
    if (leanback) {
      clear();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => clear());
  }

  void _focusAction(FocusNode node) {
    if (!node.canRequestFocus) return;
    node.requestFocus();
    if (!node.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) node.requestFocus();
      });
    }
  }

  /// TV: Left from any portal row → header actions. Up only reaches the header
  /// from the first row; Left works at any scroll position (stays in panel).
  void _leftToPortalHeader() {
    if (!iptvUseTvFocus(context)) return;
    iptvFocusRowItem('iptv-portal-header');
  }

  /// Action chrome is its own horizontal row (sortOrder 200+) — without
  /// explicit ↑/↓ edges, Down traps on the button instead of the portal list.
  void _upFromActions() {
    if (widget.listIndex <= 0) {
      if (widget.onUpEdge != null) {
        widget.onUpEdge!();
        return;
      }
      iptvFocusRowItem('iptv-portal-header', 0);
      return;
    }
    if (widget.onUpEdge != null) {
      widget.onUpEdge!();
      return;
    }
    iptvFocusRowItem('portals', widget.listIndex - 1);
  }

  void _downFromActions() {
    if (widget.onDownEdge != null) {
      widget.onDownEdge!();
      return;
    }
    final handle = ShellTvFocusCoordinator.rowHandle('iptv', 'portals');
    final count = handle?.itemCount ?? 0;
    if (widget.listIndex + 1 < count) {
      iptvFocusRowItem('portals', widget.listIndex + 1);
      return;
    }
    // Last portal without an edge: stay on the card (panel wires exit itself).
    _focusAction(_rowFocus);
  }

  String get _actionsRowId => 'portal-${widget.listIndex}-actions';

  void _clearHover() {
    setState(() => _lineHover = false);
    _hideDetailCard();
  }

  void _scheduleDetailCard() {
    _detailTimer?.cancel();
    _detailTimer = Timer(_detailHoverDelay, () {
      if (!mounted || !_lineHover) return;
      _showDetailCard();
    });
  }

  void _showDetailCard() {
    if (_detailOverlay != null) {
      _detailOverlay!.markNeedsBuild();
      return;
    }
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    _detailOverlay = OverlayEntry(
      builder: (ctx) {
        final ctrl = widget.ctrl;
        final v = widget.portal;
        // UnconstrainedBox: Overlay gives max constraints; without this the
        // DecoratedBox expands into a full-screen black slab (EPG peek uses
        // a Row slot instead — same tight-size rule).
        return CompositedTransformFollower(
          link: _detailLink,
          showWhenUnlinked: false,
          targetAnchor: Alignment.centerLeft,
          followerAnchor: Alignment.centerRight,
          offset: const Offset(-10, 0),
          child: UnconstrainedBox(
            alignment: Alignment.centerRight,
            child: Material(
              type: MaterialType.transparency,
              child: AnimatedBuilder(
                animation: ctrl,
                builder: (_, _) => _PortalProbeDetailCard(
                  portal: v,
                  probe: ctrl.portalProbeFor(v.key),
                  checking: ctrl.isPortalHealthChecking(v.key),
                ),
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(_detailOverlay!);
  }

  void _hideDetailCard() {
    _detailTimer?.cancel();
    _detailTimer = null;
    _detailOverlay?.remove();
    _detailOverlay = null;
  }

  Future<void> _copy() async {
    if (_sharing) return;

    if (_shareCode != null) {
      setState(() => _showShareCode = true);
      await Clipboard.setData(ClipboardData(text: _shareCode!));
      ForjaToast.success(
        'Share code copied',
        duration: const Duration(seconds: 2),
      );
      return;
    }

    setState(() => _sharing = true);
    try {
      final code = await IptvPortalShare.createShare(widget.portal.portal);
      if (!mounted) return;
      _shareCode = IptvPortalShare.formatCode(code);
      setState(() {
        _sharing = false;
        _showShareCode = true;
      });
      await Clipboard.setData(ClipboardData(text: _shareCode!));
      ForjaToast.success(
        'Share code copied',
        duration: const Duration(seconds: 2),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _sharing = false);
      ForjaToast.error('Could not create share code');
    }
  }

  void _askDelete() {
    setState(() => _confirmingDelete = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _confirmYesFocus.requestFocus();
    });
  }

  void _cancelDelete() {
    setState(() => _confirmingDelete = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _deleteFocus.requestFocus();
    });
  }

  Future<void> _confirmDelete() async {
    if (widget.ctrl.isDeletingPortal(widget.portal.key)) return;
    setState(() => _confirmingDelete = false);
    await widget.ctrl.deletePortal(widget.portal.key);
  }

  void _onRowTap() {
    if (_confirmingDelete) {
      _cancelDelete();
      return;
    }
    if (_showShareCode) {
      setState(() => _showShareCode = false);
      return;
    }
    final ctrl = widget.ctrl;
    if (ctrl.isNewPortal(widget.portal.key)) {
      ctrl.markPortalSeen(widget.portal.key);
    }
    ctrl.selectPortal(widget.portal);
  }

  PlayerSourceStatus _activePortalStatus({
    required bool checking,
    required bool? health,
  }) {
    if (checking) return PlayerSourceStatus.checking;
    if (health == false) return PlayerSourceStatus.failed;
    return PlayerSourceStatus.active;
  }

  Widget _activePortalStatusGlyph(PlayerSourceStatus status) {
    final color = playerSourceStatusColor(status);
    final Widget glyph = switch (status) {
      PlayerSourceStatus.active => Icon(
        Icons.play_circle_filled_rounded,
        color: color,
        size: _statusSlot,
      ),
      PlayerSourceStatus.failed => Icon(
        Icons.cancel_rounded,
        color: color,
        size: _statusSlot,
      ),
      PlayerSourceStatus.checking => SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 2, color: color),
      ),
      PlayerSourceStatus.ready => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      PlayerSourceStatus.unchecked => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    };
    return SizedBox(
      width: _statusSlot,
      height: _statusSlot,
      child: Center(child: glyph),
    );
  }

  Widget _idlePortalHealthDot({required bool checking, required bool? health}) {
    return SizedBox(
      width: _statusSlot,
      height: _statusSlot,
      child: Center(
        child: checking
            ? SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: playerSourceStatusColor(PlayerSourceStatus.checking),
                ),
              )
            : Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: health == true
                      ? playerSourceStatusColor(PlayerSourceStatus.active)
                      : health == false
                      ? playerSourceStatusColor(PlayerSourceStatus.failed)
                      : playerSourceStatusColor(PlayerSourceStatus.unchecked),
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.ctrl;
    final v = widget.portal;
    final isActive = widget.isActive;
    final deleting = ctrl.isDeletingPortal(v.key);
    final leanback = iptvLeanbackOnly(context);
    // Parent AnimatedBuilder(ctrl) already rebuilds on notify — no per-tile
    // ListenableBuilder (that doubled work on every health/status tick).
    final isFav = ctrl.isFavoritePortal(v.key);
    final isNew = ctrl.isNewPortal(v.key);
    // Leanback: star only when already favorited or action chrome is open (→).
    // `_focused` would flash the hover star on every ↑/↓ step.
    final showStar =
        !deleting && (_reveal || isFav || (!leanback && _focused));
    final showNewChrome =
        !deleting && isNew && !_reveal && !_showShareCode;
    final health = ctrl.portalHealthFor(v.key);
    final checking = ctrl.isPortalHealthChecking(v.key);
    final title = v.displayLabel;
    final railAnim = leanback
        ? Duration.zero
        : const Duration(milliseconds: 180);
    final reveal = deleting ? false : _reveal;

    final fillColor = leanback && _focused
        ? ForjaShellColors.brandGreen.withValues(alpha: 0.14)
        : isActive
            ? playerSourceStatusColor(
                PlayerSourceStatus.active,
              ).withValues(alpha: 0.07)
            : showNewChrome
                ? IptvShellStyle.accent.withValues(alpha: 0.1)
                : (_lineHover || _focused || _showShareCode)
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.transparent;

    Widget tile = ExcludeFocus(
      excluding: deleting,
      child: IgnorePointer(
        ignoring: deleting,
        child: Opacity(
          opacity: deleting ? 0.55 : 1,
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: fillColor,
                  border: showNewChrome
                      ? Border(
                          left: BorderSide(
                            color: IptvShellStyle.accent,
                            width: 3,
                          ),
                        )
                      : null,
                ),
                child: SizedBox(
                  height: _rowHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _buildPortalMainTap(
                          ctrl: ctrl,
                          v: v,
                          isActive: isActive,
                          isFav: isFav,
                          showStar: showStar,
                          showNewChrome: showNewChrome,
                          health: health,
                          checking: checking,
                          title: title,
                          instantStar: leanback,
                          deleting: deleting,
                        ),
                      ),
                      AnimatedContainer(
                        duration: railAnim,
                        curve: Curves.easeOutCubic,
                        width: reveal ? _actionW : 0,
                        height: _rowHeight,
                        child: !reveal
                            ? const SizedBox.shrink()
                            : ClipRect(
                                child: OverflowBox(
                                  minWidth: _actionW,
                                  maxWidth: _actionW,
                                  alignment: Alignment.centerRight,
                                  child: SizedBox(
                                    width: _actionW,
                                    height: _rowHeight,
                                    child: _buildActionRail(),
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              if (deleting)
                const Positioned.fill(
                  child: CustomPaint(painter: _PortalDeletingStripePainter()),
                ),
            ],
          ),
        ),
      ),
    );

    // Desktop hybrid still has D-pad focus — must keep MouseRegion for hover.
    if (!leanback) {
      tile = MouseRegion(
        onEnter: deleting
            ? null
            : (_) {
                setState(() => _lineHover = true);
                if (isNew) ctrl.markPortalSeen(v.key);
                ctrl.schedulePortalHealthCheck(v);
                _scheduleDetailCard();
              },
        onExit: deleting
            ? null
            : (_) {
                _clearHover();
                ctrl.cancelPortalHealthCheck(v.key);
              },
        child: tile,
      );
      tile = CompositedTransformTarget(link: _detailLink, child: tile);
    }

    // Only register the action row while revealed — itemCount 0↔4 on every
    // focus step was thrashing the TV focus graph during D-pad scroll.
    if (!reveal) return tile;
    return iptvCatalogRow(
      rowId: _actionsRowId,
      sortOrder: 200 + widget.listIndex,
      itemCount: _confirmingDelete ? 3 : 4,
      child: tile,
    );
  }

  Widget _buildPortalMainTap({
    required IptvController ctrl,
    required VerifiedPortal v,
    required bool isActive,
    required bool isFav,
    required bool showStar,
    required bool showNewChrome,
    required bool? health,
    required bool checking,
    required String title,
    required bool instantStar,
    required bool deleting,
  }) {
    return iptvTap(
      context: context,
      onTap: _onRowTap,
      borderRadius: 0,
      listIndex: widget.listIndex,
      tvRowId: 'portals',
      tvItemIndex: widget.listIndex,
      focusNode: _rowFocus,
      allowNestedFocus: iptvUseTvFocus(context) && !deleting,
      // Panel `_focusPortalAt` owns the jump. `.item` uses settings 240px
      // slack (snap-to-top) and fights the list jump — hover chrome flashes.
      ensureVisibleMode: ShellTvEnsureVisibleMode.off,
      onUpEdge: widget.onUpEdge,
      onDownEdge: widget.onDownEdge,
      onLeftEdge: _leftToPortalHeader,
      onRightEdge: () {
        if (deleting) return;
        // TV: open chrome on demand (row stays full-width while ↑/↓ scrolling).
        _focusAction(
          _confirmingDelete ? _confirmYesFocus : _favoriteFocus,
        );
      },
      onFocusChange: _onRowFocusChange,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.center,
              child: isActive
                  ? _activePortalStatusGlyph(
                      _activePortalStatus(
                        checking: checking,
                        health: health,
                      ),
                    )
                  : _idlePortalHealthDot(
                      checking: checking,
                      health: health,
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _confirmingDelete
                  ? _deleteConfirmLine()
                  : _showShareCode || _sharing
                  ? _shareCodeLine()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _expiryLine(v.expiry),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (showNewChrome) ...[
                              _newPortalBadge(),
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  color: isFav
                                      ? const Color(0xFFFBBF24)
                                      : isActive
                                      ? Colors.white
                                      : showNewChrome
                                      ? IptvShellStyle.accent
                                      : Colors.white.withValues(
                                          alpha: 0.88,
                                        ),
                                  fontSize: 13,
                                  fontWeight: isFav ||
                                          isActive ||
                                          showNewChrome
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  height: 1.25,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            _platformBadge(
                              v.portal.platform,
                              muted: showNewChrome,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                v.portal.url,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  color: showNewChrome
                                      ? Colors.white54
                                      : Colors.white38,
                                  fontSize: 11,
                                  height: 1.25,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        _seatsLine(
                          active: v.activeConnections,
                          max: v.maxConnections,
                        ),
                      ],
                    ),
            ),
            Align(
              alignment: Alignment.center,
              child: AnimatedOpacity(
                opacity: showStar ? 1 : 0,
                duration: instantStar
                    ? Duration.zero
                    : const Duration(milliseconds: 120),
                child: IgnorePointer(
                  ignoring: !showStar,
                  child: iptvTap(
                    context: context,
                    onTap: () => ctrl.toggleFavoritePortal(v.key),
                    borderRadius: 16,
                    focusNode: _favoriteFocus,
                    tvRowId: _actionsRowId,
                    tvItemIndex: 0,
                    onLeftEdge: () => _focusAction(_rowFocus),
                    onRightEdge: () => _focusAction(
                      _confirmingDelete ? _confirmYesFocus : _copyFocus,
                    ),
                    onUpEdge: _upFromActions,
                    onDownEdge: _downFromActions,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        // Favorited = solid gold. TV focus alone = yellow
                        // outline (not solid / not brand-green rail tint).
                        isFav
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 16,
                        color: isFav || _favoriteFocus.hasFocus
                            ? const Color(0xFFFBBF24)
                            : Colors.white30,
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

  Widget _buildActionRail() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: _confirmingDelete
          ? [
              _IptvRailAction(
                tooltip: 'Yes',
                icon: Icons.check_rounded,
                color: const Color(0xFFEF4444),
                onTap: _confirmDelete,
                focusNode: _confirmYesFocus,
                tvRowId: _actionsRowId,
                tvItemIndex: 1,
                onLeftEdge: () => _focusAction(_favoriteFocus),
                onRightEdge: () => _focusAction(_confirmNoFocus),
                onUpEdge: _upFromActions,
                onDownEdge: _downFromActions,
              ),
              _IptvRailAction(
                tooltip: 'No',
                icon: Icons.close_rounded,
                color: Colors.white60,
                onTap: _cancelDelete,
                focusNode: _confirmNoFocus,
                tvRowId: _actionsRowId,
                tvItemIndex: 2,
                onLeftEdge: () => _focusAction(_confirmYesFocus),
                onUpEdge: _upFromActions,
                onDownEdge: _downFromActions,
              ),
            ]
          : [
              _IptvRailAction(
                tooltip: 'Copy share code',
                icon: _sharing
                    ? Icons.hourglass_top_rounded
                    : Icons.copy_rounded,
                color: Colors.white60,
                onTap: _sharing ? null : _copy,
                focusNode: _copyFocus,
                tvRowId: _actionsRowId,
                tvItemIndex: 1,
                onLeftEdge: () => _focusAction(_favoriteFocus),
                onRightEdge: () => _focusAction(_editFocus),
                onUpEdge: _upFromActions,
                onDownEdge: _downFromActions,
              ),
              _IptvRailAction(
                tooltip: 'Edit',
                icon: Icons.edit_rounded,
                color: Colors.white60,
                onTap: widget.onEdit,
                focusNode: _editFocus,
                tvRowId: _actionsRowId,
                tvItemIndex: 2,
                onLeftEdge: () => _focusAction(_copyFocus),
                onRightEdge: () => _focusAction(_deleteFocus),
                onUpEdge: _upFromActions,
                onDownEdge: _downFromActions,
              ),
              _IptvRailAction(
                tooltip: 'Delete',
                icon: Icons.delete_rounded,
                color: const Color(0xFFEF4444),
                onTap: _askDelete,
                focusNode: _deleteFocus,
                tvRowId: _actionsRowId,
                tvItemIndex: 3,
                onLeftEdge: () => _focusAction(_editFocus),
                onUpEdge: _upFromActions,
                onDownEdge: _downFromActions,
              ),
            ],
    );
  }

  Widget _deleteConfirmLine() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        'Delete this portal?',
        style: GoogleFonts.plusJakartaSans(
          color: const Color(0xFFEF4444),
          fontSize: 13,
          fontWeight: FontWeight.w600,
          height: 1.25,
        ),
      ),
    );
  }

  Widget _shareCodeLine() {
    if (_sharing) {
      return Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: IptvShellStyle.accent,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Creating share code…',
            style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 12),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'SHARE CODE · TAP ROW TO HIDE',
          style: GoogleFonts.plusJakartaSans(
            color: IptvShellStyle.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _shareCode ?? '-',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.jetBrainsMono(
            color: IptvShellStyle.accent,
            fontSize: IptvPortalShare.isEmbeddedToken(_shareCode ?? '')
                ? 12
                : 18,
            fontWeight: FontWeight.w700,
            letterSpacing:
                IptvPortalShare.isEmbeddedToken(_shareCode ?? '') ? 0.4 : 2,
          ),
        ),
      ],
    );
  }

  Widget _expiryLine(String expiry) {
    final tone = _portalExpiryTone(expiry);
    return Row(
      children: [
        Icon(Icons.event_rounded, size: 12, color: tone.color),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            tone.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              color: tone.color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }

  Widget _seatsLine({required String active, required String max}) {
    final used = active.trim().isEmpty ? '0' : active.trim();
    final cap = max.trim().isEmpty ? '?' : max.trim();
    final activeN = int.tryParse(used);
    final maxN = int.tryParse(cap);
    final full = activeN != null && maxN != null && maxN > 0 && activeN >= maxN;
    // Blue = free capacity · gray = full (avoid expiry green/orange).
    final color = full ? const Color(0xFF9CA3AF) : const Color(0xFF60A5FA);
    return Row(
      children: [
        Icon(Icons.people_rounded, size: 12, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            '$used/$cap',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }

  Widget _newPortalBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: IptvShellStyle.accent.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: IptvShellStyle.accent.withValues(alpha: 0.5)),
      ),
      child: Text(
        'NEW',
        style: GoogleFonts.plusJakartaSans(
          color: IptvShellStyle.accent,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          height: 1,
        ),
      ),
    );
  }

  Widget _platformBadge(IptvPortalPlatform platform, {required bool muted}) {
    final label = switch (platform) {
      IptvPortalPlatform.xtream => 'Xtream',
      IptvPortalPlatform.m3u => 'M3U',
      IptvPortalPlatform.stalker => 'Stalker',
    };
    final color = muted ? Colors.white54 : Colors.white38;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          height: 1,
        ),
      ),
    );
  }

}

/// Diagonal hatch overlay for a portal row mid-delete.
class _PortalDeletingStripePainter extends CustomPainter {
  const _PortalDeletingStripePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;
    const spacing = 12.0;
    for (double x = -size.height; x < size.width + size.height; x += spacing) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PortalDeletingStripePainter oldDelegate) =>
      false;
}

class _IptvRailAction extends StatefulWidget {
  const _IptvRailAction({
    required this.tooltip,
    required this.icon,
    required this.color,
    this.onTap,
    this.focusNode,
    this.tvRowId,
    this.tvItemIndex,
    this.onLeftEdge,
    this.onRightEdge,
    this.onUpEdge,
    this.onDownEdge,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final String? tvRowId;
  final int? tvItemIndex;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;
  final VoidCallback? onUpEdge;
  final VoidCallback? onDownEdge;

  @override
  State<_IptvRailAction> createState() => _IptvRailActionState();
}

class _IptvRailActionState extends State<_IptvRailAction> {
  bool _focused = false;
  bool _hovered = false;

  bool get _active =>
      iptvFocusActive(context, hovered: _hovered, focused: _focused);

  @override
  Widget build(BuildContext context) {
    final tvFocused = iptvTvFocused(context, focused: _focused);
    final fg = iptvFocusFg(
      widget.color,
      active: _active,
      tvFocused: tvFocused,
    );
    final child = SizedBox(
      width: 32,
      height: 32,
      child: Icon(widget.icon, size: 16, color: fg),
    );
    if (iptvUseTvFocus(context)) {
      return Tooltip(
        message: widget.tooltip,
        child: iptvTap(
          context: context,
          onTap: widget.onTap,
          borderRadius: 6,
          focusNode: widget.focusNode,
          tvRowId: widget.tvRowId,
          tvItemIndex: widget.tvItemIndex,
          onLeftEdge: widget.onLeftEdge,
          onRightEdge: widget.onRightEdge,
          onUpEdge: widget.onUpEdge,
          onDownEdge: widget.onDownEdge,
          onFocusChange: (focused) => setState(() => _focused = focused),
          onHoverChange: (hovered) => setState(() => _hovered = hovered),
          child: child,
        ),
      );
    }
    return Tooltip(
      message: widget.tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(6),
          child: child,
        ),
      ),
    );
  }
}

/// Desktop hover detail — compact like [IptvGuideEpgCard] floating peek.
class _PortalProbeDetailCard extends StatelessWidget {
  const _PortalProbeDetailCard({
    required this.portal,
    required this.probe,
    required this.checking,
  });

  final VerifiedPortal portal;
  final PortalProbeResult? probe;
  final bool checking;

  static const _cardW = 280.0;

  @override
  Widget build(BuildContext context) {
    final p = probe;
    final server = p?.server ?? const PortalServerInfo();
    final status = checking && p == null
        ? 'Checking…'
        : (p?.statusLabel ?? 'Not checked');
    final statusColor = p == null
        ? Colors.white54
        : p.alive
            ? ForjaShellColors.brandGreen
            : const Color(0xFFEF4444);

    final expiry = (p != null && p.expiry.isNotEmpty && p.expiry != 'Unknown')
        ? p.expiry
        : portal.expiry;
    final seatsActive = (p != null && p.activeConnections.isNotEmpty)
        ? p.activeConnections
        : portal.activeConnections;
    final seatsMax = (p != null && p.maxConnections.isNotEmpty)
        ? p.maxConnections
        : portal.maxConnections;

    final platformLabel = switch (portal.platform) {
      IptvPortalPlatform.xtream => 'Xtream',
      IptvPortalPlatform.m3u => 'M3U',
      IptvPortalPlatform.stalker => 'Stalker',
    };

    final lines = <(String, String)>[
      ('Platform', platformLabel),
      ('URL', _shortUrl(portal.portal.url)),
      if (expiry.isNotEmpty) ('Expires', expiry),
      if (seatsMax.isNotEmpty) ('Seats', '$seatsActive / $seatsMax'),
    ];
    if (p != null && p.message.trim().isNotEmpty) {
      lines.add(('Message', p.message.trim()));
    }
    if (server.protocol.isNotEmpty) {
      lines.add(('Protocol', server.protocol));
    }
    final ports = <String>[
      if (server.port.isNotEmpty) server.port,
      if (server.httpsPort.isNotEmpty) 'https ${server.httpsPort}',
      if (server.rtmpPort.isNotEmpty) 'rtmp ${server.rtmpPort}',
    ];
    if (ports.isNotEmpty) lines.add(('Ports', ports.join(' · ')));
    if (server.timezone.isNotEmpty) {
      lines.add(('Timezone', server.timezone));
    }

    return IgnorePointer(
      child: SizedBox(
        width: _cardW,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ForjaFrostedPanel(
            enableBlur: true,
            blurSigma: 28,
            border: null,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    portal.displayLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (var i = 0; i < lines.length; i++) ...[
                    if (i > 0) const SizedBox(height: 4),
                    _detailRow(lines[i].$1, lines[i].$2),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _shortUrl(String raw) {
    final t = raw.trim();
    if (t.length <= 42) return t;
    return '${t.substring(0, 40)}…';
  }

  Widget _detailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 68,
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
