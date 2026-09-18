import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:forja/shared/engine/runtime/kit/pack_chrome_scope.dart';
import 'package:forja/shared/engine/runtime/shell/shell_bus.dart';
import 'package:forja/shell/tv/tv_browse_text_field.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
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
  }

  @override
  Widget build(BuildContext context) {
    final chrome = PackChromeScope.maybeOf(context);
    final query = chrome?.eventQuery ?? '';
    final compact = !widget.alwaysOpen &&
        MediaQuery.sizeOf(context).width < 760;
    final useTv = shellTvBrowseSearch(context);

    return EventListSearch(
      key: _searchKey,
      query: query,
      onQueryChanged: (q) => chrome?.onEventQuery(q),
      tooltip: widget.tooltip,
      placeholder: widget.placeholder,
      compact: compact,
      alwaysOpen: widget.alwaysOpen,
      onCompactSearch: () => unawaited(_openCompactDialog()),
      tvItemIndex: widget.tvItemIndex,
      onLeftEdge: widget.onLeftEdge,
      onRightEdge: widget.onRightEdge,
      onDownEdge: widget.onDownEdge,
      collapsedSize: widget.collapsedSize ?? kEventListSearchCollapsed,
      expandedWidth: widget.expandedWidth ?? kEventListSearchExpanded,
      fontSize: widget.fontSize ?? 13,
      iconSize: widget.iconSize ?? 20,
      fieldIconSize: widget.fieldIconSize ?? 18,
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
                browsePlaceholder: widget.placeholder,
                browseHintStyle: GoogleFonts.plusJakartaSans(
                  color: Colors.white38,
                  fontSize: widget.fontSize ?? 13,
                ),
                caretHeight: 16,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: widget.fontSize ?? 13,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              );
            },
    );
  }
}
