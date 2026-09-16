import 'package:flutter/material.dart';
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
    this.onClose,
    this.onSelect,
    this.onFavorite,
    this.onEdit,
    this.onDelete,
    this.onCopyShareCode,
    this.onHoverEnter,
    this.onHoverExit,
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
  final VoidCallback? onClose;
  final void Function(PortalListItem item)? onSelect;
  final void Function(PortalListItem item)? onFavorite;
  final void Function(PortalListItem item)? onEdit;
  final void Function(PortalListItem item)? onDelete;
  final Future<String?> Function(PortalListItem item)? onCopyShareCode;
  final void Function(PortalListItem item)? onHoverEnter;
  final void Function(PortalListItem item)? onHoverExit;

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

  IconData _iconFor(PortalListHeaderAction a) {
    final raw = a.icon.trim().isNotEmpty ? a.icon : a.id;
    return switch (raw.trim().toLowerCase()) {
      'add' => Icons.add_rounded,
      'import' || 'content_paste' || 'paste' => Icons.content_paste_rounded,
      'casino' || 'deal' => Icons.casino_rounded,
      'refresh' => Icons.refresh_rounded,
      _ => Icons.circle_outlined,
    };
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

    return PortalListPanel(
      width: widget.width,
      surfaceColor:
          widget.surfaceColor ?? ForjaShellColors.cinematic.menuSurface,
      searchOpen: _searchOpen,
      statusText: status,
      header: Container(
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
            _PortalHeaderIcon(
              tooltip: _searchOpen ? 'Close search' : 'Search',
              icon: _searchOpen ? Icons.close_rounded : Icons.search_rounded,
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
            for (final a in widget.headerActions)
              _PortalHeaderIcon(
                tooltip: a.tooltip ?? a.label,
                icon: _iconFor(a),
                onPressed: widget.busy || !a.enabled ? null : a.onPressed,
              ),
            if (widget.onClose != null)
              _PortalHeaderIcon(
                tooltip: 'Close',
                icon: Icons.close_rounded,
                onPressed: widget.onClose,
              ),
          ],
        ),
      ),
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
      body: filtered.isEmpty
          ? Center(
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
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              itemExtent: PortalListRow.rowHeight,
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final item = filtered[index];
                return PortalListRow(
                  item: item,
                  leanback: widget.leanback,
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
                );
              },
            ),
    );
  }
}

/// Classic IPTV portal header icon (former [IptvIconAction]):
/// muted gray idle → brand green on hover/TV focus; slight scale on press.
class _PortalHeaderIcon extends StatefulWidget {
  const _PortalHeaderIcon({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;

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

  bool get _active =>
      _pressed ||
      ShellPaintScope.interactiveActive(
        context,
        hovered: _hovered,
        focused: _focused,
      );

  Color get _idleColor {
    final c = widget.color;
    if (c == null) return ForjaShellColors.textSecondary;
    return c;
  }

  Color get _fg {
    final enabled = widget.onPressed != null;
    if (!enabled) return _idleColor.withValues(alpha: 0.45);
    if ((_tv && _focused) || _active) return ForjaShellColors.brandGreen;
    return _idleColor;
  }

  Widget _icon() => Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(widget.icon, color: _fg, size: _iconSize),
      );

  @override
  Widget build(BuildContext context) {
    final body = Tooltip(message: widget.tooltip, child: _icon());

    if (_tv) {
      return ShellPaintScope.focusableTap(
        context: context,
        onTap: widget.onPressed,
        borderRadius: 24,
        scaleOnFocus: 1.0,
        suppressInkHover: true,
        showFocusFill: false,
        tvZone: ShellPaintTvZone.topBar,
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
