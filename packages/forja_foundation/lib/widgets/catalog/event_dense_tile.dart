import 'package:flutter/material.dart';
import 'package:forja_foundation/components/crossfade_swap.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

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
    this.fontSize = ShellTokens.eventDenseFontSize,
    this.metaFontSize = ShellTokens.eventDenseMetaFontSize,
    this.pad = const EdgeInsets.symmetric(
      horizontal: ShellTokens.eventDensePadH,
      vertical: ShellTokens.eventDensePadV,
    ),
    this.iconSize = ShellTokens.eventDenseIconSize,
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
  final double fontSize;
  final double metaFontSize;
  final EdgeInsetsGeometry pad;
  final double iconSize;

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
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final titleFs = tv
        ? (fontSize == ShellTokens.eventDenseFontSize
            ? ShellTokens.eventDenseFontSizeTv
            : ShellTokens.tvTypeSize(fontSize))
        : fontSize;
    final metaFs = tv
        ? (metaFontSize == ShellTokens.eventDenseMetaFontSize
            ? ShellTokens.eventDenseMetaFontSizeTv
            : ShellTokens.tvTypeSize(metaFontSize))
        : metaFontSize;
    final ico = tv
        ? (iconSize == ShellTokens.eventDenseIconSize
            ? ShellTokens.eventDenseIconSizeTv
            : ShellTokens.chromeScale(iconSize, tv: true))
        : iconSize;
    final padding = tv &&
            pad ==
                const EdgeInsets.symmetric(
                  horizontal: ShellTokens.eventDensePadH,
                  vertical: ShellTokens.eventDensePadV,
                )
        ? const EdgeInsets.symmetric(
            horizontal: ShellTokens.eventDensePadHTv,
            vertical: ShellTokens.eventDensePadVTv,
          )
        : pad;
    final dot = tv
        ? ShellTokens.eventDenseLiveDotTv
        : ShellTokens.eventDenseLiveDot;
    final leadGap = ShellTokens.chromeScale(10, tv: tv);
    final idleLead = ShellTokens.chromeScale(18, tv: tv);
    final trailGap = ShellTokens.chromeScale(8, tv: tv);

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
            width: ShellTokens.chromeScale(3, tv: tv),
          ),
        ),
      ),
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            if (airing)
              Container(
                width: dot,
                height: dot,
                margin: EdgeInsets.only(right: leadGap),
                decoration: const BoxDecoration(
                  color: Color(0xFF22C55E),
                  shape: BoxShape.circle,
                ),
              )
            else
              SizedBox(width: idleLead),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CrossfadeSwap(
                    child: Text(
                      title,
                      key: ValueKey(title),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: titleFs,
                        height: ShellTokens.eventDenseLineHeight,
                        fontWeight: titleWeight,
                      ),
                    ),
                  ),
                  if (meta.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(
                        top: tv
                            ? ShellTokens.eventDenseMetaGapTv
                            : ShellTokens.eventDenseMetaGap,
                      ),
                      child: CrossfadeSwap(
                        child: Text(
                          meta,
                          key: ValueKey(meta),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: ForjaShellColors.textSecondary,
                            fontSize: metaFs,
                            height: ShellTokens.eventDenseLineHeight,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (viewers > 0)
              Padding(
                padding: EdgeInsets.only(left: trailGap),
                child: CrossfadeSwap(
                  child: Text(
                    '$viewers',
                    key: ValueKey(viewers),
                    style: TextStyle(
                      color: selected
                          ? ForjaShellColors.brandGreen.withValues(alpha: 0.85)
                          : ForjaShellColors.textSecondary
                              .withValues(alpha: 0.85),
                      fontSize: metaFs,
                      height: ShellTokens.eventDenseLineHeight,
                    ),
                  ),
                ),
              ),
            if (playable)
              Padding(
                padding: EdgeInsets.only(left: trailGap),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: accent,
                  size: ico,
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
