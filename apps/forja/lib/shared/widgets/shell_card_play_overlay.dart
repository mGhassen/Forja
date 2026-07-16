import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';

/// Centered play control for catalog / continue-watching cards.
/// Fades in on hover/focus; active state uses brand green and floats upward.
class ShellCardPlayOverlay extends StatelessWidget {
  const ShellCardPlayOverlay({
    super.key,
    required this.active,
    this.visible = true,
    this.onTap,
    this.diameter = 48,
    this.iconSize = 28,
  });

  final bool active;
  final bool visible;
  final VoidCallback? onTap;
  final double diameter;
  final double iconSize;

  /// Card lift on hover/focus — shared with episode rows and continue watching.
  static const double cardHoverScale = 1.05;

  @override
  Widget build(BuildContext context) {
    final lifted = active && visible;
    final button = AnimatedSlide(
      offset: lifted ? const Offset(0, -0.1) : Offset.zero,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: AnimatedScale(
        scale: lifted ? 1.1 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: visible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            width: diameter,
            height: diameter,
            decoration: BoxDecoration(
              color: active
                  ? ForjaShellColors.brandGreen
                  : Colors.black.withValues(alpha: 0.42),
              shape: BoxShape.circle,
              border: Border.all(
                color: active
                    ? ForjaShellColors.brandGreen.withValues(alpha: 0.85)
                    : Colors.white.withValues(alpha: 0.24),
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              Icons.play_arrow_rounded,
              color: active ? const Color(0xFF111827) : Colors.white,
              size: iconSize,
            ),
          ),
        ),
      ),
    );

    final centered = Center(
      child: onTap != null
          ? MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onTap,
                behavior: HitTestBehavior.opaque,
                child: button,
              ),
            )
          : button,
    );

    return Positioned.fill(
      child: onTap == null ? IgnorePointer(child: centered) : centered,
    );
  }
}
