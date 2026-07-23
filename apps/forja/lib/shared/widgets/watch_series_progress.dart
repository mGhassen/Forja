import 'package:flutter/material.dart';
import 'package:forja/shared/design/src/forja_shell_colors.dart';

/// Details-only series / anime / drama watched aggregate.
class WatchSeriesProgress extends StatelessWidget {
  const WatchSeriesProgress({
    super.key,
    required this.watched,
    required this.total,
    this.compact = false,
  });

  final int watched;
  final int total;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (total <= 0 || watched <= 0) return const SizedBox.shrink();
    final done = watched >= total;
    final pct = ((watched / total) * 100).round().clamp(0, 100);
    final accent = ForjaShellColors.progressFill;
    final label = done
        ? 'Completed · $watched/$total'
        : '$watched of $total · $pct%';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          done ? Icons.check_circle_rounded : Icons.playlist_add_check_rounded,
          size: compact ? 13 : 14,
          color: done ? accent : Colors.white.withValues(alpha: 0.7),
        ),
        SizedBox(width: compact ? 4 : 5),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: compact ? 11 : 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
