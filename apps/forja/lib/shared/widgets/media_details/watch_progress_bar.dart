import 'package:flutter/material.dart';
import 'package:forja/shared/design/src/forja_shell_colors.dart';
import 'package:rust/rust.dart' show isInProgressResume, isWatchFinished;

class WatchProgressBar extends StatelessWidget {
  const WatchProgressBar({
    super.key,
    required this.positionMs,
    required this.durationMs,
    this.accentColor,
    this.compact = false,
  });

  final int positionMs;
  final int durationMs;
  final Color? accentColor;
  final bool compact;

  static bool isResumable(int positionMs, int durationMs) =>
      isInProgressResume(positionMs, durationMs);

  static bool isFinished(int positionMs, int durationMs) =>
      isWatchFinished(positionMs, durationMs);

  static String formatMinutes(int ms) {
    final totalMin = (ms / 60000).ceil();
    if (totalMin < 60) return '${totalMin}m';
    final h = totalMin ~/ 60;
    final m = totalMin % 60;
    return m > 0 ? '${h}h ${m}m' : '${h}h';
  }

  @override
  Widget build(BuildContext context) {
    if (durationMs <= 0) return const SizedBox.shrink();
    final fraction = (positionMs / durationMs).clamp(0.0, 1.0);
    if (!isResumable(positionMs, durationMs) && !isFinished(positionMs, durationMs)) {
      return const SizedBox.shrink();
    }

    final accent = accentColor ?? ForjaShellColors.brandGreen;
    final finished = isFinished(positionMs, durationMs);
    final remaining = durationMs - positionMs;
    final label = finished ? 'Watched' : '${formatMinutes(remaining)} left';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: compact ? 3 : 4,
            backgroundColor: Colors.white.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation(accent),
          ),
        ),
        SizedBox(height: compact ? 4 : 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (finished) ...[
              Icon(
                Icons.check_circle_rounded,
                size: compact ? 13 : 14,
                color: accent,
              ),
              SizedBox(width: compact ? 4 : 5),
            ],
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
