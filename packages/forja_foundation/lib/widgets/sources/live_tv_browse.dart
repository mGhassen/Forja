import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/widgets/sources/sources_types.dart';

/// Empty key = **All** (every matched channel).
const kSourcesCategoryAll = '';

const kSourcesSearchCollapsed = 40.0;
const kSourcesSearchExpanded = 260.0;

String sourcesCategoryKey(SourcesRow row) {
  final cat = (row.subtitle ?? '').trim();
  return cat.isEmpty ? 'Other' : cat;
}

@immutable
class SourcesCategoryBucket {
  const SourcesCategoryBucket({
    required this.key,
    required this.label,
    required this.count,
  });

  final String key;
  final String label;
  final int count;
}

/// Unique categories in row order (first appearance).
List<SourcesCategoryBucket> sourcesCategoriesFromRows(
  List<SourcesRow> rows,
) {
  final order = <String>[];
  final counts = <String, int>{};
  for (final row in rows) {
    final key = sourcesCategoryKey(row);
    final prev = counts[key];
    if (prev == null) {
      order.add(key);
      counts[key] = 1;
    } else {
      counts[key] = prev + 1;
    }
  }
  return [
    for (final k in order)
      SourcesCategoryBucket(key: k, label: k, count: counts[k]!),
  ];
}

List<SourcesRow> sourcesFilterByCategory(
  List<SourcesRow> rows,
  String selectedKey,
) {
  if (selectedKey == kSourcesCategoryAll) return rows;
  return [
    for (final row in rows)
      if (sourcesCategoryKey(row) == selectedKey) row,
  ];
}

bool sourcesRowMatchesQuery(SourcesRow row, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  final hay = [
    row.title,
    row.subtitle,
    row.footer,
    ...row.badges,
  ]
      .whereType<String>()
      .map((s) => s.trim().toLowerCase())
      .where((s) => s.isNotEmpty);
  for (final part in hay) {
    if (part.contains(q)) return true;
  }
  return false;
}

List<SourcesRow> sourcesFilterByQuery(
  List<SourcesRow> rows,
  String query,
) {
  final q = query.trim();
  if (q.isEmpty) return rows;
  return [
    for (final row in rows)
      if (sourcesRowMatchesQuery(row, q)) row,
  ];
}

/// Expanding search control — icon → field (IPTV / Live TV chrome).
class SourcesExpandingSearch extends StatefulWidget {
  const SourcesExpandingSearch({
    super.key,
    required this.query,
    required this.onQueryChanged,
    this.focusNode,
    this.debugLabel = 'sources-expanding-search',
    this.useTvBrowse = false,
    this.fieldBuilder,
  });

  final String query;
  final ValueChanged<String> onQueryChanged;
  final FocusNode? focusNode;
  final String debugLabel;
  /// When true and [fieldBuilder] is null, uses a read-only-until-focus TextField.
  final bool useTvBrowse;
  /// Host injects TV browse text field when needed.
  final Widget Function(
    BuildContext context, {
    required TextEditingController controller,
    required FocusNode focusNode,
    required ValueChanged<String> onChanged,
    required VoidCallback onEscape,
  })? fieldBuilder;

  @override
  State<SourcesExpandingSearch> createState() =>
      _SourcesExpandingSearchState();
}

class _SourcesExpandingSearchState extends State<SourcesExpandingSearch>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;
  late final bool _ownsFocus;
  late final AnimationController _anim;
  late final Animation<double> _expand;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.query);
    _ownsFocus = widget.focusNode == null;
    _focus = widget.focusNode ?? FocusNode(debugLabel: widget.debugLabel);
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _expand = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
    _focus.onKeyEvent = (node, event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;
      if (event.logicalKey == LogicalKeyboardKey.escape) {
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
  void didUpdateWidget(SourcesExpandingSearch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query && _ctrl.text != widget.query) {
      _ctrl.text = widget.query;
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

  void _openSearch() {
    if (_open) {
      _focus.requestFocus();
      return;
    }
    setState(() => _open = true);
    unawaited(_anim.forward());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  void _close({required bool clearQuery}) {
    if (!_open && widget.query.isEmpty) {
      if (_anim.value == 0) return;
    }
    _focus.unfocus();
    if (clearQuery) {
      _ctrl.clear();
      widget.onQueryChanged('');
    }
    setState(() => _open = false);
    unawaited(_anim.reverse());
  }

  void _onChanged(String next) {
    widget.onQueryChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final tvFocus = widget.useTvBrowse;
    return AnimatedBuilder(
      animation: _expand,
      builder: (context, _) {
        final t = _expand.value;
        final width = kSourcesSearchCollapsed +
            (kSourcesSearchExpanded - kSourcesSearchCollapsed) * t;
        // Fixed size — no Align (Align expands in Row and gets clipped/scaled).
        return SizedBox(
          width: width,
          height: kSourcesSearchCollapsed,
          child: ClipRect(
            clipBehavior: t > 0.01 ? Clip.hardEdge : Clip.none,
            child: Stack(
              alignment: Alignment.centerLeft,
              clipBehavior: Clip.none,
              children: [
                Opacity(
                  opacity: t,
                  child: IgnorePointer(
                    ignoring: t < 0.55,
                    child: OverflowBox(
                      maxWidth: kSourcesSearchExpanded,
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: kSourcesSearchExpanded,
                        child: _field(context, tvFocus: tvFocus),
                      ),
                    ),
                  ),
                ),
                if (t < 0.95)
                  Opacity(
                    opacity: (1.0 - t * 1.4).clamp(0.0, 1.0),
                    child: IgnorePointer(
                      ignoring: t > 0.2,
                      child: _icon(context),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _icon(BuildContext context) {
    // No scale — hover/focus paint fill only (matches hero pill chrome).
    return Tooltip(
      message: 'Search channels',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _openSearch,
          customBorder: const CircleBorder(),
          child: Ink(
            width: kSourcesSearchCollapsed,
            height: kSourcesSearchCollapsed,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
              ),
            ),
            child: const Icon(
              Icons.search_rounded,
              color: Colors.white70,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(BuildContext context, {required bool tvFocus}) {
    final field = widget.fieldBuilder?.call(
          context,
          controller: _ctrl,
          focusNode: _focus,
          onChanged: _onChanged,
          onEscape: () => _close(clearQuery: true),
        ) ??
        TextField(
          controller: _ctrl,
          focusNode: _focus,
          onChanged: _onChanged,
          onSubmitted: (_) => _focus.unfocus(),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          cursorColor: ForjaShellColors.sectionAccent,
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            hintText: 'Search channels…',
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.38),
              fontSize: 13,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        );
    return Container(
      height: kSourcesSearchCollapsed,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(kSourcesSearchCollapsed / 2),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      padding: const EdgeInsets.only(left: 4, right: 4),
      child: Row(
        children: [
          const SizedBox(width: 8),
          const Icon(Icons.search_rounded, color: Colors.white70, size: 18),
          const SizedBox(width: 6),
          Expanded(child: field),
          InkWell(
            onTap: () => _close(clearQuery: true),
            borderRadius: BorderRadius.circular(16),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.close_rounded, color: Colors.white70, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

/// Categories rail row (IPTV Live visual language).
class SourcesCategoryRailRow extends StatefulWidget {
  const SourcesCategoryRailRow({
    super.key,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.listIndex,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final int? listIndex;

  @override
  State<SourcesCategoryRailRow> createState() =>
      _SourcesCategoryRailRowState();
}

class _SourcesCategoryRailRowState extends State<SourcesCategoryRailRow> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final lit = selected || _focused || _hovered;
    final tile = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: selected
            ? ForjaShellColors.sectionAccent.withValues(alpha: 0.18)
            : lit
                ? ForjaShellColors.surfaceElevated
                : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected
              ? ForjaShellColors.sectionAccent.withValues(alpha: 0.55)
              : _focused
                  ? ForjaShellColors.sectionAccent.withValues(alpha: 0.35)
                  : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected
                    ? ForjaShellColors.cinematic.textPrimary
                    : ForjaShellColors.cinematic.textSecondary,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${widget.count}',
            style: TextStyle(
              color: ForjaShellColors.cinematic.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );

    return FocusableActionDetector(
      onShowFocusHighlight: (f) => setState(() => _focused = f),
      onShowHoverHighlight: (h) => setState(() => _hovered = h),
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap();
            return null;
          },
        ),
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: tile,
        ),
      ),
    );
  }
}
