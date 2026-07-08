import 'package:flutter/material.dart';
import 'package:forja/shared/design/src/forja_shell_colors.dart';

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

  static bool isResumable(int positionMs, int durationMs) {
    if (durationMs <= 0) return false;
    final p = positionMs / durationMs;
    return p >= 0.02 && p < 0.9;
  }

  static bool isFinished(int positionMs, int durationMs) {
    if (durationMs <= 0) return false;
    return positionMs / durationMs >= 0.9;
  }

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

    final accent = accentColor ?? ForjaShellColors.progressFill;
    final remaining = durationMs - positionMs;
    final label = isFinished(positionMs, durationMs)
        ? 'Watched'
        : '${formatMinutes(remaining)} left';

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
