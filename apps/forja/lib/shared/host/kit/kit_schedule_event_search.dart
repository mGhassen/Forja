import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:forja/shared/engine/live/kit_schedule_event_query.dart';
import 'package:forja/shared/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shell/bus/shell_bus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:forja/shared/shell/forja_shell_scope.dart';
import 'package:forja/shared/shell/forja_shell_input_policy.dart';
import 'package:forja/shared/shell/shell_focusable_tap.dart';
import 'package:forja/shared/shell/tv_browse_text_field.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
const _kSearchCollapsed = 40.0;
const _kSearchExpanded = 260.0;

/// Expanding event search for Live Sports kit top bar (left of Portals).
class KitScheduleEventSearch extends ConsumerStatefulWidget {
  const KitScheduleEventSearch({
    super.key,
    required this.tabId,
    required this.rowId,
    required this.itemIndex,
    this.onLeftEdge,
    this.onRightEdge,
    this.onDownEdge,
  });

  final String tabId;
  final String rowId;
  final int itemIndex;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;
  final VoidCallback? onDownEdge;

  @override
  ConsumerState<KitScheduleEventSearch> createState() =>
      _KitScheduleEventSearchState();
}

class _KitScheduleEventSearchState
    extends ConsumerState<KitScheduleEventSearch>
    with SingleTickerProviderStateMixin {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _fieldFocus =
      FocusNode(debugLabel: 'kit-schedule-event-search');
  final FocusNode _closeFocus =
      FocusNode(debugLabel: 'kit-schedule-event-search-close');
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

  @override
  void initState() {
    super.initState();
    _ctrl.text = ref.read(kitScheduleEventQueryProvider);
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
    if (ref.read(kitScheduleEventSearchOpenProvider)) {
      _anim.value = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncTvFieldRegistration(open: true);
      });
    }
    ShellBus.registerFindShortcutHandler(_handleFindShortcut);
  }

  void _onExpandStatus(AnimationStatus status) {
    if (!mounted) return;
    // Collapsed tool unmounts at the end of expand — reclaim the chrome slot.
    if (status == AnimationStatus.completed &&
        ref.read(kitScheduleEventSearchOpenProvider)) {
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

  /// When expanded, the collapsed Search tool unmounts — register [_fieldFocus]
  /// at the same chrome slot so D-pad (← from Portals, → from Refresh, ↑ restore)
  /// can land on the open field again (IPTV `_syncSearchChromeRow` parity).
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
    ref.read(kitScheduleEventQueryProvider.notifier).state = value;
  }

  void _setOpen(bool open) {
    ref.read(kitScheduleEventSearchOpenProvider.notifier).state = open;
    _syncTvFieldRegistration(open: open);
  }

  void _openSearch({required bool compact}) {
    if (compact) {
      unawaited(_openCompactDialog());
      return;
    }
    if (ref.read(kitScheduleEventSearchOpenProvider)) {
      _focusField(edit: _tv);
      return;
    }
    _setOpen(true);
    _anim.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Collapsed tool may still be registered mid-anim — re-claim the slot.
      _syncTvFieldRegistration(open: true);
      _focusField(edit: _tv);
    });
  }

  Future<void> _openCompactDialog() async {
    if (_dialogOpen) return;
    _dialogOpen = true;
    final initial = ref.read(kitScheduleEventQueryProvider);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final local = TextEditingController(text: initial);
        return AlertDialog(
          backgroundColor: ForjaShellColors.surfaceElevated,
          title: const Text('Search events', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: local,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Team, match, sport…',
              hintStyle: TextStyle(color: Colors.white38),
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
    final open = ref.watch(kitScheduleEventSearchOpenProvider);
    final query = ref.watch(kitScheduleEventQueryProvider);
    ref.listen<bool>(kitScheduleEventSearchOpenProvider, (prev, next) {
      if (prev == next) return;
      _syncTvFieldRegistration(open: next);
      if (next) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && ref.read(kitScheduleEventSearchOpenProvider)) {
            _syncTvFieldRegistration(open: true);
          }
        });
      }
    });
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
        message: 'Search events',
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
              browsePlaceholder: 'Search events…',
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
