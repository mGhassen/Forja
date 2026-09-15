import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';

/// Dense schedule/event row paint — props only (RFC-106 Zone A).
///
/// Host wraps with focus / TV chrome when needed.
class EventDenseTile extends StatelessWidget {
  const EventDenseTile({
    super.key,
    required this.title,
    required this.meta,
    required this.airing,
    required this.viewers,
    required this.selected,
    this.playable = true,
    this.focused = false,
    this.hovered = false,
    this.onTap,
  });

  final String title;
  final String meta;
  final bool airing;
  final int viewers;
  final bool selected;
  final bool playable;
  final bool focused;
  final bool hovered;
  final VoidCallback? onTap;

  bool get _chrome => focused || hovered;

  Color get _fill {
    if (selected) {
      return ForjaShellColors.brandGreen.withValues(alpha: 0.18);
    }
    if (_chrome) return ForjaShellColors.inkHover;
    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    final titleColor = !playable
        ? Colors.white54
        : selected
            ? ForjaShellColors.brandGreen
            : ForjaShellColors.textPrimary;
    final titleWeight =
        selected || _chrome ? FontWeight.w700 : FontWeight.w600;
    final accent =
        selected ? ForjaShellColors.brandGreen : ForjaShellColors.iconMuted;

    final row = DecoratedBox(
      decoration: BoxDecoration(
        color: _fill,
        border: Border(
          left: BorderSide(
            color: selected ? ForjaShellColors.brandGreen : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            if (airing)
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
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 14,
                      fontWeight: titleWeight,
                    ),
                  ),
                  if (meta.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        meta,
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
            if (viewers > 0)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  '$viewers',
                  style: TextStyle(
                    color: selected
                        ? ForjaShellColors.brandGreen.withValues(alpha: 0.85)
                        : ForjaShellColors.textSecondary
                            .withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                ),
              ),
            if (playable)
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

    if (onTap == null) return row;
    return GestureDetector(onTap: onTap, child: row);
  }
}

/// Subtitle line for an event-shaped presentation.
String eventDenseMetaLine({
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
