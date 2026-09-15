import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Activate [builder] only once the placeholder enters the viewport.
///
/// Inactive state must paint [placeholder] (section skeleton) — never an empty
/// box or a spinner. Pre-wipe `KitLazyViewportGate` held row shimmer in place.
class LazyViewportGate extends StatefulWidget {
  const LazyViewportGate({
    super.key,
    required this.detectorKey,
    required this.placeholderHeight,
    required this.builder,
    this.placeholder,
    this.eager = false,
  });

  final Key detectorKey;
  final double placeholderHeight;
  final Widget Function(BuildContext context) builder;

  /// Structure placeholder while off-screen / before activate.
  final Widget? placeholder;

  /// When true, skip the gate (hero / first-paint rails).
  final bool eager;

  @override
  State<LazyViewportGate> createState() => _LazyViewportGateState();
}

class _LazyViewportGateState extends State<LazyViewportGate> {
  bool _activated = false;

  @override
  void initState() {
    super.initState();
    if (widget.eager) _activated = true;
  }

  @override
  void didUpdateWidget(covariant LazyViewportGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.eager && !_activated) _activated = true;
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    if (_activated || info.visibleFraction <= 0) return;
    setState(() => _activated = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_activated) return widget.builder(context);
    final ph = widget.placeholder ??
        SizedBox(height: widget.placeholderHeight);
    return VisibilityDetector(
      key: widget.detectorKey,
      onVisibilityChanged: _onVisibilityChanged,
      child: ph,
    );
  }
}
