import 'package:flutter/material.dart';
import 'package:forja_foundation/components/settled_network_image.dart';

/// Slow cinematic pan & zoom. Host passes [enableMotion] (shell Ken Burns policy).
class KenBurnsBackdrop extends StatefulWidget {
  const KenBurnsBackdrop({
    super.key,
    required this.imageUrl,
    this.tintDominant,
    this.tintMuted,
    this.blurSigma = 28,
    this.cycleDuration = const Duration(seconds: 25),
    this.minScale = 1.0,
    this.maxScale = 1.25,
    this.showColorTint = true,
    this.panBegin = const Alignment(-0.5, -0.3),
    this.panEnd = const Alignment(0.5, 0.2),
    this.fit = BoxFit.cover,
    this.imageAlignment = Alignment.topCenter,
    this.filterQuality = FilterQuality.low,
    this.enableMotion = true,
  });

  final String imageUrl;
  final Color? tintDominant;
  final Color? tintMuted;
  final double blurSigma;
  final Duration cycleDuration;
  final double minScale;
  final double maxScale;
  final bool showColorTint;
  final Alignment panBegin;
  final Alignment panEnd;
  final BoxFit fit;
  final Alignment imageAlignment;
  final FilterQuality filterQuality;
  final bool enableMotion;

  @override
  State<KenBurnsBackdrop> createState() => _KenBurnsBackdropState();
}

class _KenBurnsBackdropState extends State<KenBurnsBackdrop>
    with TickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _scaleAnimation;
  Animation<Alignment>? _alignAnimation;
  bool? _motionEnabled;

  void _syncMotion() {
    final enabled = widget.enableMotion;
    if (_motionEnabled == enabled) return;
    _motionEnabled = enabled;
    if (enabled) {
      _setupAnimations();
    } else {
      _tearDownAnimations();
    }
  }

  @override
  void initState() {
    super.initState();
    _syncMotion();
  }

  @override
  void didUpdateWidget(KenBurnsBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enableMotion != widget.enableMotion) {
      _syncMotion();
    }
    if (_motionEnabled != true) return;
    if (oldWidget.cycleDuration != widget.cycleDuration ||
        oldWidget.minScale != widget.minScale ||
        oldWidget.maxScale != widget.maxScale ||
        oldWidget.panBegin != widget.panBegin ||
        oldWidget.panEnd != widget.panEnd) {
      _tearDownAnimations();
      _setupAnimations();
    }
  }

  void _tearDownAnimations() {
    _controller?.dispose();
    _controller = null;
    _scaleAnimation = null;
    _alignAnimation = null;
  }

  void _setupAnimations() {
    _tearDownAnimations();
    final controller = AnimationController(
      duration: widget.cycleDuration,
      vsync: this,
    )..repeat(reverse: true);
    _controller = controller;
    _scaleAnimation = Tween<double>(
      begin: widget.minScale,
      end: widget.maxScale,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
    _alignAnimation = AlignmentTween(
      begin: widget.panBegin,
      end: widget.panEnd,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _tearDownAnimations();
    super.dispose();
  }

  Widget _image() {
    return SettledNetworkImage(
      imageUrl: widget.imageUrl,
      fit: widget.fit,
      alignment: widget.imageAlignment,
      filterQuality: widget.filterQuality,
    );
  }

  Widget _tintOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(
              const Color(0xFF141414),
              widget.tintDominant ?? const Color(0xFF141414),
              0.35,
            )!
                .withValues(alpha: 0.75),
            Color.lerp(
              const Color(0xFF000000),
              widget.tintMuted ?? const Color(0xFF000000),
              0.15,
            )!
                .withValues(alpha: 0.88),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final scale = _scaleAnimation;
    final align = _alignAnimation;
    final motion = _motionEnabled == true &&
        controller != null &&
        scale != null &&
        align != null;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (motion)
          AnimatedBuilder(
            animation: controller,
            builder: (context, child) {
              return Transform.scale(
                scale: scale.value,
                alignment: align.value,
                child: child,
              );
            },
            child: _image(),
          )
        else
          _image(),
        if (widget.showColorTint) _tintOverlay(),
      ],
    );
  }
}
