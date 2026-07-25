import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';

/// Centered play control for catalog / continue-watching cards.
/// Fades in on hover/focus; active state uses brand green and floats upward.
class ShellCardPlayOverlay extends StatefulWidget {
  const ShellCardPlayOverlay({
    super.key,
    required this.active,
    this.visible = true,
    this.onTap,
    this.focusNode,
    this.onKeyEvent,
    this.diameter = 48,
    this.iconSize = 28,
  });

  final bool active;
  final bool visible;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final KeyEventResult Function(FocusNode node, KeyEvent event)? onKeyEvent;
  final double diameter;
  final double iconSize;

  /// Card lift on hover/focus - shared with episode rows and continue watching.
  static const double cardHoverScale = 1.05;

  @override
  State<ShellCardPlayOverlay> createState() => _ShellCardPlayOverlayState();
}

class _ShellCardPlayOverlayState extends State<ShellCardPlayOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulse;
  bool _buttonHovered = false;
  bool _buttonFocused = false;

  bool get _pulseEnabled =>
      (_buttonHovered || _buttonFocused) &&
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
    // Attach a tap recognizer only while visible + actionable. An invisible
    // play control must not win the gesture arena over the parent card
    // (episode select). Hover tracking stays enabled for the pulse.
    final interactive = widget.onTap != null && widget.visible;
    final lifted = (widget.active || _buttonFocused) && widget.visible;
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
              color: widget.active || _buttonFocused
                  ? ForjaShellColors.brandGreen
                  : Colors.black.withValues(alpha: 0.42),
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.active || _buttonFocused
                    ? ForjaShellColors.brandGreen.withValues(alpha: 0.85)
                    : Colors.white.withValues(alpha: 0.24),
                width: _buttonFocused ? 2 : 1,
              ),
              boxShadow: widget.active || _buttonFocused
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
                color: widget.active || _buttonFocused
                    ? const Color(0xFF111827)
                    : Colors.white,
                size: widget.iconSize,
              ),
            ),
          ),
        ),
      ),
    );

    Widget button = MouseRegion(
      key: const ValueKey('shell-card-play-hover-target'),
      cursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
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
      child: interactive
          ? GestureDetector(
              onTap: widget.onTap,
              behavior: HitTestBehavior.opaque,
              child: buttonFace,
            )
          : buttonFace,
    );

    if (interactive && widget.focusNode != null) {
      button = Focus(
        focusNode: widget.focusNode,
        onFocusChange: (focused) {
          setState(() => _buttonFocused = focused);
          _syncPulse();
        },
        onKeyEvent: (node, event) {
          final custom = widget.onKeyEvent?.call(node, event);
          if (custom == KeyEventResult.handled) return KeyEventResult.handled;
          if (!shellTvIsActivateKey(event)) return KeyEventResult.ignored;
          widget.onTap?.call();
          return KeyEventResult.handled;
        },
        child: button,
      );
    }

    return Positioned.fill(child: Center(child: button));
  }
}
