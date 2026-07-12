import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';

/// Centered play control for catalog / continue-watching cards.
/// Fades in on hover/focus; active state uses brand green (live-match theme).
/// Scales with the parent card — no extra scale here.
class ShellCardPlayOverlay extends StatelessWidget {
  const ShellCardPlayOverlay({
    super.key,
    required this.active,
    this.visible = true,
  });

  final bool active;
  final bool visible;

  static const _diameter = 48.0;
  static const _iconSize = 28.0;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: AnimatedOpacity(
            opacity: visible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              width: _diameter,
              height: _diameter,
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
                size: _iconSize,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
