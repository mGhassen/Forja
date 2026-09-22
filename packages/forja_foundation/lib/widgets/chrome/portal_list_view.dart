import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:forja_foundation/tokens/forja_motion_theme.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/tokens/portal_list_tokens.dart';
import 'package:forja_foundation/widgets/chrome/portal_list_panel.dart';
import 'package:forja_foundation/widgets/chrome/portal_list_row.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:forja_foundation/widgets/guide/guide_chrome_style.dart';
import 'package:google_fonts/google_fonts.dart';

/// Opaque header action for [PortalListView] — no product verbs in the DS.
class PortalListHeaderAction {
  const PortalListHeaderAction({
    required this.id,
    required this.label,
    this.icon = '',
    this.enabled = true,
    this.tooltip,
    this.hoverLabel,
    this.hoverLabelMuted = false,
    this.onPressed,
  });

  final String id;
  final String label;

  /// Material icon name / id (`add`, `refresh`, `casino`, …).
  final String icon;
  final bool enabled;
  final String? tooltip;

  /// When set, replaces the icon while hovered / focused (e.g. credits).
  final String? hoverLabel;
  final bool hoverLabelMuted;
  final VoidCallback? onPressed;
}

/// Full portals inventory panel paint — props / callbacks only (RFC-095).
///
/// Owns search chrome + empty/list composition. Host wires inventory → props
/// and callbacks → engines; pack owns copy / action ids.
///
/// When [ShellPaintTvTabScope] is mounted, header + rows register into the
/// host TV focus graph via [ShellPaintScope] (no coordinator imports).
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
    this.listScrollController,
    this.titleFontSize = 18,
    this.pad = const EdgeInsets.fromLTRB(
      PortalListTokens.panelPad,
      PortalListTokens.panelPad,
      PortalListTokens.sectionGap,
      PortalListTokens.sectionGap,
    ),
    this.rowHeight = PortalListRow.rowHeight,
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
    this.searchFieldBuilder,
  });

  final double width;
  final Color? surfaceColor;
  final String title;

  /// Unused for header title — prefer [PortalListHeaderAction.hoverLabel].
  /// Kept for kit / host callers that still pass credits here.
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

  final ScrollController? listScrollController;
  final double titleFontSize;
  final EdgeInsetsGeometry pad;
  final double rowHeight;

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

  /// ← from any portal row → header Search (stays in panel).
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

  /// Desktop/TV search field — host supplies the browse/edit split field
  /// (`TvBrowseTextField`) so D-pad land highlights without opening the IME.
  /// Null (phone) falls back to a plain type-on-focus field.
  /// Paint (decoration / style) stays here — the host only swaps the widget.
  final Widget Function(
    BuildContext context, {
    required TextEditingController controller,
    required FocusNode focusNode,
    required ValueChanged<String> onChanged,
    required VoidCallback onEscape,
    required InputDecoration decoration,
    required TextStyle style,
    required String placeholder,
  })? searchFieldBuilder;

  static const headerRowId = 'portal-header';
  static const portalsRowId = 'portals';

  @override
  State<PortalListView> createState() => _PortalListViewState();
}

class _PortalListViewState extends State<PortalListView> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode(debugLabel: 'portal-panel-search');
  final ValueNotifier<String?> _hoverRowId = ValueNotifier<String?>(null);
  late final ScrollController _ownedListScroll = ScrollController();
  String _query = '';
  bool _searchOpen = false;

  /// Header icon index the search toggle (magnifier ⇄ close ×) paints at.
  static const _searchHeaderIndex = 0;

  ScrollController get _listScroll =>
      widget.listScrollController ?? _ownedListScroll;

  @override
  void initState() {
    super.initState();
    _searchFocus.onKeyEvent = _onSearchKey;
  }

  @override
  void dispose() {
    _hoverRowId.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _ownedListScroll.dispose();
    super.dispose();
  }

  /// → at the end of the query hops to the × that closes the search; a caret
  /// still inside the text keeps moving as usual (desktop typing).
  KeyEventResult _onSearchKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
      _closeSearch();
      return KeyEventResult.handled;
    }
    if (key != LogicalKeyboardKey.arrowRight) return KeyEventResult.ignored;
    final sel = _searchCtrl.selection;
    final atEnd = !sel.isValid ||
        (sel.isCollapsed && sel.baseOffset >= _searchCtrl.text.length);
    if (!atEnd) return KeyEventResult.ignored;
    widget.onHeaderFocusAt?.call(_searchHeaderIndex);
    return KeyEventResult.handled;
  }

  void _closeSearch() {
    if (!_searchOpen) return;
    setState(() {
      _searchOpen = false;
      _searchCtrl.clear();
      _query = '';
    });
    widget.onHeaderFocusAt?.call(_searchHeaderIndex);
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
    final tab = ShellPaintTvTabScope.tabIdOf(context);
    return tab != null && ShellPaintScope.useTvFocusOf(context);
  }

  String? get _tabId => ShellPaintTvTabScope.tabIdOf(context);

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
    // Scroll moves rows under a fixed cursor — MouseRegion often skips onExit,
    // so drop exclusive hover ownership (clears stacked info cards).
    if (notification is ScrollUpdateNotification &&
        (notification.scrollDelta ?? 0) != 0 &&
        _hoverRowId.value != null) {
      _hoverRowId.value = null;
    }
    if (notification is! UserScrollNotification) return false;
    if (notification.direction == ScrollDirection.idle) return false;
    widget.onListPointerBrowse?.call();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final tvDensity = ShellPaintScope.usesTvDensityOf(context);
    final rowExtent = PortalListTokens.resolveRowHeight(
      tvDensity,
      widget.rowHeight,
    );
    final searchFontSize = tvDensity
        ? PortalListTokens.titleFontSizeTv
        : PortalListTokens.titleFontSize;
    final headerTitleFontSize = tvDensity
        ? ShellTokens.tvTitleFontSize
        : widget.titleFontSize;
    final badgeFontSize =
        tvDensity ? ShellTokens.tvMetaFontSize : 12.0;
    final filtered = _filtered;
    final hint = widget.searchPlaceholder.trim().isEmpty
        ? 'Search…'
        : widget.searchPlaceholder;
    // Busy / loading only — portal count lives in the title row.
    final status = widget.statusText.trim();
    final tab = _tabId ?? '';

    Widget header = _buildHeader(
      context,
      tab: tab,
      titleFontSize: headerTitleFontSize,
      badgeFontSize: badgeFontSize,
      portalCount: widget.items.length,
    );
    Widget body = filtered.isEmpty
        ? _buildEmpty(context)
        : _buildList(filtered, tab: tab, rowExtent: rowExtent);
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

    final padH = PortalListTokens.panelPadOf(tvDensity);
    final gap = PortalListTokens.sectionGapOf(tvDensity);
    return PortalListPanel(
      width: widget.width,
      surfaceColor:
          widget.surfaceColor ?? ForjaShellColors.cinematic.menuSurface,
      searchOpen: _searchOpen,
      statusText: status,
      onEscape: widget.onClose,
      header: header,
      search: Padding(
        padding: EdgeInsets.fromLTRB(padH, gap, padH, tvDensity ? 2 : 4),
        child: _searchField(searchFontSize: searchFontSize, hint: hint),
      ),
      body: body,
    );
  }

  /// Desktop/TV get the host's browse/edit field (D-pad land = highlight only,
  /// OK opens the IME). Phone keeps the plain type-on-focus field.
  ///
  /// Chrome matches [EventListSearch] top-bar pill — fixed subtle border, no
  /// green Material focus ring when selected.
  Widget _searchField({
    required double searchFontSize,
    required String hint,
  }) {
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final height = PortalListTokens.searchFieldHeightOf(tv);
    final fieldPadV = PortalListTokens.searchFieldPadVOf(tv);
    final pad = PortalListTokens.searchChromePadOf(tv);
    final lead = PortalListTokens.searchChromeLeadOf(tv);
    final mid = PortalListTokens.searchChromeMidOf(tv);
    final decoration = InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.plusJakartaSans(
        color: Colors.white.withValues(alpha: 0.38),
        fontSize: searchFontSize,
      ),
      isDense: true,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
      contentPadding: EdgeInsets.symmetric(vertical: fieldPadV),
    );
    final style = GoogleFonts.plusJakartaSans(
      color: Colors.white,
      fontSize: searchFontSize,
    );
    final build = widget.searchFieldBuilder;
    final field = build != null
        ? build(
            context,
            controller: _searchCtrl,
            focusNode: _searchFocus,
            onChanged: (v) => setState(() => _query = v),
            onEscape: _closeSearch,
            decoration: decoration,
            style: style,
            placeholder: hint,
          )
        : TextField(
            controller: _searchCtrl,
            focusNode: _searchFocus,
            style: style,
            cursorColor: ForjaShellColors.brandGreen,
            decoration: decoration,
            onChanged: (v) => setState(() => _query = v),
          );
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      padding: EdgeInsets.symmetric(horizontal: pad),
      child: Row(
        children: [
          SizedBox(width: lead),
          Icon(
            Icons.search_rounded,
            color: Colors.white70,
            size: PortalListTokens.searchPrefixIconSizeOf(tv),
          ),
          SizedBox(width: mid),
          Expanded(child: field),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context, {
    required String tab,
    required double titleFontSize,
    required double badgeFontSize,
    required int portalCount,
  }) {
    // L→R paint: Search · Scrape · Deal · Add  (indices for TV L/R).
    final actions = widget.headerActions;
    final searchIndex = 0;
    final actionBase = 1;
    final lastHeader = actionBase + actions.length - 1;
    final title =
        widget.title.trim().isEmpty ? 'Portals' : widget.title.trim();

    Widget iconAt({
      required int index,
      required String tooltip,
      required IconData icon,
      required VoidCallback? onPressed,
      Color? color,
      String? hoverLabel,
      bool hoverLabelMuted = false,
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
        hoverLabel: hoverLabel,
        hoverLabelMuted: hoverLabelMuted,
        hoverLabelFontSize: badgeFontSize,
        onPressed: onPressed,
        tvItemIndex: _tv ? index : null,
        onUpEdge: widget.onHeaderUp,
        onDownEdge: widget.onHeaderDown,
        onLeftEdge: left,
        onRightEdge: right,
      );
    }

    return Container(
      padding: widget.pad,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          Text(
            '$portalCount',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white54,
              fontSize: badgeFontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: PortalListTokens.sectionGap),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: titleFontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          iconAt(
            index: searchIndex,
            tooltip: _searchOpen ? 'Close search' : 'Search portals',
            icon: _searchOpen ? Icons.close_rounded : Icons.search_rounded,
            color: _searchOpen ? ForjaShellColors.brandGreen : null,
            onPressed: () {
              if (_searchOpen) {
                _closeSearch();
                return;
              }
              // Tool-button activate may move focus onto the field; the browse
              // field highlights only — OK opens the keyboard.
              setState(() => _searchOpen = true);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _searchOpen) _searchFocus.requestFocus();
              });
            },
          ),
          for (var i = 0; i < actions.length; i++)
            iconAt(
              index: actionBase + i,
              tooltip: actions[i].tooltip ?? actions[i].label,
              icon: _iconFor(actions[i]),
              hoverLabel: (actions[i].hoverLabel ?? '').trim().isNotEmpty
                  ? actions[i].hoverLabel!.trim()
                  : null,
              hoverLabelMuted: actions[i].hoverLabelMuted,
              onPressed: widget.busy || !actions[i].enabled
                  ? null
                  : actions[i].onPressed,
            ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final titleFontSize =
        tv ? ShellTokens.tvTitleFontSize : 16.0;
    final bodyFontSize =
        tv ? ShellTokens.tvBodyFontSize : 12.0;
    final pad = PortalListTokens.panelPadOf(tv) * 2;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(pad),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: PortalListTokens.emptyIconSizeOf(tv),
              color: Colors.white38,
            ),
            if (widget.emptyTitle.trim().isNotEmpty) ...[
              SizedBox(height: PortalListTokens.itemSpacingOf(tv)),
              Text(
                widget.emptyTitle,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (widget.emptyDescription.trim().isNotEmpty) ...[
              SizedBox(height: PortalListTokens.sectionGapOf(tv)),
              Text(
                widget.emptyDescription,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white60,
                  fontSize: bodyFontSize,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildList(
    List<PortalListItem> filtered, {
    required String tab,
    required double rowExtent,
  }) {
    final last = filtered.length - 1;
    return LiveTvScrollbar(
      controller: _listScroll,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onListScrollNotification,
        child: ListView.builder(
          controller: _listScroll,
          padding: EdgeInsets.fromLTRB(
            4,
            0,
            4,
            PortalListTokens.sectionGapOf(
              ShellPaintScope.usesTvDensityOf(context),
            ),
          ),
          itemExtent: rowExtent,
          scrollCacheExtent: ScrollCacheExtent.pixels(
            rowExtent * 14,
          ),
          addAutomaticKeepAlives: false,
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final item = filtered[index];
            return PortalListRow(
              key: ValueKey<String>(item.id),
              item: item,
              leanback: widget.leanback,
              height: rowExtent,
              listIndex: index,
              hoverOwnerId: widget.leanback ? null : _hoverRowId,
              onSelect: widget.busy || widget.onSelect == null
                  ? null
                  : () => widget.onSelect!(item),
              onFavorite: widget.busy || widget.onFavorite == null
                  ? null
                  : () => widget.onFavorite!(item),
              onEdit: widget.busy || widget.onEdit == null
                  ? null
                  : () => widget.onEdit!(item),
              onCopyShareCode: widget.busy || widget.onCopyShareCode == null
                  ? null
                  : () => widget.onCopyShareCode!(item),
            onHoverEnter: () {
              // Mouse/trackpad hover = pointer browse (I147) — not only scroll.
              widget.onListPointerBrowse?.call();
              widget.onHoverEnter?.call(item);
            },
            onHoverExit: widget.onHoverExit == null
                ? null
                : () => widget.onHoverExit!(item),
            onDelete: widget.busy || widget.onDelete == null
                ? null
                : () {
                    // Delete Yes is a click — skip inventory focus restore.
                    if (!widget.leanback) {
                      widget.onListPointerBrowse?.call();
                    }
                    widget.onDelete!(item);
                  },
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
      ),
    );
  }
}

/// Classic IPTV portal header icon — white idle, brand-green hover, press scale.
/// Optional [hoverLabel] replaces the icon while hovered / focused (e.g. credits).
class _PortalHeaderIcon extends StatefulWidget {
  const _PortalHeaderIcon({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
    this.hoverLabel,
    this.hoverLabelMuted = false,
    this.hoverLabelFontSize = 12,
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

  /// When non-empty, shown instead of [icon] while hovered or focused.
  final String? hoverLabel;
  final bool hoverLabelMuted;
  final double hoverLabelFontSize;
  final int? tvItemIndex;
  final VoidCallback? onUpEdge;
  final VoidCallback? onDownEdge;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;

  @override
  State<_PortalHeaderIcon> createState() => _PortalHeaderIconState();
}

class _PortalHeaderIconState extends State<_PortalHeaderIcon> {
  static const _pressScale = 0.88;

  bool _focused = false;
  final ValueNotifier<bool> _hoveredN = ValueNotifier(false);
  bool _pressed = false;

  @override
  void dispose() {
    _hoveredN.dispose();
    super.dispose();
  }

  bool get _tv => ShellPaintScope.useTvFocusOf(context);
  bool get _tvDensity => ShellPaintScope.usesTvDensityOf(context);
  double get _iconSize => PortalListTokens.headerIconSizeOf(_tvDensity);
  double get _hit => PortalListTokens.headerIconHitOf(_tvDensity);

  bool get _hasHoverLabel => (widget.hoverLabel ?? '').trim().isNotEmpty;

  bool _litFor(bool hovered) =>
      hovered ||
      ShellPaintScope.focusStyledOf(context, focused: _focused);

  Color _fgFor(bool hovered) {
    final enabled = widget.onPressed != null;
    if (!enabled) return Colors.white.withValues(alpha: 0.38);
    if (_litFor(hovered)) return ForjaShellColors.brandGreen;
    return widget.color ?? Colors.white;
  }

  void _setHovered(bool v) {
    if (_hoveredN.value == v) return;
    _hoveredN.value = v;
    if (!v) _pressed = false;
  }

  Widget _face(bool hovered) {
    final label = (widget.hoverLabel ?? '').trim();
    final lit = _litFor(hovered);
    final showLabel = label.isNotEmpty && lit;
    return SizedBox(
      width: _hit,
      height: _hit,
      child: Center(
        child: showLabel
            ? FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    color: widget.hoverLabelMuted
                        ? Colors.white38
                        : ForjaShellColors.brandGreen,
                    fontSize: widget.hoverLabelFontSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : Icon(widget.icon, color: _fgFor(hovered), size: _iconSize),
      ),
    );
  }

  Widget _paintedFace(bool hovered) {
    if (_hasHoverLabel) return _face(hovered);
    return Tooltip(message: widget.tooltip, child: _face(hovered));
  }

  @override
  Widget build(BuildContext context) {
    if (_tv && ShellPaintTvRowScope.maybeOf(context) != null) {
      return ShellPaintScope.focusableTap(
        context: context,
        onTap: widget.onPressed,
        borderRadius: 24,
        motion: ForjaMotionPreset.fillOnly,
        suppressInkHover: true,
        showFocusFill: false,
        tvItemIndex: widget.tvItemIndex,
        tvZone: ShellPaintTvZone.topBar,
        onUpEdge: widget.onUpEdge,
        onDownEdge: widget.onDownEdge,
        onLeftEdge: widget.onLeftEdge,
        onRightEdge: widget.onRightEdge,
        onFocusChange: (f) => setState(() => _focused = f),
        onHoverChange: _setHovered,
        child: ListenableBuilder(
          listenable: _hoveredN,
          builder: (context, _) => _paintedFace(_hoveredN.value),
        ),
      );
    }

    final enabled = widget.onPressed != null;
    final chip = ForjaMotionTheme.of(context).chipLift;
    final trackHover = enabled || _hasHoverLabel;

    return MouseRegion(
      hitTestBehavior: HitTestBehavior.opaque,
      onEnter: !trackHover ? null : (_) => _setHovered(true),
      onExit: !trackHover ? null : (_) => _setHovered(false),
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        onTapDown: !enabled ? null : (_) => setState(() => _pressed = true),
        onTapUp: !enabled ? null : (_) => setState(() => _pressed = false),
        onTapCancel: !enabled ? null : () => setState(() => _pressed = false),
        child: ListenableBuilder(
          listenable: _hoveredN,
          builder: (context, _) {
            final scale = !enabled
                ? 1.0
                : _pressed
                    ? _pressScale
                    : ForjaMotionTheme.of(context).scaleForActive(
                        context,
                        ForjaMotionPreset.chipLift,
                        _hoveredN.value,
                      );
            return AnimatedScale(
              scale: scale,
              duration: chip.duration,
              curve: chip.resolvedCurve,
              child: _paintedFace(_hoveredN.value),
            );
          },
        ),
      ),
    );
  }
}
