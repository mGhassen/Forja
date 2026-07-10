import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Skeleton-style light sweep + optional animated rainbow fill when focused.
class ForjaFocusEffectStack extends StatefulWidget {
  const ForjaFocusEffectStack({
    super.key,
    required this.focused,
    required this.borderRadius,
    required this.child,
    this.rainbowBackground = false,
  });

  final bool focused;
  final BorderRadius borderRadius;
  final Widget child;
  final bool rainbowBackground;

  @override
  State<ForjaFocusEffectStack> createState() => _ForjaFocusEffectStackState();
}

class _ForjaFocusEffectStackState extends State<ForjaFocusEffectStack>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    if (widget.focused) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant ForjaFocusEffectStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focused && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.focused && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.focused) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          clipBehavior: Clip.none,
          fit: StackFit.passthrough,
          children: [
            if (widget.rainbowBackground)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: widget.borderRadius,
                    gradient: _rainbowGradient(_controller.value),
                  ),
                ),
              ),
            child!,
            Positioned.fill(
              child: ClipRRect(
                borderRadius: widget.borderRadius,
                child: CustomPaint(
                  painter: _FocusShimmerPainter(progress: _controller.value),
                ),
              ),
            ),
          ],
        );
      },
      child: widget.child,
    );
  }

  LinearGradient _rainbowGradient(double t) {
    Color at(double hueOffset) {
      final hue = ((t * 360) + hueOffset) % 360;
      return HSVColor.fromAHSV(1, hue, 0.82, 0.96).toColor();
    }

    return LinearGradient(
      begin: Alignment(-1 + t * 2, -0.4),
      end: Alignment(1 + t * 2, 0.4),
      colors: [
        at(0),
        at(72),
        at(144),
        at(216),
        at(288),
        at(360),
      ],
    );
  }
}

class _FocusShimmerPainter extends CustomPainter {
  _FocusShimmerPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final bandWidth = size.width * 0.45;
    final travel = size.width + bandWidth;
    final left = -bandWidth + travel * progress;

    final rect = Rect.fromLTWH(left, 0, bandWidth, size.height);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: 0.08),
          Colors.white.withValues(alpha: 0.22),
          Colors.white.withValues(alpha: 0.08),
          Colors.white.withValues(alpha: 0),
        ],
        stops: const [0, 0.25, 0.5, 0.75, 1],
      ).createShader(rect);

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(rect, paint);
    canvas.restore();

    final edgeGlow = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.06 + math.sin(progress * math.pi * 2) * 0.02),
          Colors.white.withValues(alpha: 0),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, edgeGlow);
  }

  @override
  bool shouldRepaint(covariant _FocusShimmerPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
