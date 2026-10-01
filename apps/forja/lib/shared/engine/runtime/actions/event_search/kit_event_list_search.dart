import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:forja/shared/engine/runtime/kit/hosts/iptv_catalog_land.dart';
import 'package:forja/shared/engine/runtime/kit/pack_chrome_scope.dart';
import 'package:forja/shared/engine/runtime/shell/shell_bus.dart';
import 'package:forja/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shell/tv/shell_tv_focus.dart';
import 'package:forja/shell/tv/tv_browse_text_field.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/event_list_search.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

/// Host wire for pack `action: eventSearch` — expanding circle search on the
/// kit top bar (IPTV / Live Sports). Query lives on [PackChromeScope].
class KitEventListSearch extends StatefulWidget {
  const KitEventListSearch({
    super.key,
    required this.tooltip,
    required this.placeholder,
    this.alwaysOpen = false,
    this.tvItemIndex,
    this.onLeftEdge,
    this.onRightEdge,
    this.onDownEdge,
    this.collapsedSize,
    this.expandedWidth,
    this.fontSize,
    this.iconSize,
    this.fieldIconSize,
  });

  final String tooltip;
  final String placeholder;
  final bool alwaysOpen;
  final int? tvItemIndex;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;
  final VoidCallback? onDownEdge;
  final double? collapsedSize;
  final double? expandedWidth;
  final double? fontSize;
  final double? iconSize;
  final double? fieldIconSize;

  @override
  State<KitEventListSearch> createState() => _KitEventListSearchState();
}

class _KitEventListSearchState extends State<KitEventListSearch> {
  final GlobalKey<EventListSearchState> _searchKey =
      GlobalKey<EventListSearchState>();
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    ShellBus.registerFindShortcutHandler(_handleFindShortcut);
  }

  @override
  void dispose() {
    ShellBus.unregisterFindShortcutHandler(_handleFindShortcut);
    super.dispose();
  }

  bool _handleFindShortcut() {
    if (!mounted) return false;
    // KeepAlive hubs stay mounted offstage — only the active tab may consume.
    final tab = (ShellPaintTvTabScope.tabIdOf(context) ?? '').trim();
    if (tab.isEmpty || tab != ShellBus.activeShellTabId) return false;
    if (ShellBus.shellOverlayHasPage.value) return false;
    final search = _searchKey.currentState;
    if (search == null) return false;
    search.openSearch();
    return true;
  }

  Future<void> _openCompactDialog() async {
    if (_dialogOpen) return;
    final chrome = PackChromeScope.maybeOf(context);
    if (chrome == null) return;
    _dialogOpen = true;
    final initial = chrome.eventQuery;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final local = TextEditingController(text: initial);
        return AlertDialog(
          backgroundColor: ForjaShellColors.surfaceElevated,
          title: Text(
            widget.tooltip,
            style: const TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: local,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: widget.placeholder,
              hintStyle: const TextStyle(color: Colors.white38),
            ),
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, ''),
              child: const Text('Clear'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, local.text),
              child: const Text('Search'),
            ),
          ],
        );
      },
    );
    _dialogOpen = false;
    if (!mounted || result == null) return;
    chrome.onEventQuery(result.trim());
    _focusAfterSearchCommit(result.trim());
  }

  @override
  Widget build(BuildContext context) {
    final chrome = PackChromeScope.maybeOf(context);
    final query = chrome?.eventQuery ?? '';
    final compact = !widget.alwaysOpen &&
        MediaQuery.sizeOf(context).width < 760;
    final useTv = shellTvBrowseSearch(context);
    final tvDensity = ShellPaintScope.usesTvDensityOf(context);
    final collapsed = widget.collapsedSize ??
        (tvDensity
            ? ShellTokens.eventSearchCollapsedTv
            : ShellTokens.eventSearchCollapsed);
    final expanded = widget.expandedWidth ??
        (tvDensity
            ? ShellTokens.eventSearchExpandedTv
            : ShellTokens.eventSearchExpanded);
    final fontSize = widget.fontSize ??
        (tvDensity
            ? ShellTokens.eventSearchFontSizeTv
            : ShellTokens.eventSearchFontSize);
    final iconSize = widget.iconSize ??
        (tvDensity
            ? ShellTokens.eventSearchIconSizeTv
            : ShellTokens.eventSearchIconSize);
    final fieldIconSize = widget.fieldIconSize ??
        (tvDensity
            ? ShellTokens.eventSearchClearIconSizeTv
            : ShellTokens.eventSearchClearIconSize);

    return EventListSearch(
      key: _searchKey,
      query: query,
      onQueryChanged: (q) {
        chrome?.onEventQuery(q);
        _focusAfterSearchCommit(q.trim());
      },
      tooltip: widget.tooltip,
      placeholder: widget.placeholder,
      compact: compact,
      alwaysOpen: widget.alwaysOpen,
      onCompactSearch: () => unawaited(_openCompactDialog()),
      tvItemIndex: widget.tvItemIndex,
      onLeftEdge: widget.onLeftEdge,
      onRightEdge: widget.onRightEdge,
      onDownEdge: widget.onDownEdge,
      openFieldSlot: !useTv || widget.tvItemIndex == null
          ? null
          : ({required focusNode, required child}) => _OpenSearchTvSlot(
              node: focusNode,
              index: widget.tvItemIndex!,
              child: child,
            ),
      collapsedSize: collapsed,
      expandedWidth: expanded,
      fontSize: fontSize,
      iconSize: iconSize,
      fieldIconSize: fieldIconSize,
      fieldBuilder: !useTv
          ? null
          : (ctx, {
              required controller,
              required focusNode,
              required onChanged,
              required onSubmitted,
              required onEscape,
            }) {
              return TvBrowseTextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: onChanged,
                onSubmitted: onSubmitted,
                onEscape: onEscape,
                onKeyEvent: (node, event) => _searchFieldArrow(
                  ctx,
                  event,
                  index: widget.tvItemIndex,
                  onDownEdge: widget.onDownEdge,
                ),
                browsePlaceholder: widget.placeholder,
                browseHintStyle: GoogleFonts.plusJakartaSans(
                  color: Colors.white38,
                  fontSize: fontSize,
                ),
                caretHeight: ShellTokens.chromeScale(16, tv: tvDensity),
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: fontSize,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    vertical: ShellTokens.chromeScale(10, tv: tvDensity),
                  ),
                ),
              );
            },
    );
  }

  /// After OK/Enter search: first channel when hits exist, else keep the field.
  void _focusAfterSearchCommit(String q) {
    if (q.isEmpty) return;
    var frames = 0;
    void attempt() {
      if (!mounted) return;
      if (frames++ < 2) {
        WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
        return;
      }
      final tab = (ShellPaintTvTabScope.tabIdOf(context) ?? '').trim();
      if (tab.isEmpty) return;
      final handle = ShellTvFocusCoordinator.rowHandle(
        tab,
        IptvCatalogLand.itemsRowId,
      );
      if (handle != null && handle.itemCount > 0) {
        ShellTvFocusCoordinator.focusRowItem(tab, IptvCatalogLand.itemsRowId, 0);
        return;
      }
      _searchKey.currentState?.focusField();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
  }
}

/// Left / up / down follow the same chrome row as the collapsed search icon.
/// Right stays on the field so the caret and the × still own it.
KeyEventResult _searchFieldArrow(
  BuildContext context,
  KeyEvent event, {
  required int? index,
  required VoidCallback? onDownEdge,
}) {
  if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
    return KeyEventResult.ignored;
  }
  final key = event.logicalKey;
  if (key != LogicalKeyboardKey.arrowLeft &&
      key != LogicalKeyboardKey.arrowUp &&
      key != LogicalKeyboardKey.arrowDown) {
    return KeyEventResult.ignored;
  }
  final row = ShellPaintTvRowScope.maybeOf(context);
  final tab = (row?.tabId ?? ShellPaintTvTabScope.tabIdOf(context) ?? '')
      .trim();
  final rowId = (row?.rowId ?? '').trim();
  if (index == null || tab.isEmpty || rowId.isEmpty) {
    return KeyEventResult.ignored;
  }
  return shellTvHandleRowArrows(
    event: event,
    tvMeta: ShellTvFocusMeta(
      tabId: tab,
      zone: ShellTvZone.topBar,
      rowId: rowId,
      itemIndex: index,
    ),
    onDownEdge: key == LogicalKeyboardKey.arrowDown ? onDownEdge : null,
  );
}

/// Keeps the open search field in the chrome-row slot the icon used.
class _OpenSearchTvSlot extends StatefulWidget {
  const _OpenSearchTvSlot({
    required this.node,
    required this.index,
    required this.child,
  });

  final FocusNode node;
  final int index;
  final Widget child;

  @override
  State<_OpenSearchTvSlot> createState() => _OpenSearchTvSlotState();
}

class _OpenSearchTvSlotState extends State<_OpenSearchTvSlot> {
  String? _tab;
  String? _row;

  @override
  void initState() {
    super.initState();
    widget.node.addListener(_onFocus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final row = ShellPaintTvRowScope.maybeOf(context);
    final tab = (row?.tabId ?? ShellPaintTvTabScope.tabIdOf(context) ?? '')
        .trim();
    final rowId = (row?.rowId ?? '').trim();
    if (tab != _tab || rowId != _row) {
      _release();
      _tab = tab.isEmpty ? null : tab;
      _row = rowId.isEmpty ? null : rowId;
    }
    _claim();
  }

  @override
  void didUpdateWidget(covariant _OpenSearchTvSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node != widget.node) {
      oldWidget.node.removeListener(_onFocus);
      widget.node.addListener(_onFocus);
      _release(node: oldWidget.node, index: oldWidget.index);
    } else if (oldWidget.index != widget.index) {
      _release(index: oldWidget.index);
    }
    _claim();
  }

  void _claim() {
    final tab = _tab;
    final row = _row;
    if (tab == null || row == null) return;
    ShellTvFocusCoordinator.registerItemNode(
      tabId: tab,
      rowId: row,
      index: widget.index,
      node: widget.node,
    );
  }

  void _release({FocusNode? node, int? index}) {
    final tab = _tab;
    final row = _row;
    if (tab == null || row == null) return;
    ShellTvFocusCoordinator.unregisterItemNode(
      tabId: tab,
      rowId: row,
      index: index ?? widget.index,
      node: node ?? widget.node,
    );
  }

  void _onFocus() {
    if (!widget.node.hasFocus) return;
    final tab = _tab;
    final row = _row;
    if (tab == null || row == null) return;
    ShellTvFocusCoordinator.onRowItemFocused(
      tabId: tab,
      rowId: row,
      index: widget.index,
      node: widget.node,
      zone: ShellTvZone.topBar,
    );
  }

  @override
  void dispose() {
    widget.node.removeListener(_onFocus);
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
