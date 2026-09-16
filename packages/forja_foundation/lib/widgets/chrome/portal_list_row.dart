import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/widgets/chrome/portal_list_panel.dart';
import 'package:forja_foundation/widgets/chrome/portal_probe_detail_card.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:google_fonts/google_fonts.dart';

/// Matches [PortalListView.portalsRowId] — keep in sync (avoid import cycle).
const _kPortalsRowId = 'portals';


/// Presentational portal inventory row — props / callbacks only (RFC-095).
///
/// Visual parity with the former IPTV Portals panel tile: 98px card, health
/// glyph, expiry / title / platform+URL / seats, hover action rail.
///
/// When [tvTabId] is set, the row + action chrome register via [ShellPaintScope].
class PortalListRow extends StatefulWidget {
  const PortalListRow({
    super.key,
    required this.item,
    this.leanback = false,
    this.tvTabId,
    this.listIndex = 0,
    this.height = rowHeight,
    this.actionWidth = 108,
    this.fontSize = 13,
    this.metaFontSize = 11,
    this.onSelect,
    this.onFavorite,
    this.onEdit,
    this.onDelete,
    this.onCopyShareCode,
    this.onHoverEnter,
    this.onHoverExit,
    this.onUpEdge,
    this.onDownEdge,
    this.onLeftEdge,
    this.onTvFocus,
  });

  static const rowHeight = 98.0;

  final PortalListItem item;
  final bool leanback;
  final String? tvTabId;
  final int listIndex;
  final double height;
  final double actionWidth;
  final double fontSize;
  final double metaFontSize;
  final VoidCallback? onSelect;
  final VoidCallback? onFavorite;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final Future<String?> Function()? onCopyShareCode;
  final VoidCallback? onHoverEnter;
  final VoidCallback? onHoverExit;
  final VoidCallback? onUpEdge;
  final VoidCallback? onDownEdge;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onTvFocus;

  @override
  State<PortalListRow> createState() => _PortalListRowState();
}

class _PortalListRowState extends State<PortalListRow> {
  static const _statusSlot = 18.0;
  static const _detailHoverDelay = Duration(seconds: 1);

  bool _lineHover = false;
  bool _focused = false;
  bool _sharing = false;
  bool _showShareCode = false;
  bool _confirmingDelete = false;
  String? _shareCode;

  final LayerLink _detailLink = LayerLink();
  Timer? _detailTimer;
  OverlayEntry? _detailOverlay;

  late final FocusNode _rowFocus;
  late final FocusNode _favoriteFocus;
  late final FocusNode _copyFocus;
  late final FocusNode _editFocus;
  late final FocusNode _deleteFocus;
  late final FocusNode _confirmYesFocus;
  late final FocusNode _confirmNoFocus;

  PortalListItem get item => widget.item;

  bool get _tv =>
      (widget.tvTabId ?? '').trim().isNotEmpty &&
      ShellPaintScope.useTvFocusOf(context);

  bool get _actionChromeFocused =>
      _favoriteFocus.hasFocus ||
      _copyFocus.hasFocus ||
      _editFocus.hasFocus ||
      _deleteFocus.hasFocus ||
      _confirmYesFocus.hasFocus ||
      _confirmNoFocus.hasFocus;

  /// Leanback: keep rail closed while ↑/↓ skims — open only on → / action focus.
  bool get _reveal {
    if (_confirmingDelete || _actionChromeFocused) return true;
    if (_lineHover) return true;
    if (!widget.leanback &&
        ShellPaintScope.focusStyledOf(context, focused: _focused)) {
      return true;
    }
    return false;
  }

  bool get _showStar {
    if (item.deleting) return false;
    return _reveal ||
        item.favorite ||
        (!widget.leanback &&
            ShellPaintScope.focusStyledOf(context, focused: _focused));
  }

  bool get _showNewChrome =>
      !item.deleting && item.isNew && !_reveal && !_showShareCode;

  String get _actionsRowId => 'portal-${widget.listIndex}-actions';

  @override
  void initState() {
    super.initState();
    _rowFocus = FocusNode(debugLabel: 'portal-row');
    _favoriteFocus = FocusNode(debugLabel: 'portal-favorite');
    _copyFocus = FocusNode(debugLabel: 'portal-copy');
    _editFocus = FocusNode(debugLabel: 'portal-edit');
    _deleteFocus = FocusNode(debugLabel: 'portal-delete');
    _confirmYesFocus = FocusNode(debugLabel: 'portal-delete-yes');
    _confirmNoFocus = FocusNode(debugLabel: 'portal-delete-no');
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
  void didUpdateWidget(covariant PortalListRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_detailOverlay == null) return;
    // OverlayEntry lives under Overlay, not this row. Sync markNeedsBuild
    // during list rebuild asserts "wrong build scope" and poisons Tooltips.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final entry = _detailOverlay;
      if (entry == null) return;
      if (!entry.mounted) {
        _detailOverlay = null;
        return;
      }
      entry.markNeedsBuild();
    });
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

  void _clearHover() {
    setState(() => _lineHover = false);
    _hideDetailCard();
  }

  void _scheduleDetailCard() {
    if (widget.leanback) return;
    _detailTimer?.cancel();
    _detailTimer = Timer(_detailHoverDelay, () {
      if (!mounted || !_lineHover) return;
      _showDetailCard();
    });
  }

  void _showDetailCard() {
    if (widget.leanback) return;
    final existing = _detailOverlay;
    if (existing != null) {
      if (!existing.mounted) {
        _detailOverlay = null;
      } else {
        // Defer — may be called from hover mid-parent rebuild.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final entry = _detailOverlay;
          if (entry == null || !entry.mounted) {
            _detailOverlay = null;
            return;
          }
          entry.markNeedsBuild();
        });
        return;
      }
    }
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) {
        // UnconstrainedBox: Overlay gives max constraints; without this the
        // card expands into a full-screen slab.
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
              child: PortalProbeDetailCard(item: item),
            ),
          ),
        );
      },
    );
    _detailOverlay = entry;
    overlay.insert(entry);
  }

  void _hideDetailCard() {
    _detailTimer?.cancel();
    _detailTimer = null;
    final entry = _detailOverlay;
    _detailOverlay = null;
    if (entry == null) return;
    if (entry.mounted) {
      entry.remove();
    }
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

  void _onRowFocusChange(bool focused) {
    if (focused) {
      widget.onTvFocus?.call();
      if (widget.leanback) {
        widget.onHoverEnter?.call();
      }
      if (!_focused || widget.leanback) {
        setState(() => _focused = true);
      }
      return;
    }
    void clear() {
      if (!mounted) return;
      if (_focused) setState(() => _focused = false);
      if (widget.leanback) widget.onHoverExit?.call();
    }

    if (widget.leanback) {
      clear();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => clear());
  }

  Future<void> _copy() async {
    final request = widget.onCopyShareCode;
    if (request == null || _sharing) return;
    if (_shareCode != null) {
      setState(() => _showShareCode = true);
      await Clipboard.setData(ClipboardData(text: _shareCode!));
      return;
    }
    setState(() => _sharing = true);
    try {
      final code = await request();
      if (!mounted) return;
      final trimmed = (code ?? '').trim();
      if (trimmed.isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: trimmed));
      }
      setState(() {
        _sharing = false;
        _shareCode = trimmed.isEmpty ? null : trimmed;
        _showShareCode = _shareCode != null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _sharing = false);
    }
  }

  void _onRowTap() {
    if (_confirmingDelete) {
      setState(() => _confirmingDelete = false);
      return;
    }
    if (_showShareCode) {
      setState(() => _showShareCode = false);
      return;
    }
    widget.onSelect?.call();
  }

  Color _healthColor({required bool checking, required bool? health}) {
    if (checking) return const Color(0xFF38BDF8);
    if (health == true) return ForjaShellColors.brandGreen;
    if (health == false) return const Color(0xFFEF4444);
    return const Color(0x3DFFFFFF);
  }

  Color _selectedStatusColor({required bool checking, required bool? health}) {
    if (checking) return const Color(0xFF38BDF8);
    if (health == false) return const Color(0xFFEF4444);
    return ForjaShellColors.brandGreen;
  }

  @override
  Widget build(BuildContext context) {
    final deleting = item.deleting;
    final isActive = item.selected;
    final reveal = _reveal;
    final railAnim =
        widget.leanback ? Duration.zero : const Duration(milliseconds: 180);

    final fillColor = widget.leanback && _focused
        ? ForjaShellColors.brandGreen.withValues(alpha: 0.14)
        : isActive
            ? ForjaShellColors.brandGreen.withValues(alpha: 0.07)
            : _showNewChrome
                ? ForjaShellColors.navUnderline.withValues(alpha: 0.1)
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
                  border: _showNewChrome
                      ? const Border(
                          left: BorderSide(
                            color: ForjaShellColors.navUnderline,
                            width: 3,
                          ),
                        )
                      : null,
                ),
                child: SizedBox(
                  height: widget.height,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _buildMain()),
                      AnimatedContainer(
                        duration: railAnim,
                        curve: Curves.easeOutCubic,
                        width: reveal ? widget.actionWidth : 0,
                        height: widget.height,
                        child: !reveal
                            ? const SizedBox.shrink()
                            : ClipRect(
                                child: OverflowBox(
                                  minWidth: widget.actionWidth,
                                  maxWidth: widget.actionWidth,
                                  alignment: Alignment.centerRight,
                                  child: SizedBox(
                                    width: widget.actionWidth,
                                    height: widget.height,
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
                  child: CustomPaint(painter: _DeletingStripePainter()),
                ),
            ],
          ),
        ),
      ),
    );

    if (!widget.leanback) {
      tile = MouseRegion(
        onEnter: deleting
            ? null
            : (_) {
                setState(() => _lineHover = true);
                widget.onHoverEnter?.call();
                _scheduleDetailCard();
              },
        onExit: deleting
            ? null
            : (_) {
                _clearHover();
                widget.onHoverExit?.call();
              },
        child: tile,
      );
      tile = CompositedTransformTarget(link: _detailLink, child: tile);
    }

    if (_tv && reveal) {
      final tab = widget.tvTabId!.trim();
      tile = ShellPaintScope.tvRow(
        context: context,
        tabId: tab,
        rowId: _actionsRowId,
        sortOrder: 200 + widget.listIndex,
        itemCount: _confirmingDelete ? 3 : 4,
        child: tile,
      );
    }

    return tile;
  }

  Widget _buildMain() {
    final isActive = item.selected;
    final isFav = item.favorite;
    final title = item.label;
    final checking = item.checking;
    final health = item.healthy;
    final tab = (widget.tvTabId ?? '').trim();
    final deleting = item.deleting;

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.center,
            child: isActive
                ? _activeGlyph(checking: checking, health: health)
                : _idleDot(checking: checking, health: health),
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
                          _expiryLine(item.expiry),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              if (_showNewChrome) ...[
                                _newBadge(),
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
                                            : _showNewChrome
                                                ? ForjaShellColors.navUnderline
                                                : Colors.white.withValues(
                                                    alpha: 0.88,
                                                  ),
                                    fontSize: widget.fontSize,
                                    fontWeight: isFav ||
                                            isActive ||
                                            _showNewChrome
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
                              if ((item.platformLabel ?? '')
                                  .trim()
                                  .isNotEmpty) ...[
                                _platformBadge(
                                  item.platformLabel!.trim(),
                                  muted: _showNewChrome,
                                ),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                child: Text(
                                  item.subtitle ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: _showNewChrome
                                        ? Colors.white54
                                        : Colors.white38,
                                    fontSize: widget.metaFontSize,
                                    height: 1.25,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          _seatsLine(
                            active: item.activeConnections,
                            max: item.maxConnections,
                          ),
                        ],
                      ),
          ),
          Align(
            alignment: Alignment.center,
            child: AnimatedOpacity(
              opacity: _showStar ? 1 : 0,
              duration: widget.leanback
                  ? Duration.zero
                  : const Duration(milliseconds: 120),
              child: IgnorePointer(
                ignoring: !_showStar || widget.onFavorite == null,
                child: _tv
                    ? ShellPaintScope.focusableTap(
                        context: context,
                        onTap: widget.onFavorite,
                        borderRadius: 16,
                        scaleOnFocus: 1.0,
                        showFocusFill: false,
                        suppressInkHover: true,
                        focusNode: _favoriteFocus,
                        tvTabId: tab,
                        tvRowId: _actionsRowId,
                        tvItemIndex: 0,
                        ensureVisibleMode: ShellPaintEnsureVisible.off,
                        onLeftEdge: () => _focusAction(_rowFocus),
                        onRightEdge: () => _focusAction(
                          _confirmingDelete ? _confirmYesFocus : _copyFocus,
                        ),
                        onUpEdge: widget.onUpEdge,
                        onDownEdge: widget.onDownEdge,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            isFav
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 16,
                            color: isFav || _favoriteFocus.hasFocus
                                ? const Color(0xFFFBBF24)
                                : Colors.white30,
                          ),
                        ),
                      )
                    : IconButton(
                        tooltip: isFav ? 'Unfavorite' : 'Favorite',
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        onPressed: widget.onFavorite,
                        icon: Icon(
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
          ),
        ],
      ),
    );

    if (_tv) {
      return ShellPaintScope.focusableTap(
        context: context,
        onTap: _onRowTap,
        borderRadius: 0,
        scaleOnFocus: 1.0,
        showFocusFill: false,
        suppressInkHover: true,
        focusNode: _rowFocus,
        listIndex: widget.listIndex,
        tvTabId: tab,
        tvRowId: _kPortalsRowId,
        tvItemIndex: widget.listIndex,
        tvZone: ShellPaintTvZone.row,
        allowNestedFocus: !deleting,
        ensureVisibleMode: ShellPaintEnsureVisible.off,
        onUpEdge: widget.onUpEdge,
        onDownEdge: widget.onDownEdge,
        onLeftEdge: widget.onLeftEdge,
        onRightEdge: deleting
            ? null
            : () => _focusAction(
                  _confirmingDelete ? _confirmYesFocus : _favoriteFocus,
                ),
        onFocusChange: _onRowFocusChange,
        child: content,
      );
    }

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: _onRowTap,
        child: content,
      ),
    );
  }

  Widget _buildActionRail() {
    if (_confirmingDelete) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _RailAction(
            tooltip: 'Yes',
            icon: Icons.check_rounded,
            color: const Color(0xFFEF4444),
            onTap: () {
              setState(() => _confirmingDelete = false);
              widget.onDelete?.call();
            },
            tvTabId: _tv ? widget.tvTabId : null,
            tvRowId: _actionsRowId,
            tvItemIndex: 1,
            focusNode: _confirmYesFocus,
            onLeftEdge: () => _focusAction(_favoriteFocus),
            onRightEdge: () => _focusAction(_confirmNoFocus),
            onUpEdge: widget.onUpEdge,
            onDownEdge: widget.onDownEdge,
          ),
          _RailAction(
            tooltip: 'No',
            icon: Icons.close_rounded,
            color: Colors.white60,
            onTap: () => setState(() => _confirmingDelete = false),
            tvTabId: _tv ? widget.tvTabId : null,
            tvRowId: _actionsRowId,
            tvItemIndex: 2,
            focusNode: _confirmNoFocus,
            onLeftEdge: () => _focusAction(_confirmYesFocus),
            onUpEdge: widget.onUpEdge,
            onDownEdge: widget.onDownEdge,
          ),
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (widget.onCopyShareCode != null)
          _RailAction(
            tooltip: 'Copy share code',
            icon: _sharing
                ? Icons.hourglass_top_rounded
                : Icons.copy_rounded,
            color: Colors.white60,
            onTap: _sharing ? null : () => unawaited(_copy()),
            tvTabId: _tv ? widget.tvTabId : null,
            tvRowId: _actionsRowId,
            tvItemIndex: 1,
            focusNode: _copyFocus,
            onLeftEdge: () => _focusAction(_favoriteFocus),
            onRightEdge: () => _focusAction(_editFocus),
            onUpEdge: widget.onUpEdge,
            onDownEdge: widget.onDownEdge,
          ),
        if (widget.onEdit != null)
          _RailAction(
            tooltip: 'Edit',
            icon: Icons.edit_rounded,
            color: Colors.white60,
            onTap: widget.onEdit,
            tvTabId: _tv ? widget.tvTabId : null,
            tvRowId: _actionsRowId,
            tvItemIndex: 2,
            focusNode: _editFocus,
            onLeftEdge: () => _focusAction(_copyFocus),
            onRightEdge: () => _focusAction(_deleteFocus),
            onUpEdge: widget.onUpEdge,
            onDownEdge: widget.onDownEdge,
          ),
        if (widget.onDelete != null)
          _RailAction(
            tooltip: 'Delete',
            icon: Icons.delete_rounded,
            color: const Color(0xFFEF4444),
            onTap: () => setState(() => _confirmingDelete = true),
            tvTabId: _tv ? widget.tvTabId : null,
            tvRowId: _actionsRowId,
            tvItemIndex: 3,
            focusNode: _deleteFocus,
            onLeftEdge: () => _focusAction(_editFocus),
            onUpEdge: widget.onUpEdge,
            onDownEdge: widget.onDownEdge,
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
          fontSize: widget.fontSize,
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
              color: ForjaShellColors.brandGreen,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Creating share code…',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
        ],
      );
    }
    final code = _shareCode ?? '-';
    final dense = code.length > 12;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'SHARE CODE · TAP ROW TO HIDE',
          style: GoogleFonts.plusJakartaSans(
            color: ForjaShellColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          code,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.jetBrainsMono(
            color: ForjaShellColors.brandGreen,
            fontSize: dense ? 12 : 18,
            fontWeight: FontWeight.w700,
            letterSpacing: dense ? 0.4 : 2,
          ),
        ),
      ],
    );
  }

  Widget _expiryLine(String? expiry) {
    final tone = portalExpiryTone(expiry);
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
              fontSize: widget.metaFontSize,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }

  Widget _seatsLine({String? active, String? max}) {
    final used = _seatToken(active, fallback: '0');
    final cap = _seatToken(max, fallback: '?');
    final activeN = int.tryParse(used);
    final maxN = int.tryParse(cap);
    final full =
        activeN != null && maxN != null && maxN > 0 && activeN >= maxN;
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
              fontSize: widget.metaFontSize,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }

  static String _seatToken(String? raw, {required String fallback}) {
    final s = (raw ?? '').trim();
    if (s.isEmpty || s == 'null' || s == 'undefined') return fallback;
    return s;
  }

  Widget _newBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: ForjaShellColors.navUnderline.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: ForjaShellColors.navUnderline.withValues(alpha: 0.5),
        ),
      ),
      child: Text(
        'NEW',
        style: GoogleFonts.plusJakartaSans(
          color: ForjaShellColors.navUnderline,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          height: 1,
        ),
      ),
    );
  }

  Widget _platformBadge(String label, {required bool muted}) {
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

  Widget _idleDot({required bool checking, required bool? health}) {
    final color = _healthColor(checking: checking, health: health);
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
                  color: color,
                ),
              )
            : Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                ),
              ),
      ),
    );
  }

  Widget _activeGlyph({required bool checking, required bool? health}) {
    final color = _selectedStatusColor(checking: checking, health: health);
    final Widget glyph;
    if (checking) {
      glyph = SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 2, color: color),
      );
    } else if (health == false) {
      glyph = Icon(Icons.cancel_rounded, color: color, size: _statusSlot);
    } else {
      glyph = Icon(
        Icons.play_circle_filled_rounded,
        color: color,
        size: _statusSlot,
      );
    }
    return SizedBox(
      width: _statusSlot,
      height: _statusSlot,
      child: Center(child: glyph),
    );
  }
}

/// Expiry label + color for portal rows (paint only).
///
/// Parity with classic IPTV panel / host [PortalExpiry.parse]: green / orange /
/// red from days left. Parses `16 Feb 2027`, unix, DD/MM/YYYY, ISO, trailing `*`.
({Color color, String label}) portalExpiryTone(String? expiry) {
  final raw = (expiry ?? '').trim();
  final label = raw.isEmpty ? 'Unknown' : raw;
  final end = _tryParseExpiry(label);
  if (end == null) {
    return (
      color: const Color(0xFF9CA3AF),
      label: label == 'Unknown' ? 'Ends: Unknown' : 'Ends: $label',
    );
  }
  final today = DateTime.now();
  final midnight = DateTime(today.year, today.month, today.day);
  final days = end.difference(midnight).inDays;
  // Orange for soon — not amber/gold (favorite star).
  final Color color;
  if (days < 0) {
    color = const Color(0xFFEF4444);
  } else if (days <= 7) {
    color = const Color(0xFFF97316);
  } else if (days <= 30) {
    color = const Color(0xFFFB923C);
  } else {
    color = const Color(0xFF22C55E);
  }
  final prefix = days < 0 ? 'Expired' : 'Ends';
  return (color: color, label: '$prefix $label');
}

const _expiryMonthIndex = <String, int>{
  'jan': 1,
  'january': 1,
  'feb': 2,
  'february': 2,
  'mar': 3,
  'march': 3,
  'apr': 4,
  'april': 4,
  'may': 5,
  'jun': 6,
  'june': 6,
  'jul': 7,
  'july': 7,
  'aug': 8,
  'august': 8,
  'sep': 9,
  'september': 9,
  'oct': 10,
  'october': 10,
  'nov': 11,
  'november': 11,
  'dec': 12,
  'december': 12,
};

DateTime? _tryParseExpiry(String raw) {
  final s = raw.trim().replaceFirst(RegExp(r'\*+$'), '').trim();
  if (s.isEmpty || s.toLowerCase() == 'unknown') return null;

  if (RegExp(r'^\d+$').hasMatch(s)) {
    final n = int.tryParse(s);
    if (n == null) return null;
    final ms = n > 1000000000000 ? n : n * 1000;
    try {
      final d = DateTime.fromMillisecondsSinceEpoch(ms);
      return d.year <= 1970 ? null : DateTime(d.year, d.month, d.day);
    } catch (_) {
      return null;
    }
  }

  // `24/01/2027 19:55:57` (DD/MM/YYYY).
  final dmy = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})').firstMatch(s);
  if (dmy != null) {
    final day = int.tryParse(dmy.group(1)!);
    final month = int.tryParse(dmy.group(2)!);
    final year = int.tryParse(dmy.group(3)!);
    if (day != null &&
        month != null &&
        year != null &&
        year > 1970 &&
        month >= 1 &&
        month <= 12 &&
        day >= 1 &&
        day <= 31) {
      return DateTime(year, month, day);
    }
  }

  // `16 Feb 2027` / `16 February 2027` (host PortalExpiry.format).
  final parts = s.split(RegExp(r'\s+'));
  if (parts.length == 3) {
    final day = int.tryParse(parts[0]);
    final month = _expiryMonthIndex[parts[1].toLowerCase()];
    final year = int.tryParse(parts[2]);
    if (day != null && month != null && year != null && year > 1970) {
      return DateTime(year, month, day);
    }
  }

  // `February 16, 2027` / `Feb 16 2027`
  final eng = RegExp(r'^([A-Za-z]+)\s+(\d{1,2}),?\s+(\d{4})').firstMatch(s);
  if (eng != null) {
    final month = _expiryMonthIndex[eng.group(1)!.toLowerCase()];
    final day = int.tryParse(eng.group(2)!);
    final year = int.tryParse(eng.group(3)!);
    if (day != null && month != null && year != null && year > 1970) {
      return DateTime(year, month, day);
    }
  }

  final iso = DateTime.tryParse(s);
  if (iso != null && iso.year > 1970) {
    return DateTime(iso.year, iso.month, iso.day);
  }

  final slash = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})$').firstMatch(s);
  if (slash != null) {
    var y = int.parse(slash.group(3)!);
    if (y < 100) y += 2000;
    final a = int.parse(slash.group(1)!);
    final b = int.parse(slash.group(2)!);
    final day = a > 12 ? a : b;
    final month = a > 12 ? b : a;
    if (y > 1970 && month >= 1 && month <= 12 && day >= 1 && day <= 31) {
      return DateTime(y, month, day);
    }
  }
  return null;
}


class _RailAction extends StatelessWidget {
  const _RailAction({
    required this.tooltip,
    required this.icon,
    required this.color,
    this.onTap,
    this.tvTabId,
    this.tvRowId,
    this.tvItemIndex,
    this.focusNode,
    this.onLeftEdge,
    this.onRightEdge,
    this.onUpEdge,
    this.onDownEdge,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final String? tvTabId;
  final String? tvRowId;
  final int? tvItemIndex;
  final FocusNode? focusNode;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;
  final VoidCallback? onUpEdge;
  final VoidCallback? onDownEdge;

  @override
  Widget build(BuildContext context) {
    final body = SizedBox(
      width: 32,
      height: 32,
      child: Icon(icon, size: 16, color: color),
    );
    final tab = (tvTabId ?? '').trim();
    final child = Tooltip(message: tooltip, child: body);
    if (tab.isEmpty || !ShellPaintScope.useTvFocusOf(context)) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: child,
        ),
      );
    }
    return ShellPaintScope.focusableTap(
      context: context,
      onTap: onTap,
      borderRadius: 6,
      scaleOnFocus: 1.0,
      showFocusFill: false,
      suppressInkHover: true,
      focusNode: focusNode,
      tvTabId: tab,
      tvRowId: tvRowId,
      tvItemIndex: tvItemIndex,
      ensureVisibleMode: ShellPaintEnsureVisible.off,
      onLeftEdge: onLeftEdge,
      onRightEdge: onRightEdge,
      onUpEdge: onUpEdge,
      onDownEdge: onDownEdge,
      child: child,
    );
  }
}

class _DeletingStripePainter extends CustomPainter {
  const _DeletingStripePainter();

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
  bool shouldRepaint(covariant _DeletingStripePainter oldDelegate) => false;
}
