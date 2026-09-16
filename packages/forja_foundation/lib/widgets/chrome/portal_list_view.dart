import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/widgets/chrome/portal_list_panel.dart';
import 'package:forja_foundation/widgets/chrome/portal_list_row.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:google_fonts/google_fonts.dart';

/// Opaque header action for [PortalListView] — no product verbs in the DS.
class PortalListHeaderAction {
  const PortalListHeaderAction({
    required this.id,
    required this.label,
    this.icon = '',
    this.enabled = true,
    this.tooltip,
    this.onPressed,
  });

  final String id;
  final String label;

  /// Material icon name / id (`add`, `refresh`, `casino`, …).
  final String icon;
  final bool enabled;
  final String? tooltip;
  final VoidCallback? onPressed;
}

/// Full portals inventory panel paint — props / callbacks only (RFC-095).
///
/// Owns search chrome + empty/list composition. Host wires inventory → props
/// and callbacks → engines; pack owns copy / action ids.
///
/// When [tvTabId] is set, header + rows register into the host TV focus graph
/// via [ShellPaintScope] (no coordinator imports in foundation).
class PortalListView extends StatefulWidget {
  const PortalListView({
    super.key,
    required this.width,
    required this.title,
    required this.items,
    this.surfaceColor,
    this.badgeLabel,
    this.badgeMuted = false,
    this.headerActions = const [],
    this.searchPlaceholder = '',
    this.emptyTitle = '',
    this.emptyDescription = '',
    this.statusText = '',
    this.busy = false,
    this.leanback = false,
    this.tvTabId,
    this.listScrollController,
    this.onClose,
    this.onSelect,
    this.onFavorite,
    this.onEdit,
    this.onDelete,
    this.onCopyShareCode,
    this.onHoverEnter,
    this.onHoverExit,
    this.onHeaderUp,
    this.onHeaderDown,
    this.onHeaderFocusAt,
    this.onPortalLeft,
    this.onPortalMove,
    this.onPortalExitUp,
    this.onPortalExitDown,
    this.onPortalTvFocus,
    this.onListPointerBrowse,
  });

  final double width;
  final Color? surfaceColor;
  final String title;

  /// Optional trailing badge next to title (e.g. credits) — opaque string.
  final String? badgeLabel;
  final bool badgeMuted;

  final List<PortalListHeaderAction> headerActions;
  final List<PortalListItem> items;
  final String searchPlaceholder;
  final String emptyTitle;
  final String emptyDescription;
  final String statusText;
  final bool busy;
  final bool leanback;

  /// Host tab id for TV row registration (`iptv`, `live_sports`, …).
  final String? tvTabId;
  final ScrollController? listScrollController;

  final VoidCallback? onClose;
  final void Function(PortalListItem item)? onSelect;
  final void Function(PortalListItem item)? onFavorite;
  final void Function(PortalListItem item)? onEdit;
  final void Function(PortalListItem item)? onDelete;
  final Future<String?> Function(PortalListItem item)? onCopyShareCode;
  final void Function(PortalListItem item)? onHoverEnter;
  final void Function(PortalListItem item)? onHoverExit;

  /// ↑ from header icons (e.g. Portals chip).
  final VoidCallback? onHeaderUp;

  /// ↓ from header → portal list (host owns exact index / retry).
  final VoidCallback? onHeaderDown;

  /// L/R between header icons — host focuses registered item index.
  final void Function(int index)? onHeaderFocusAt;

  /// ← from any portal row → header (stays in panel).
  final VoidCallback? onPortalLeft;

  /// ↑/↓ within the list — host applies hold-accel stride + jump-then-focus.
  final void Function(int fromIndex, int delta)? onPortalMove;

  /// ↑ from the first portal → header.
  final VoidCallback? onPortalExitUp;

  /// ↓ past the last portal (optional catalog handoff).
  final VoidCallback? onPortalExitDown;

  /// Row gained TV focus — host tracks last index (I147).
  final void Function(int index)? onPortalTvFocus;

  /// Mouse/trackpad scroll while panel open.
  final VoidCallback? onListPointerBrowse;

  static const headerRowId = 'portal-header';
  static const portalsRowId = 'portals';

  @override
  State<PortalListView> createState() => _PortalListViewState();
}

class _PortalListViewState extends State<PortalListView> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _searchOpen = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<PortalListItem> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.items;
    return [
      for (final p in widget.items)
        if (p.label.toLowerCase().contains(q) ||
            (p.subtitle?.toLowerCase().contains(q) ?? false) ||
            (p.platformLabel?.toLowerCase().contains(q) ?? false))
          p,
    ];
  }

  bool get _tv {
    final tab = (widget.tvTabId ?? '').trim();
    return tab.isNotEmpty && ShellPaintScope.useTvFocusOf(context);
  }

  IconData _iconFor(PortalListHeaderAction a) {
    final raw = a.icon.trim().isNotEmpty ? a.icon : a.id;
    return switch (raw.trim().toLowerCase()) {
      'add' => Icons.add_rounded,
      'import' || 'content_paste' || 'paste' => Icons.content_paste_rounded,
      'casino' || 'deal' => Icons.casino_rounded,
      'scrape' ||
      'travel_explore' ||
      'explore' =>
        Icons.travel_explore_rounded,
      'refresh' => Icons.refresh_rounded,
      _ => Icons.circle_outlined,
    };
  }

  bool _onListScrollNotification(ScrollNotification notification) {
    if (notification is! UserScrollNotification) return false;
    if (notification.direction == ScrollDirection.idle) return false;
    widget.onListPointerBrowse?.call();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final hint = widget.searchPlaceholder.trim().isEmpty
        ? 'Search…'
        : widget.searchPlaceholder;
    final status = widget.statusText.trim().isNotEmpty
        ? widget.statusText
        : '${filtered.length}';
    final tab = (widget.tvTabId ?? '').trim();

    Widget header = _buildHeader(context, tab: tab);
    Widget body = filtered.isEmpty
        ? _buildEmpty()
        : _buildList(filtered, tab: tab);

    if (_tv && tab.isNotEmpty) {
      header = ShellPaintScope.tvRow(
        context: context,
        tabId: tab,
        rowId: PortalListView.headerRowId,
        sortOrder: 0,
        itemCount: 1 + widget.headerActions.length,
        child: header,
      );
      if (filtered.isNotEmpty) {
        body = ShellPaintScope.tvRow(
          context: context,
          tabId: tab,
          rowId: PortalListView.portalsRowId,
          sortOrder: 2,
          itemCount: filtered.length,
          axis: ShellPaintTvRowAxis.vertical,
          child: body,
        );
      }
    }

    return PortalListPanel(
      width: widget.width,
      surfaceColor:
          widget.surfaceColor ?? ForjaShellColors.cinematic.menuSurface,
      searchOpen: _searchOpen,
      statusText: status,
      onEscape: widget.onClose,
      header: header,
      search: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: TextField(
          controller: _searchCtrl,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 13,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.plusJakartaSans(
              color: Colors.white38,
              fontSize: 13,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: Colors.white54,
              size: 20,
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
      ),
      body: body,
    );
  }

  Widget _buildHeader(BuildContext context, {required String tab}) {
    // L→R paint: Search · Scrape · Deal · Add  (indices for TV L/R).
    final actions = widget.headerActions;
    final searchIndex = 0;
    final actionBase = 1;
    final lastHeader = actionBase + actions.length - 1;

    Widget iconAt({
      required int index,
      required String tooltip,
      required IconData icon,
      required VoidCallback? onPressed,
      Color? color,
    }) {
      final left = index > searchIndex
          ? () => widget.onHeaderFocusAt?.call(index - 1)
          : null;
      final right = index < lastHeader
          ? () => widget.onHeaderFocusAt?.call(index + 1)
          : null;
      return _PortalHeaderIcon(
        tooltip: tooltip,
        icon: icon,
        color: color,
        onPressed: onPressed,
        tvTabId: _tv ? tab : null,
        tvItemIndex: _tv ? index : null,
        onUpEdge: widget.onHeaderUp,
        onDownEdge: widget.onHeaderDown,
        onLeftEdge: left,
        onRightEdge: right,
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          Text(
            widget.title.trim().isEmpty ? 'Portals' : widget.title,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          if ((widget.badgeLabel ?? '').trim().isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              widget.badgeLabel!.trim(),
              style: TextStyle(
                color: widget.badgeMuted
                    ? Colors.white38
                    : ForjaShellColors.brandGreen,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const Spacer(),
          iconAt(
            index: searchIndex,
            tooltip: _searchOpen ? 'Close search' : 'Search portals',
            icon: _searchOpen ? Icons.close_rounded : Icons.search_rounded,
            color: _searchOpen ? ForjaShellColors.brandGreen : null,
            onPressed: () {
              setState(() {
                _searchOpen = !_searchOpen;
                if (!_searchOpen) {
                  _searchCtrl.clear();
                  _query = '';
                }
              });
            },
          ),
          for (var i = 0; i < actions.length; i++)
            iconAt(
              index: actionBase + i,
              tooltip: actions[i].tooltip ?? actions[i].label,
              icon: _iconFor(actions[i]),
              onPressed: widget.busy || !actions[i].enabled
                  ? null
                  : actions[i].onPressed,
            ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.inbox_outlined,
              size: 48,
              color: Colors.white38,
            ),
            if (widget.emptyTitle.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                widget.emptyTitle,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (widget.emptyDescription.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                widget.emptyDescription,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white60,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<PortalListItem> filtered, {required String tab}) {
    final last = filtered.length - 1;
    return NotificationListener<ScrollNotification>(
      onNotification: _onListScrollNotification,
      child: ListView.builder(
        controller: widget.listScrollController,
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        itemExtent: PortalListRow.rowHeight,
        scrollCacheExtent: ScrollCacheExtent.pixels(
          PortalListRow.rowHeight * 14,
        ),
        addAutomaticKeepAlives: false,
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final item = filtered[index];
          return PortalListRow(
            key: ValueKey<String>(item.id),
            item: item,
            leanback: widget.leanback,
            tvTabId: _tv ? tab : null,
            listIndex: index,
            onSelect: widget.busy || widget.onSelect == null
                ? null
                : () => widget.onSelect!(item),
            onFavorite: widget.busy || widget.onFavorite == null
                ? null
                : () => widget.onFavorite!(item),
            onEdit: widget.busy || widget.onEdit == null
                ? null
                : () => widget.onEdit!(item),
            onDelete: widget.busy || widget.onDelete == null
                ? null
                : () => widget.onDelete!(item),
            onCopyShareCode: widget.busy || widget.onCopyShareCode == null
                ? null
                : () => widget.onCopyShareCode!(item),
            onHoverEnter: widget.onHoverEnter == null
                ? null
                : () => widget.onHoverEnter!(item),
            onHoverExit: widget.onHoverExit == null
                ? null
                : () => widget.onHoverExit!(item),
            onUpEdge: !_tv
                ? null
                : index == 0
                    ? widget.onPortalExitUp
                    : () => widget.onPortalMove?.call(index, -1),
            onDownEdge: !_tv
                ? null
                : index >= last
                    ? widget.onPortalExitDown
                    : () => widget.onPortalMove?.call(index, 1),
            onLeftEdge: _tv ? widget.onPortalLeft : null,
            onTvFocus: _tv
                ? () => widget.onPortalTvFocus?.call(index)
                : null,
          );
        },
      ),
    );
  }
}

/// Classic IPTV portal header icon — white idle / hover, press scale.
class _PortalHeaderIcon extends StatefulWidget {
  const _PortalHeaderIcon({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
    this.tvTabId,
    this.tvItemIndex,
    this.onUpEdge,
    this.onDownEdge,
    this.onLeftEdge,
    this.onRightEdge,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;
  final String? tvTabId;
  final int? tvItemIndex;
  final VoidCallback? onUpEdge;
  final VoidCallback? onDownEdge;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;

  @override
  State<_PortalHeaderIcon> createState() => _PortalHeaderIconState();
}

class _PortalHeaderIconState extends State<_PortalHeaderIcon> {
  static const _iconSize = 24.0;
  static const _hoverScale = 1.08;
  static const _pressScale = 0.88;

  bool _focused = false;
  bool _hovered = false;
  bool _pressed = false;

  bool get _tv => ShellPaintScope.useTvFocusOf(context);

  Color get _fg {
    final enabled = widget.onPressed != null;
    if (!enabled) return Colors.white.withValues(alpha: 0.38);
    if (_tv && _focused) return ForjaShellColors.brandGreen;
    return widget.color ?? Colors.white;
  }

  Widget _icon() => Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(widget.icon, color: _fg, size: _iconSize),
      );

  @override
  Widget build(BuildContext context) {
    final body = Tooltip(message: widget.tooltip, child: _icon());
    final tab = (widget.tvTabId ?? '').trim();

    if (_tv && tab.isNotEmpty) {
      return ShellPaintScope.focusableTap(
        context: context,
        onTap: widget.onPressed,
        borderRadius: 24,
        scaleOnFocus: 1.0,
        suppressInkHover: true,
        showFocusFill: false,
        tvTabId: tab,
        tvRowId: PortalListView.headerRowId,
        tvItemIndex: widget.tvItemIndex,
        tvZone: ShellPaintTvZone.topBar,
        onUpEdge: widget.onUpEdge,
        onDownEdge: widget.onDownEdge,
        onLeftEdge: widget.onLeftEdge,
        onRightEdge: widget.onRightEdge,
        onFocusChange: (f) => setState(() => _focused = f),
        onHoverChange: (h) => setState(() => _hovered = h),
        child: body,
      );
    }

    final enabled = widget.onPressed != null;
    final scale = !enabled
        ? 1.0
        : _pressed
            ? _pressScale
            : _hovered
                ? _hoverScale
                : 1.0;

    return MouseRegion(
      onEnter: !enabled ? null : (_) => setState(() => _hovered = true),
      onExit: !enabled
          ? null
          : (_) => setState(() {
                _hovered = false;
                _pressed = false;
              }),
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        onTapDown: !enabled ? null : (_) => setState(() => _pressed = true),
        onTapUp: !enabled ? null : (_) => setState(() => _pressed = false),
        onTapCancel: !enabled ? null : () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: body,
        ),
      ),
    );
  }
}
