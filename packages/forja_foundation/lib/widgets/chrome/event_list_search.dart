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
    this.alwaysOpen = false,
    this.onCompactSearch,
    this.focusNode,
    this.debugLabel = 'event-list-search',
    this.fieldBuilder,
    this.collapsedSize = kEventListSearchCollapsed,
    this.expandedWidth = kEventListSearchExpanded,
    this.fontSize = ShellTokens.eventSearchFontSize,
    this.iconSize = ShellTokens.eventSearchIconSize,
    this.fieldIconSize = ShellTokens.eventSearchClearIconSize,
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

  /// Always show the open input (no circle tool). Used on category rail.
  final bool alwaysOpen;

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
  final ValueNotifier<bool> _toolHoveredN = ValueNotifier(false);
  bool _closeFocused = false;
  final ValueNotifier<bool> _closeHoveredN = ValueNotifier(false);
  late final FocusNode _closeFocus;

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
    _closeFocus = FocusNode(debugLabel: '${widget.debugLabel}-close');
    _focus.onKeyEvent = (node, event) {
      if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
        return KeyEventResult.ignored;
      }
      if (event.logicalKey == LogicalKeyboardKey.escape ||
          event.logicalKey == LogicalKeyboardKey.goBack) {
        _close(clearQuery: true);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        // Mid-query: let the caret move. At the end → focus the ×.
        final sel = _ctrl.selection;
        final atEnd = !sel.isValid ||
            (sel.isCollapsed && sel.baseOffset >= _ctrl.text.length);
        if (!atEnd) return KeyEventResult.ignored;
        _closeFocus.requestFocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
    if (widget.query.trim().isNotEmpty) {
      _open = true;
      _anim.value = 1;
    } else if (widget.alwaysOpen) {
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
    _toolHoveredN.dispose();
    _closeHoveredN.dispose();
    _closeFocus.dispose();
    if (_ownsFocus) _focus.dispose();
    super.dispose();
  }

  void _setToolHovered(bool h) {
    if (_toolHoveredN.value == h) return;
    _toolHoveredN.value = h;
  }

  void _setCloseHovered(bool h) {
    if (_closeHoveredN.value == h) return;
    _closeHoveredN.value = h;
  }

  void openSearch({bool edit = true}) {
    if (widget.alwaysOpen) {
      _focus.requestFocus();
      return;
    }
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

  /// Keep focus on the field (empty search results).
  void focusField() => openSearch();

  void _commit(String value) {
    widget.onQueryChanged(value);
  }

  void _close({required bool clearQuery}) {
    _focus.unfocus();
    if (clearQuery) {
      _ctrl.clear();
      _commit('');
    }
    if (widget.alwaysOpen) {
      setState(() {});
      return;
    }
    setState(() => _open = false);
    unawaited(_anim.reverse());
  }

  @override
  Widget build(BuildContext context) {
    if (widget.alwaysOpen) {
      return SizedBox(
        height: widget.collapsedSize,
        width: double.infinity,
        child: _fieldChrome(),
      );
    }
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

  Widget _collapsedIconPaint({required bool hasQuery, required bool hovered}) {
    final chromeActive = ShellPaintScope.interactiveActive(
      context,
      hovered: hovered,
      focused: _toolFocused,
    );
    final tvFocused = _tv && _toolFocused;
    final lit = chromeActive || tvFocused;
    final idleAlpha = hasQuery ? 0.12 : 0.08;
    final size = widget.collapsedSize;
    return Tooltip(
      message: widget.tooltip,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: lit
              ? ForjaShellColors.brandGreen.withValues(alpha: 0.14)
              : Colors.white.withValues(alpha: idleAlpha),
          shape: BoxShape.circle,
          border: Border.all(
            color: tvFocused
                ? ForjaShellColors.brandGreen
                : chromeActive
                    ? ForjaShellColors.brandGreen.withValues(alpha: 0.45)
                    : hasQuery
                        ? ForjaShellColors.brandGreen.withValues(alpha: 0.35)
                        : Colors.white.withValues(alpha: 0.12),
            width: tvFocused ? 1.5 : 1,
          ),
        ),
        child: Icon(
          Icons.search_rounded,
          color: lit || hasQuery
              ? ForjaShellColors.brandGreen
              : Colors.white60,
          size: widget.iconSize,
        ),
      ),
    );
  }

  Widget _collapsedIcon({required bool hasQuery}) {
    final size = widget.collapsedSize;
    return ShellPaintScope.focusableTap(
      context: context,
      onTap: () => openSearch(),
      borderRadius: size / 2,
      motion: ForjaMotionPreset.fillOnly,
      suppressInkHover: true,
      showFocusFill: false,
      tvItemIndex: widget.tvItemIndex,
      tvZone: ShellPaintTvZone.topBar,
      onLeftEdge: widget.onLeftEdge,
      onRightEdge: widget.onRightEdge,
      onDownEdge: widget.onDownEdge,
      onFocusChange: (f) => setState(() => _toolFocused = f),
      onHoverChange: _setToolHovered,
      child: ListenableBuilder(
        listenable: _toolHoveredN,
        builder: (context, _) => _collapsedIconPaint(
          hasQuery: hasQuery,
          hovered: _toolHoveredN.value,
        ),
      ),
    );
  }

  Widget _fieldChrome() {
    final field = widget.fieldBuilder?.call(
          context,
          controller: _ctrl,
          focusNode: _focus,
          onChanged: (_) {},
          onSubmitted: (v) {
            _commit(v);
          },
          onEscape: () => _close(clearQuery: true),
        ) ??
        TextField(
          controller: _ctrl,
          focusNode: _focus,
          textInputAction: TextInputAction.search,
          onSubmitted: (v) {
            _commit(v);
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
            focusNode: _closeFocus,
            onRightEdge: widget.onRightEdge,
            onDownEdge: widget.onDownEdge,
            onFocusChange: (f) => setState(() => _closeFocused = f),
            onHoverChange: _setCloseHovered,
            child: ListenableBuilder(
              listenable: _closeHoveredN,
              builder: (context, _) {
                final closeActive = ShellPaintScope.interactiveActive(
                  context,
                  hovered: _closeHoveredN.value,
                  focused: _closeFocused,
                );
                final closeTv = _tv && _closeFocused;
                return Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    Icons.close_rounded,
                    size: widget.fieldIconSize,
                    color: closeActive || closeTv
                        ? ForjaShellColors.brandGreen
                        : Colors.white54,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
