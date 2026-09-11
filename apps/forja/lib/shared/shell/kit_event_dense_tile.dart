import 'package:flutter/material.dart';
import 'package:forja/shared/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/shell/shell_focusable_tap.dart';
import 'package:forja_foundation/widgets/catalog/event_dense_tile.dart';

export 'package:forja_foundation/widgets/catalog/event_dense_tile.dart'
    show EventDenseTile, eventDenseMetaLine;

/// Host TV/focus wrapper around [EventDenseTile].
class KitEventDenseTile extends StatefulWidget {
  const KitEventDenseTile({
    super.key,
    required this.title,
    required this.meta,
    required this.airing,
    required this.viewers,
    required this.selected,
    required this.index,
    required this.onTap,
    this.playable = true,
    this.tvTabId,
    this.tvRowId,
    this.onUpEdge,
    this.onLeftEdge,
    this.onRightEdge,
  });

  final String title;
  final String meta;
  final bool airing;
  final int viewers;
  final bool selected;
  final int index;
  final bool playable;
  final VoidCallback? onTap;
  final String? tvTabId;
  final String? tvRowId;
  final VoidCallback? onUpEdge;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;

  @override
  State<KitEventDenseTile> createState() => _KitEventDenseTileState();
}

class _KitEventDenseTileState extends State<KitEventDenseTile> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tv = widget.tvTabId != null && widget.tvRowId != null;
    final paint = EventDenseTile(
      title: widget.title,
      meta: widget.meta,
      airing: widget.airing,
      viewers: widget.viewers,
      selected: widget.selected,
      playable: widget.playable,
      focused: _focused,
      hovered: _hovered,
    );

    return shellFocusableTap(
      context: context,
      onTap: widget.onTap,
      borderRadius: 0,
      scaleOnFocus: 1.0,
      showFocusFill: false,
      showFocusBorder: false,
      showFocusRail: false,
      suppressInkHover: true,
      listIndex: widget.index,
      gridIndex: tv ? widget.index : null,
      gridColumns: tv ? 1 : null,
      tvTabId: tv ? widget.tvTabId : null,
      tvRowId: tv ? widget.tvRowId : null,
      tvZone: tv ? ShellTvZone.grid : null,
      tvItemIndex: tv ? widget.index : null,
      ensureVisibleMode: ShellTvEnsureVisibleMode.item,
      onUpEdge: widget.onUpEdge,
      onLeftEdge: widget.onLeftEdge,
      onRightEdge: widget.onRightEdge,
      onFocusChange: (f) => setState(() => _focused = f),
      onHoverChange: (h) => setState(() => _hovered = h),
      child: paint,
    );
  }
}

/// Legacy alias for [eventDenseMetaLine].
String kitEventDenseMetaLine({
  required bool airing,
  String? startsAt,
  String? badge,
  List<String> genres = const [],
}) =>
    eventDenseMetaLine(
      airing: airing,
      startsAt: startsAt,
      badge: badge,
      genres: genres,
    );
