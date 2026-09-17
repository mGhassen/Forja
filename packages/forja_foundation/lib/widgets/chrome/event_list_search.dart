import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_motion_theme.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

const kEventListSearchCollapsed = ShellTokens.eventSearchCollapsed;
const kEventListSearchExpanded = ShellTokens.eventSearchExpanded;

/// Expanding list search for `kit.topBar` (`action: eventSearch`) — Zone A.
///
/// Circle tool → inline field. Typing stays local until Enter / OK / submit
/// (or clear). Host owns committed query / TV browse field / Cmd+F via
/// [fieldBuilder].
class EventListSearch extends StatefulWidget {
  const EventListSearch({
    super.key,
    required this.query,
    required this.onQueryChanged,
    this.tooltip = 'Search',
    this.placeholder = 'Search…',
    this.compact = false,
    this.onCompactSearch,
    this.focusNode,
    this.debugLabel = 'event-list-search',
    this.fieldBuilder,
    this.collapsedSize = kEventListSearchCollapsed,
    this.expandedWidth = kEventListSearchExpanded,
    this.fontSize = ShellTokens.eventSearchFontSize,
    this.iconSize = ShellTokens.eventSearchIconSize,
    this.fieldIconSize = ShellTokens.eventSearchClearIconSize,
    this.tvTabId,
    this.tvRowId,
    this.tvItemIndex,
    this.onLeftEdge,
    this.onRightEdge,
    this.onDownEdge,
  });

  final String query;

  /// Committed query only — fired on submit / clear, not per keystroke.
  final ValueChanged<String> onQueryChanged;
  final String tooltip;
  final String placeholder;

  /// Narrow layouts — host opens a dialog instead of expanding inline.
  final bool compact;
  final VoidCallback? onCompactSearch;

  final FocusNode? focusNode;
  final String debugLabel;

  final Widget Function(
    BuildContext context, {
    required TextEditingController controller,
    required FocusNode focusNode,
    required ValueChanged<String> onChanged,
    required ValueChanged<String> onSubmitted,
    required VoidCallback onEscape,
  })? fieldBuilder;

  final double collapsedSize;
  final double expandedWidth;
  final double fontSize;
  final double iconSize;
  final double fieldIconSize;

  final String? tvTabId;
  final String? tvRowId;
  final int? tvItemIndex;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;
  final VoidCallback? onDownEdge;

  @override
  State<EventListSearch> createState() => EventListSearchState();
}

class EventListSearchState extends State<EventListSearch>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;
  late final bool _ownsFocus;
  late final AnimationController _anim;
  late final Animation<double> _expand;
  bool _open = false;
  bool _toolFocused = false;
  bool _toolHovered = false;
  bool _closeFocused = false;
  bool _closeHovered = false;

  bool get _tv => ShellPaintScope.useTvFocusOf(context);

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.query);
    _ownsFocus = widget.focusNode == null;
    _focus = widget.focusNode ?? FocusNode(debugLabel: widget.debugLabel);
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _expand = CurvedAnimation(
      parent: _anim,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _focus.onKeyEvent = (node, event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;
      if (event.logicalKey == LogicalKeyboardKey.escape ||
          event.logicalKey == LogicalKeyboardKey.goBack) {
        _close(clearQuery: true);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
    if (widget.query.trim().isNotEmpty) {
      _open = true;
      _anim.value = 1;
    }
  }

  @override
  void didUpdateWidget(EventListSearch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query && _ctrl.text != widget.query) {
      _ctrl.value = TextEditingValue(
        text: widget.query,
        selection: TextSelection.collapsed(offset: widget.query.length),
      );
      if (widget.query.trim().isNotEmpty && !_open) {
        _open = true;
        _anim.value = 1;
      }
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    _ctrl.dispose();
    if (_ownsFocus) _focus.dispose();
    super.dispose();
  }

  void openSearch({bool edit = true}) {
    if (widget.compact) {
      widget.onCompactSearch?.call();
      return;
    }
    if (_open) {
      _focus.requestFocus();
      return;
    }
    setState(() => _open = true);
    unawaited(_anim.forward());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.requestFocus();
    });
  }

  void _commit(String value) {
    widget.onQueryChanged(value);
  }

  void _close({required bool clearQuery}) {
    _focus.unfocus();
    if (clearQuery) {
      _ctrl.clear();
      _commit('');
    }
    setState(() => _open = false);
    unawaited(_anim.reverse());
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return _collapsedIcon(hasQuery: widget.query.trim().isNotEmpty);
    }

    return AnimatedBuilder(
      animation: _expand,
      builder: (context, _) {
        final t = _expand.value;
        final collapsed = widget.collapsedSize;
        final expanded = widget.expandedWidth;
        final width = collapsed + (expanded - collapsed) * t;
        return SizedBox(
          width: width,
          height: collapsed,
          child: Stack(
            alignment: Alignment.centerRight,
            children: [
              if (t > 0.02)
                Opacity(
                  opacity: t.clamp(0.0, 1.0),
                  child: OverflowBox(
                    maxWidth: expanded,
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: expanded,
                      child: _fieldChrome(),
                    ),
                  ),
                ),
              if (t < 0.98)
                Opacity(
                  opacity: (1 - t).clamp(0.0, 1.0),
                  child: _collapsedIcon(
                    hasQuery: widget.query.trim().isNotEmpty,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _collapsedIcon({required bool hasQuery}) {
    final active = ShellPaintScope.interactiveActive(
          context,
          hovered: _toolHovered,
          focused: _toolFocused,
        ) ||
        hasQuery;
    final tvFocused = _tv && _toolFocused;
    final idleAlpha = hasQuery ? 0.12 : 0.08;
    final size = widget.collapsedSize;
    final child = Tooltip(
      message: widget.tooltip,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withValues(
            alpha: active || tvFocused ? 0.16 : idleAlpha,
          ),
          shape: BoxShape.circle,
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
          size: widget.iconSize,
        ),
      ),
    );

    return ShellPaintScope.focusableTap(
      context: context,
      onTap: () => openSearch(),
      borderRadius: size / 2,
      motion: ForjaMotionPreset.fillOnly,
      suppressInkHover: true,
      showFocusFill: false,
      tvTabId: widget.tvTabId,
      tvRowId: widget.tvRowId,
      tvItemIndex: widget.tvItemIndex,
      tvZone: ShellPaintTvZone.topBar,
      onLeftEdge: widget.onLeftEdge,
      onRightEdge: widget.onRightEdge,
      onDownEdge: widget.onDownEdge,
      onFocusChange: (f) => setState(() => _toolFocused = f),
      onHoverChange: (h) => setState(() => _toolHovered = h),
      child: child,
    );
  }

  Widget _fieldChrome() {
    final closeActive = ShellPaintScope.interactiveActive(
          context,
          hovered: _closeHovered,
          focused: _closeFocused,
        );
    final closeTv = _tv && _closeFocused;
    final field = widget.fieldBuilder?.call(
          context,
          controller: _ctrl,
          focusNode: _focus,
          onChanged: (_) {},
          onSubmitted: (v) {
            _commit(v);
            _focus.unfocus();
          },
          onEscape: () => _close(clearQuery: true),
        ) ??
        TextField(
          controller: _ctrl,
          focusNode: _focus,
          textInputAction: TextInputAction.search,
          onSubmitted: (v) {
            _commit(v);
            _focus.unfocus();
          },
          style: TextStyle(color: Colors.white, fontSize: widget.fontSize),
          cursorColor: ForjaShellColors.brandGreen,
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            hintText: widget.placeholder,
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.38),
              fontSize: widget.fontSize,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        );

    return Container(
      height: widget.collapsedSize,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(widget.collapsedSize / 2),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      padding: const EdgeInsets.only(left: 4, right: 4),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Icon(
            Icons.search_rounded,
            color: Colors.white70,
            size: widget.fieldIconSize,
          ),
          const SizedBox(width: 6),
          Expanded(child: field),
          ShellPaintScope.focusableTap(
            context: context,
            onTap: () => _close(clearQuery: true),
            borderRadius: 16,
            motion: ForjaMotionPreset.fillOnly,
            suppressInkHover: true,
            showFocusFill: false,
            onRightEdge: widget.onRightEdge,
            onDownEdge: widget.onDownEdge,
            onFocusChange: (f) => setState(() => _closeFocused = f),
            onHoverChange: (h) => setState(() => _closeHovered = h),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                Icons.close_rounded,
                size: widget.fieldIconSize,
                color: closeActive || closeTv ? Colors.white : Colors.white54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
