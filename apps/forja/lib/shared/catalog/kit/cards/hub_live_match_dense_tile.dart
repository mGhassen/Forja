import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';

/// Dense live-match row for [`CatalogKitTypes.list`] `style: list`.
///
/// Reads presentation only — no pack ids. Driven by title/meta/airing/viewers.
class HubLiveMatchDenseTile extends StatefulWidget {
  const HubLiveMatchDenseTile({
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
  final VoidCallback? onRightEdge;

  @override
  State<HubLiveMatchDenseTile> createState() => _HubLiveMatchDenseTileState();
}

class _HubLiveMatchDenseTileState extends State<HubLiveMatchDenseTile> {
  bool _focused = false;
  bool _hovered = false;

  bool get _chrome => _focused || _hovered;

  Color get _fill {
    if (widget.selected) {
      return ForjaShellColors.brandGreen.withValues(alpha: 0.18);
    }
    if (_chrome) return ForjaShellColors.inkHover;
    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    final tv = widget.tvTabId != null && widget.tvRowId != null;
    final titleColor = !widget.playable
        ? Colors.white54
        : widget.selected
            ? ForjaShellColors.brandGreen
            : ForjaShellColors.textPrimary;
    final titleWeight =
        widget.selected || _chrome ? FontWeight.w700 : FontWeight.w600;
    final accent = widget.selected
        ? ForjaShellColors.brandGreen
        : ForjaShellColors.iconMuted;
    final row = DecoratedBox(
      decoration: BoxDecoration(
        color: _fill,
        border: Border(
          left: BorderSide(
            color: widget.selected
                ? ForjaShellColors.brandGreen
                : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            if (widget.airing)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFF22C55E),
                  shape: BoxShape.circle,
                ),
              )
            else
              const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 14,
                      fontWeight: titleWeight,
                    ),
                  ),
                  if (widget.meta.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        widget.meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ForjaShellColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (widget.viewers > 0)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  '${widget.viewers}',
                  style: TextStyle(
                    color: widget.selected
                        ? ForjaShellColors.brandGreen.withValues(alpha: 0.85)
                        : ForjaShellColors.textSecondary
                            .withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                ),
              ),
            if (widget.playable)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: accent,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
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
      onRightEdge: widget.onRightEdge,
      onFocusChange: (f) => setState(() => _focused = f),
      onHoverChange: (h) => setState(() => _hovered = h),
      child: row,
    );
  }
}

/// Subtitle line for a live [CatalogMetaItem]-shaped presentation.
String hubLiveMatchDenseMetaLine({
  required bool airing,
  String? startsAt,
  String? badge,
  List<String> genres = const [],
}) {
  final parts = <String>[];
  final sport = badge?.trim().isNotEmpty == true
      ? badge!.trim()
      : (genres.isNotEmpty ? genres.first.trim() : '');
  if (sport.isNotEmpty) parts.add(sport);
  if (airing) {
    parts.add('Live');
  } else if (startsAt != null && startsAt.trim().isNotEmpty) {
    parts.add(_formatStartsAt(startsAt.trim()));
  }
  return parts.join(' · ');
}

String _formatStartsAt(String raw) {
  final asInt = int.tryParse(raw);
  if (asInt != null) {
    final ms = asInt > 20000000000 ? asInt : asInt * 1000;
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
  final parsed = DateTime.tryParse(raw);
  if (parsed != null) {
    final local = parsed.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
  return raw;
}
