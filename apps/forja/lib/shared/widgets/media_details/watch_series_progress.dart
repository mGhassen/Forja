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
    final accent = ForjaShellColors.brandGreen;
    final label = done
        ? 'Completed · $watched/$total'
        : '$watched of $total · $pct%';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(compact ? 6 : 8),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 4 : 5,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              done
                  ? Icons.check_circle_rounded
                  : Icons.playlist_add_check_rounded,
              size: compact ? 14 : 15,
              color: accent,
            ),
            SizedBox(width: compact ? 5 : 6),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.95),
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
