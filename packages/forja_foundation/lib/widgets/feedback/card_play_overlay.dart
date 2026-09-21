import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_motion_theme.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/event_card_tokens.dart';

/// Centered play control for catalog / continue-watching cards.
/// Fades in when [visible]; brand green + float + heartbeat while [active]
/// or while the play control itself is hovered/focused.
class ShellCardPlayOverlay extends StatefulWidget {
  const ShellCardPlayOverlay({
    super.key,
    required this.active,
    this.visible = true,
    this.onTap,
    this.focusNode,
    this.onKeyEvent,
    this.diameter,
    this.iconSize,
  });

  /// When true, forces green + float + heartbeat without a button hover
  /// (TV card focus, live cards). Continue-watching on desktop leaves this
  /// false so only play-button hover accents.
  final bool active;
  final bool visible;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final KeyEventResult Function(FocusNode node, KeyEvent event)? onKeyEvent;
  /// Null → [EventCardTokens.playOverlaySize] / TV token.
  final double? diameter;
  /// Null → [EventCardTokens.playIconSize] / TV token.
  final double? iconSize;

  /// Card lift on hover/focus — prefer [ForjaMotionTheme.cardLift] at call sites.
  @Deprecated('Use ForjaMotionTheme.of(context).cardLift.hoverScale')
  static double get cardHoverScale =>
      ForjaMotionTheme.defaults.cardLift.hoverScale;

  @override
  State<ShellCardPlayOverlay> createState() => _ShellCardPlayOverlayState();
}

class _ShellCardPlayOverlayState extends State<ShellCardPlayOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late Animation<double> _pulse;
  bool _buttonHovered = false;
  bool _buttonFocused = false;

  bool get _accented =>
      widget.active || _buttonHovered || _buttonFocused;

  /// Heartbeat with the green accent — button hover/focus, or parent [active]
  /// (TV card focus / live cards that force the play control).
  bool get _pulseEnabled =>
      _accented &&
      widget.visible &&
      !(MediaQuery.maybeOf(context)?.disableAnimations ?? false);

  @override
  void initState() {
    super.initState();
    final pulse = ForjaMotionTheme.defaults.playPulse;
    _pulseController = AnimationController(
      vsync: this,
      duration: pulse.duration,
    );
    _pulse = _buildPulse(pulse);
  }

  Animation<double> _buildPulse(ForjaPulseMotionSpec pulse) {
    return TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: pulse.peakScale,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 8,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: pulse.peakScale,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 8,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: pulse.midScale,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 6,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: pulse.midScale,
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
    final pulse = ForjaMotionTheme.of(context).playPulse;
    if (_pulseController.duration != pulse.duration) {
      _pulseController.duration = pulse.duration;
    }
    _pulse = _buildPulse(pulse);
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

  /// Defer past MouseTracker.deviceUpdate — nested under card MouseRegions.
  void _queueButtonHover(bool hovered) {
    if (_buttonHovered == hovered) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _buttonHovered == hovered) return;
      setState(() => _buttonHovered = hovered);
      _syncPulse();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = ForjaMotionTheme.of(context);
    final lift = motion.playButtonLift;
    // Attach a tap recognizer only while visible + actionable. An invisible
    // play control must not win the gesture arena over the parent card
    // (episode select). Hover tracking stays enabled for the pulse.
    final interactive = widget.onTap != null && widget.visible;
    final lifted = _accented && widget.visible;
    final diameter =
        widget.diameter ?? EventCardTokens.playOverlaySizeOf(context);
    final iconSize =
        widget.iconSize ?? EventCardTokens.playIconSizeOf(context);
    final buttonFace = AnimatedSlide(
      offset: lifted ? const Offset(0, -0.1) : Offset.zero,
      duration: lift.duration,
      curve: lift.resolvedCurve,
      child: AnimatedScale(
        scale: lifted ? lift.hoverScale : 1.0,
        duration: lift.duration,
        curve: lift.resolvedCurve,
        child: AnimatedOpacity(
          opacity: widget.visible ? 1.0 : 0.0,
          duration: lift.duration,
          child: AnimatedContainer(
            duration: motion.fillOnly.duration,
            curve: motion.fillOnly.resolvedCurve,
            width: diameter,
            height: diameter,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: lifted
                  ? ForjaShellColors.brandGreen
                  : Colors.black.withValues(alpha: 0.42),
              shape: BoxShape.circle,
              border: Border.all(
                color: lifted
                    ? ForjaShellColors.brandGreen.withValues(alpha: 0.85)
                    : Colors.white.withValues(alpha: 0.24),
                width: _buttonFocused ? 2 : 1,
              ),
              boxShadow: lifted
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
              color: lifted ? const Color(0xFF111827) : Colors.white,
              size: iconSize,
            ),
          ),
        ),
      ),
    );

    Widget button = MouseRegion(
      key: const ValueKey('shell-card-play-hover-target'),
      cursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => _queueButtonHover(true),
      onExit: (_) => _queueButtonHover(false),
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
          if (!ShellPaintScope.isActivateKeyOf(context, event)) {
            return KeyEventResult.ignored;
          }
          widget.onTap?.call();
          return KeyEventResult.handled;
        },
        child: button,
      );
    }

    // Heartbeat scales the whole circle (outside the fixed diameter box so
    // peak scale is not clipped). Parent stacks often use [StackFit.expand].
    return Center(
      child: ScaleTransition(
        key: const ValueKey('shell-card-play-pulse'),
        scale: _pulse,
        child: SizedBox(
          width: diameter,
          height: diameter,
          child: button,
        ),
      ),
    );
  }
}
