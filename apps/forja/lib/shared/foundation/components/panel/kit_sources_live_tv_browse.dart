import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/foundation/components/panel/kit_sources_panel.dart';
import 'package:forja/shared/foundation/primitives/primitives.dart';

/// Empty key = **All** (every matched channel).
const kKitSourcesCategoryAll = '';

const kKitSourcesSearchCollapsed = 40.0;
const kKitSourcesSearchExpanded = 260.0;

String kitSourcesCategoryKey(KitSourcesRow row) {
  final cat = (row.subtitle ?? '').trim();
  return cat.isEmpty ? 'Other' : cat;
}

@immutable
class KitSourcesCategoryBucket {
  const KitSourcesCategoryBucket({
    required this.key,
    required this.label,
    required this.count,
  });

  final String key;
  final String label;
  final int count;
}

/// Unique categories in row order (first appearance).
List<KitSourcesCategoryBucket> kitSourcesCategoriesFromRows(
  List<KitSourcesRow> rows,
) {
  final order = <String>[];
  final counts = <String, int>{};
  for (final row in rows) {
    final key = kitSourcesCategoryKey(row);
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
      KitSourcesCategoryBucket(key: k, label: k, count: counts[k]!),
  ];
}

List<KitSourcesRow> kitSourcesFilterByCategory(
  List<KitSourcesRow> rows,
  String selectedKey,
) {
  if (selectedKey == kKitSourcesCategoryAll) return rows;
  return [
    for (final row in rows)
      if (kitSourcesCategoryKey(row) == selectedKey) row,
  ];
}

bool kitSourcesRowMatchesQuery(KitSourcesRow row, String query) {
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

List<KitSourcesRow> kitSourcesFilterByQuery(
  List<KitSourcesRow> rows,
  String query,
) {
  final q = query.trim();
  if (q.isEmpty) return rows;
  return [
    for (final row in rows)
      if (kitSourcesRowMatchesQuery(row, q)) row,
  ];
}

/// Expanding search control — icon → field (IPTV / Live TV chrome).
class KitSourcesExpandingSearch extends StatefulWidget {
  const KitSourcesExpandingSearch({
    super.key,
    required this.query,
    required this.onQueryChanged,
    this.focusNode,
    this.debugLabel = 'kit-sources-expanding-search',
  });

  final String query;
  final ValueChanged<String> onQueryChanged;
  final FocusNode? focusNode;
  final String debugLabel;

  @override
  State<KitSourcesExpandingSearch> createState() =>
      _KitSourcesExpandingSearchState();
}

class _KitSourcesExpandingSearchState extends State<KitSourcesExpandingSearch>
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
  void didUpdateWidget(KitSourcesExpandingSearch oldWidget) {
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
    final tvFocus = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    return AnimatedBuilder(
      animation: _expand,
      builder: (context, _) {
        final t = _expand.value;
        final width = kKitSourcesSearchCollapsed +
            (kKitSourcesSearchExpanded - kKitSourcesSearchCollapsed) * t;
        // Fixed size — no Align (Align expands in Row and gets clipped/scaled).
        return SizedBox(
          width: width,
          height: kKitSourcesSearchCollapsed,
          child: ClipRect(
            child: Stack(
              alignment: Alignment.centerLeft,
              clipBehavior: Clip.hardEdge,
              children: [
                Opacity(
                  opacity: t,
                  child: IgnorePointer(
                    ignoring: t < 0.55,
                    child: OverflowBox(
                      maxWidth: kKitSourcesSearchExpanded,
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: kKitSourcesSearchExpanded,
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
    return shellFocusableTap(
      context: context,
      onTap: _openSearch,
      borderRadius: kKitSourcesSearchCollapsed / 2,
      child: Tooltip(
        message: 'Search channels',
        child: Container(
          width: kKitSourcesSearchCollapsed,
          height: kKitSourcesSearchCollapsed,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(kKitSourcesSearchCollapsed / 2),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: const Icon(
            Icons.search_rounded,
            color: Colors.white70,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _field(BuildContext context, {required bool tvFocus}) {
    return Container(
      height: kKitSourcesSearchCollapsed,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(kKitSourcesSearchCollapsed / 2),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      padding: const EdgeInsets.only(left: 4, right: 4),
      child: Row(
        children: [
          const SizedBox(width: 8),
          const Icon(Icons.search_rounded, color: Colors.white70, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: tvFocus
                ? TvBrowseTextField(
                    controller: _ctrl,
                    focusNode: _focus,
                    onChanged: _onChanged,
                    onEscape: () => _close(clearQuery: true),
                    onSubmitted: (_) => _focus.unfocus(),
                    browsePlaceholder: 'Search channels…',
                    browseHintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.38),
                      fontSize: 13,
                    ),
                    caretHeight: 16,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  )
                : TextField(
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
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
          ),
          shellFocusableTap(
            context: context,
            onTap: () => _close(clearQuery: true),
            borderRadius: 16,
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
class KitSourcesCategoryRailRow extends StatefulWidget {
  const KitSourcesCategoryRailRow({
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
  State<KitSourcesCategoryRailRow> createState() =>
      _KitSourcesCategoryRailRowState();
}

class _KitSourcesCategoryRailRowState extends State<KitSourcesCategoryRailRow> {
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

    return shellFocusableTap(
      context: context,
      onTap: widget.onTap,
      borderRadius: 8,
      scaleOnFocus: 1.0,
      showFocusFill: false,
      listIndex: widget.listIndex,
      onFocusChange: (f) => setState(() => _focused = f),
      onHoverChange: (h) => setState(() => _hovered = h),
      child: tile,
    );
  }
}
