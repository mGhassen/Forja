import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:forja/shared/engine/hub/kit_feed_chrome.dart';
import 'package:forja/shared/engine/hub/kit_list_event_query.dart';
import 'package:forja/shared/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shell/bus/shell_bus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:forja/shared/shell/forja_shell_scope.dart';
import 'package:forja/shared/shell/forja_shell_input_policy.dart';
import 'package:forja/shared/shell/shell_focusable_tap.dart';
import 'package:forja/shared/shell/tv_browse_text_field.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';

export 'package:forja_foundation/widgets/chrome/event_list_search.dart'
    show EventListSearch, EventListSearchToolIcon;

const _kSearchCollapsed = 40.0;
const _kSearchExpanded = 260.0;

/// Expanding list search for [kit.topBar] (`action: search` / `eventSearch`).
class KitListEventSearch extends ConsumerStatefulWidget {
  const KitListEventSearch({
    super.key,
    required this.tabId,
    required this.rowId,
    required this.itemIndex,
    this.tooltip = 'Search',
    this.placeholder = 'Search…',
    this.onLeftEdge,
    this.onRightEdge,
    this.onDownEdge,
  });

  final String tabId;
  final String rowId;
  final int itemIndex;
  final String tooltip;
  final String placeholder;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;
  final VoidCallback? onDownEdge;

  @override
  ConsumerState<KitListEventSearch> createState() =>
      _KitListEventSearchState();
}

class _KitListEventSearchState extends ConsumerState<KitListEventSearch>
    with SingleTickerProviderStateMixin {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _fieldFocus =
      FocusNode(debugLabel: 'kit-list-event-search');
  final FocusNode _closeFocus =
      FocusNode(debugLabel: 'kit-list-event-search-close');
  final GlobalKey<TvBrowseTextFieldState> _fieldKey =
      GlobalKey<TvBrowseTextFieldState>();
  late final AnimationController _anim;
  late final Animation<double> _expand;
  bool _toolFocused = false;
  bool _toolHovered = false;
  bool _closeFocused = false;
  bool _closeHovered = false;
  bool _dialogOpen = false;

  bool get _tv => ShellScope.inputPolicyOf(context).useFocusableMoodChips;

  String get _chromeKey => kitChromeKeyForTab(widget.tabId);

  @override
  void initState() {
    super.initState();
    final key = kitChromeKeyForTab(widget.tabId);
    _ctrl.text = key.isEmpty ? '' : ref.read(kitListEventQueryProvider(key));
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _expand = CurvedAnimation(
      parent: _anim,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _anim.addStatusListener(_onExpandStatus);
    if (key.isNotEmpty && ref.read(kitListEventSearchOpenProvider(key))) {
      _anim.value = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncTvFieldRegistration(open: true);
      });
    }
    ShellBus.registerFindShortcutHandler(_handleFindShortcut);
  }

  void _onExpandStatus(AnimationStatus status) {
    if (!mounted) return;
    final key = _chromeKey;
    if (status == AnimationStatus.completed &&
        key.isNotEmpty &&
        ref.read(kitListEventSearchOpenProvider(key))) {
      _syncTvFieldRegistration(open: true);
    }
  }

  @override
  void dispose() {
    ShellBus.unregisterFindShortcutHandler(_handleFindShortcut);
    _anim.removeStatusListener(_onExpandStatus);
    _syncTvFieldRegistration(open: false);
    _anim.dispose();
    _ctrl.dispose();
    _fieldFocus.dispose();
    _closeFocus.dispose();
    super.dispose();
  }

  void _syncTvFieldRegistration({required bool open}) {
    if (open) {
      ShellTvFocusCoordinator.registerItemNode(
        tabId: widget.tabId,
        rowId: widget.rowId,
        index: widget.itemIndex,
        node: _fieldFocus,
      );
      return;
    }
    ShellTvFocusCoordinator.unregisterItemNode(
      tabId: widget.tabId,
      rowId: widget.rowId,
      index: widget.itemIndex,
      node: _fieldFocus,
    );
  }

  bool _handleFindShortcut() {
    if (!mounted) return false;
    _openSearch(compact: MediaQuery.sizeOf(context).width < 760);
    return true;
  }

  void _setQuery(String value) {
    final key = _chromeKey;
    if (key.isEmpty) return;
    ref.read(kitListEventQueryProvider(key).notifier).state = value;
  }

  void _setOpen(bool open) {
    final key = _chromeKey;
    if (key.isNotEmpty) {
      ref.read(kitListEventSearchOpenProvider(key).notifier).state = open;
    }
    _syncTvFieldRegistration(open: open);
  }

  void _openSearch({required bool compact}) {
    if (compact) {
      unawaited(_openCompactDialog());
      return;
    }
    final key = _chromeKey;
    if (key.isNotEmpty && ref.read(kitListEventSearchOpenProvider(key))) {
      _focusField(edit: _tv);
      return;
    }
    _setOpen(true);
    _anim.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncTvFieldRegistration(open: true);
      _focusField(edit: _tv);
    });
  }

  Future<void> _openCompactDialog() async {
    if (_dialogOpen) return;
    _dialogOpen = true;
    final key = _chromeKey;
    final initial =
        key.isEmpty ? '' : ref.read(kitListEventQueryProvider(key));
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
    _ctrl.text = result;
    _setQuery(result);
    _setOpen(result.trim().isNotEmpty);
  }

  void _closeSearch() {
    _setOpen(false);
    _setQuery('');
    _ctrl.clear();
    _fieldFocus.unfocus();
    _closeFocus.unfocus();
    _anim.reverse();
  }

  void _focusField({bool edit = false}) {
    if (!_fieldFocus.canRequestFocus) return;
    _syncTvFieldRegistration(open: true);
    _fieldFocus.requestFocus();
    ShellTvFocusCoordinator.onRowItemFocused(
      tabId: widget.tabId,
      rowId: widget.rowId,
      index: widget.itemIndex,
      node: _fieldFocus,
      zone: ShellTvZone.topBar,
    );
    if (!edit) {
      _fieldKey.currentState?.endEditing(keepFocus: true);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _fieldKey.currentState?.beginEditing();
    });
  }

  KeyEventResult _onFieldKey(FocusNode node, KeyEvent event) {
    if (!_tv) return KeyEventResult.ignored;
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final editing = _fieldKey.currentState?.isEditing ?? false;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.goBack || key == LogicalKeyboardKey.escape) {
      _closeSearch();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight && !editing) {
      if (_closeFocus.canRequestFocus) _closeFocus.requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) return KeyEventResult.handled;
    if (key == LogicalKeyboardKey.arrowDown) {
      widget.onDownEdge?.call();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft && !editing) {
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final key = _chromeKey;
    final open = key.isEmpty
        ? false
        : ref.watch(kitListEventSearchOpenProvider(key));
    final query =
        key.isEmpty ? '' : ref.watch(kitListEventQueryProvider(key));
    if (key.isNotEmpty) {
      ref.listen<bool>(kitListEventSearchOpenProvider(key), (prev, next) {
        if (prev == next) return;
        _syncTvFieldRegistration(open: next);
        if (next) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && ref.read(kitListEventSearchOpenProvider(key))) {
              _syncTvFieldRegistration(open: true);
            }
          });
        }
      });
    }
    if (_ctrl.text != query && !_fieldFocus.hasFocus) {
      _ctrl.value = TextEditingValue(
        text: query,
        selection: TextSelection.collapsed(offset: query.length),
      );
    }
    if (open && _anim.status == AnimationStatus.dismissed) {
      _anim.value = 1;
    }

    final compact = MediaQuery.sizeOf(context).width < 760;
    if (compact) {
      return _collapsedIcon(compact: true, hasQuery: query.trim().isNotEmpty);
    }

    return AnimatedBuilder(
      animation: _expand,
      builder: (context, _) {
        final t = _expand.value;
        final width =
            _kSearchCollapsed + (_kSearchExpanded - _kSearchCollapsed) * t;
        return SizedBox(
          width: width,
          height: _kSearchCollapsed,
          child: Stack(
            alignment: Alignment.centerRight,
            children: [
              if (t > 0.02)
                Opacity(
                  opacity: t.clamp(0.0, 1.0),
                  child: OverflowBox(
                    maxWidth: _kSearchExpanded,
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: _kSearchExpanded,
                      child: _fieldChrome(),
                    ),
                  ),
                ),
              if (t < 0.98)
                Opacity(
                  opacity: (1 - t).clamp(0.0, 1.0),
                  child: _collapsedIcon(
                    compact: false,
                    hasQuery: query.trim().isNotEmpty,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _collapsedIcon({required bool compact, required bool hasQuery}) {
    final policy = ShellScope.inputPolicyOf(context);
    final active = ShellInputPolicy.interactiveActive(
      policy,
      hovered: _toolHovered,
      focused: _toolFocused,
      context: context,
    );
    final tvFocused = _tv && _toolFocused;
    final idleAlpha = hasQuery ? 0.12 : 0.08;
    return shellFocusableTap(
      context: context,
      onTap: () => _openSearch(compact: compact),
      borderRadius: _kSearchCollapsed / 2,
      scaleOnFocus: 1.0,
      suppressInkHover: true,
      showFocusFill: false,
      tvTabId: widget.tabId,
      tvRowId: widget.rowId,
      tvItemIndex: widget.itemIndex,
      tvZone: ShellTvZone.topBar,
      onLeftEdge: widget.onLeftEdge,
      onRightEdge: widget.onRightEdge,
      onDownEdge: widget.onDownEdge,
      onUpEdge: () {},
      onFocusChange: (f) => setState(() => _toolFocused = f),
      onHoverChange: (h) => setState(() => _toolHovered = h),
      child: Tooltip(
        message: widget.tooltip,
        child: Container(
          width: _kSearchCollapsed,
          height: _kSearchCollapsed,
          decoration: BoxDecoration(
            color: Colors.white.withValues(
              alpha: active || tvFocused ? 0.16 : idleAlpha,
            ),
            borderRadius: BorderRadius.circular(_kSearchCollapsed / 2),
            border: Border.all(
              color: Colors.white.withValues(
                alpha: tvFocused
                    ? 0.45
                    : active
                        ? 0.28
                        : hasQuery
                            ? 0.22
                            : 0.12,
              ),
              width: tvFocused ? 1.5 : 1,
            ),
          ),
          child: Icon(
            Icons.search_rounded,
            color: active || tvFocused || hasQuery
                ? Colors.white
                : Colors.white60,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _fieldChrome() {
    final closeActive = ShellInputPolicy.interactiveActive(
      ShellScope.inputPolicyOf(context),
      hovered: _closeHovered,
      focused: _closeFocused,
      context: context,
    );
    final closeTv = _tv && _closeFocused;
    return Container(
      height: _kSearchCollapsed,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(_kSearchCollapsed / 2),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      padding: const EdgeInsets.only(left: 4, right: 4),
      child: Row(
        children: [
          const SizedBox(width: 8),
          const Icon(Icons.search_rounded, color: Colors.white70, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: TvBrowseTextField(
              key: _fieldKey,
              controller: _ctrl,
              focusNode: _fieldFocus,
              onChanged: _setQuery,
              onEscape: _closeSearch,
              onSubmitted: (_) => _focusField(edit: false),
              onKeyEvent: _onFieldKey,
              browsePlaceholder: widget.placeholder,
              browseHintStyle: GoogleFonts.plusJakartaSans(
                color: Colors.white38,
                fontSize: 13,
              ),
              caretHeight: 16,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 13,
              ),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          shellFocusableTap(
            context: context,
            onTap: _closeSearch,
            focusNode: _closeFocus,
            borderRadius: 16,
            scaleOnFocus: 1.0,
            suppressInkHover: true,
            showFocusFill: false,
            onLeftEdge: () => _focusField(edit: false),
            onRightEdge: widget.onRightEdge,
            onDownEdge: widget.onDownEdge,
            onUpEdge: () {},
            onFocusChange: (f) => setState(() => _closeFocused = f),
            onHoverChange: (h) => setState(() => _closeHovered = h),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                Icons.close_rounded,
                size: 18,
                color: closeActive || closeTv ? Colors.white : Colors.white54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
