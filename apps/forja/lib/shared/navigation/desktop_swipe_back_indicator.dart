import 'package:flutter/material.dart';

import 'package:forja/shared/design/design.dart';

/// Browser-style left-edge back chevron that fills with [progress] (0..1).
class DesktopSwipeBackIndicator extends StatelessWidget {
  const DesktopSwipeBackIndicator({super.key, required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final t = progress.clamp(0.0, 1.0);
    if (t <= 0) return const SizedBox.shrink();

    final size = 44.0 + (t * 8.0);
    final opacity = (0.35 + t * 0.65).clamp(0.0, 1.0);

    return IgnorePointer(
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Opacity(
            opacity: opacity,
            child: SizedBox(
              width: size,
              height: size,
              child: CustomPaint(
                painter: _SwipeBackRingPainter(progress: t),
                child: Center(
                  child: Icon(
                    Icons.chevron_left_rounded,
                    size: size * 0.62,
                    color: ForjaShellColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SwipeBackRingPainter extends CustomPainter {
  _SwipeBackRingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;

    final bg = Paint()
      ..color = ForjaShellColors.surfaceElevated.withValues(alpha: 0.92)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bg);

    final border = Paint()
      ..color = ForjaShellColors.borderSubtle
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius - 0.75, border);

    if (progress <= 0) return;

    final arc = Paint()
      ..color = ForjaShellColors.brandGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final rect = Rect.fromCircle(center: center, radius: radius - 3);
    // Start at top; sweep clockwise with progress.
    canvas.drawArc(rect, -1.57079632679, progress * 6.28318530718, false, arc);
  }

  @override
  bool shouldRepaint(covariant _SwipeBackRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
