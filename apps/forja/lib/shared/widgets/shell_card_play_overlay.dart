import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';

/// Centered play control for catalog / continue-watching cards.
/// Fades in on hover/focus; active state uses brand green and floats upward.
class ShellCardPlayOverlay extends StatefulWidget {
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
  State<ShellCardPlayOverlay> createState() => _ShellCardPlayOverlayState();
}

class _ShellCardPlayOverlayState extends State<ShellCardPlayOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulse;
  bool _buttonHovered = false;

  bool get _pulseEnabled =>
      _buttonHovered &&
      widget.active &&
      widget.visible &&
      !(MediaQuery.maybeOf(context)?.disableAnimations ?? false);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _pulse = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.12,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 8,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.12,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 8,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.07,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 6,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.07,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 8,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 70),
    ]).animate(_pulseController);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant ShellCardPlayOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();
  }

  void _syncPulse() {
    if (_pulseEnabled) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat();
      }
    } else {
      _pulseController
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lifted = widget.active && widget.visible;
    final buttonFace = AnimatedSlide(
      offset: lifted ? const Offset(0, -0.1) : Offset.zero,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: AnimatedScale(
        scale: lifted ? 1.1 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: widget.visible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            width: widget.diameter,
            height: widget.diameter,
            decoration: BoxDecoration(
              color: widget.active
                  ? ForjaShellColors.brandGreen
                  : Colors.black.withValues(alpha: 0.42),
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.active
                    ? ForjaShellColors.brandGreen.withValues(alpha: 0.85)
                    : Colors.white.withValues(alpha: 0.24),
              ),
              boxShadow: widget.active
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: ScaleTransition(
              key: const ValueKey('shell-card-play-pulse'),
              scale: _pulse,
              child: Icon(
                Icons.play_arrow_rounded,
                color: widget.active ? const Color(0xFF111827) : Colors.white,
                size: widget.iconSize,
              ),
            ),
          ),
        ),
      ),
    );

    final button = MouseRegion(
      key: const ValueKey('shell-card-play-hover-target'),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      onEnter: (_) {
        if (_buttonHovered) return;
        setState(() => _buttonHovered = true);
        _syncPulse();
      },
      onExit: (_) {
        if (!_buttonHovered) return;
        setState(() => _buttonHovered = false);
        _syncPulse();
      },
      child: widget.onTap != null
          ? GestureDetector(
              onTap: widget.onTap,
              behavior: HitTestBehavior.opaque,
              child: buttonFace,
            )
          : buttonFace,
    );

    return Positioned.fill(child: Center(child: button));
  }
}
