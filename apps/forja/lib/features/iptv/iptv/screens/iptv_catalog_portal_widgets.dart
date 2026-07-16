part of 'iptv_catalog_workspace.dart';

class _IptvPortalDialogField extends StatefulWidget {
  const _IptvPortalDialogField({
    required this.controller,
    required this.focusNode,
    required this.onArrowUp,
    required this.onArrowDown,
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

  bool get _tvBrowse => iptvUseTvFocus(context) && !_editing;

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
    final tv = iptvUseTvFocus(context);
    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      obscureText: widget.obscureText,
      readOnly: tv && !_editing,
      enableInteractiveSelection: !tv || _editing,
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
  });

  final VerifiedPortal portal;
  final IptvController ctrl;
  final bool isActive;
  final int listIndex;
  final VoidCallback onEdit;
  final VoidCallback? onUpEdge;

  @override
  State<_PortalHoverTile> createState() => _PortalHoverTileState();
}

class _PortalHoverTileState extends State<_PortalHoverTile> {
  static const _actionW = 108.0;
  static const _statusSlot = 18.0;
  static const _rowH = 98.0;

  bool _lineHover = false;
  bool _focused = false;
  bool _sharing = false;
  bool _showShareCode = false;
  String? _shareCode;
  late final FocusNode _favoriteFocus;
  late final FocusNode _copyFocus;
  late final FocusNode _editFocus;
  late final FocusNode _deleteFocus;

  bool get _reveal => _focused || _lineHover;

  double get _rowHeight => _rowH;

  @override
  void initState() {
    super.initState();
    _favoriteFocus = FocusNode(debugLabel: 'iptv-portal-favorite');
    _copyFocus = FocusNode(debugLabel: 'iptv-portal-copy');
    _editFocus = FocusNode(debugLabel: 'iptv-portal-edit');
    _deleteFocus = FocusNode(debugLabel: 'iptv-portal-delete');
  }

  @override
  void dispose() {
    _favoriteFocus.dispose();
    _copyFocus.dispose();
    _editFocus.dispose();
    _deleteFocus.dispose();
    super.dispose();
  }

  void _focusCatalogFromPanel() {
    iptvFocusBrowserCategories(widget.ctrl);
  }

  String get _actionsRowId => 'portal-${widget.listIndex}-actions';

  void _clearHover() {
    setState(() => _lineHover = false);
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
      _shareCode = code;
      setState(() {
        _sharing = false;
        _showShareCode = true;
      });
      await Clipboard.setData(ClipboardData(text: code));
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

  void _onRowTap() {
    if (_showShareCode) {
      setState(() => _showShareCode = false);
      return;
    }
    widget.ctrl.selectPortal(widget.portal);
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
            ? const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: Colors.white54,
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

    return ListenableBuilder(
      listenable: ctrl,
      builder: (context, _) {
        final isFav = ctrl.isFavoritePortal(v.key);
        final isNew = ctrl.isNewPortal(v.key);
        final showNewChrome = isNew && !_reveal && !_showShareCode;
        final health = ctrl.portalHealthFor(v.key);
        final checking = ctrl.isPortalHealthChecking(v.key);
        final title = v.displayLabel;

        if (_reveal) {
          iptvSyncRow(
            rowId: _actionsRowId,
            sortOrder: 200 + widget.listIndex,
            itemCount: 4,
          );
        }

        return MouseRegion(
          onEnter: (_) {
            setState(() => _lineHover = true);
            if (isNew) ctrl.markPortalSeen(v.key);
            ctrl.schedulePortalHealthCheck(v);
          },
          onExit: (_) {
            _clearHover();
            ctrl.cancelPortalHealthCheck(v.key);
          },
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isActive
                  ? playerSourceStatusColor(
                      PlayerSourceStatus.active,
                    ).withValues(alpha: 0.07)
                  : showNewChrome
                  ? IptvShellStyle.accent.withValues(alpha: 0.1)
                  : (_lineHover || _focused || _showShareCode)
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.transparent,
              border: showNewChrome
                  ? Border(
                      left: BorderSide(color: IptvShellStyle.accent, width: 3),
                    )
                  : null,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              height: _rowHeight,
              alignment: Alignment.topCenter,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: iptvTap(
                      context: context,
                      onTap: _onRowTap,
                      borderRadius: 0,
                      listIndex: widget.listIndex,
                      tvRowId: 'portals',
                      tvItemIndex: widget.listIndex,
                      onUpEdge: widget.onUpEdge,
                      onLeftEdge: _reveal
                          ? () => _favoriteFocus.requestFocus()
                          : _focusCatalogFromPanel,
                      onRightEdge: _reveal
                          ? () => _copyFocus.requestFocus()
                          : null,
                      onFocusChange: (focused) {
                        setState(() => _focused = focused);
                        if (focused) {
                          if (ctrl.isNewPortal(v.key)) {
                            ctrl.markPortalSeen(v.key);
                          }
                          ctrl.schedulePortalHealthCheck(v);
                        } else {
                          ctrl.cancelPortalHealthCheck(v.key);
                        }
                      },
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
                              child: _showShareCode || _sharing
                                  ? _shareCodeLine()
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
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
                                        Text(
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
                              child: iptvTap(
                                context: context,
                                onTap: () => ctrl.toggleFavoritePortal(v.key),
                                borderRadius: 16,
                                focusNode: _favoriteFocus,
                                tvRowId: _actionsRowId,
                                tvItemIndex: 0,
                                onLeftEdge: _focusCatalogFromPanel,
                                onRightEdge: _reveal
                                    ? () => _copyFocus.requestFocus()
                                    : null,
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    isFav
                                        ? Icons.star_rounded
                                        : Icons.star_outline_rounded,
                                    size: 16,
                                    color: isFav
                                        ? const Color(0xFFFBBF24)
                                        : Colors.white30,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    width: _reveal ? _actionW : 0,
                    height: _rowHeight,
                    child: ClipRect(
                      child: OverflowBox(
                        minWidth: _actionW,
                        maxWidth: _actionW,
                        alignment: Alignment.centerRight,
                        child: SizedBox(
                          width: _actionW,
                          height: _rowHeight,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
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
                                onLeftEdge: () => _favoriteFocus.requestFocus(),
                                onRightEdge: () => _editFocus.requestFocus(),
                              ),
                              _IptvRailAction(
                                tooltip: 'Edit',
                                icon: Icons.edit_rounded,
                                color: Colors.white60,
                                onTap: widget.onEdit,
                                focusNode: _editFocus,
                                tvRowId: _actionsRowId,
                                tvItemIndex: 2,
                                onLeftEdge: () => _copyFocus.requestFocus(),
                                onRightEdge: () => _deleteFocus.requestFocus(),
                              ),
                              _IptvRailAction(
                                tooltip: 'Delete',
                                icon: Icons.delete_rounded,
                                color: const Color(0xFFEF4444),
                                onTap: () => ctrl.deletePortal(v.key),
                                focusNode: _deleteFocus,
                                tvRowId: _actionsRowId,
                                tvItemIndex: 3,
                                onLeftEdge: () => _editFocus.requestFocus(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
          _shareCode ?? '—',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.jetBrainsMono(
            color: IptvShellStyle.accent,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
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
    // Blue = free capacity · gray = full (avoid expiry green/amber).
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
