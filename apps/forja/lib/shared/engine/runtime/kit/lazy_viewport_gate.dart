import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Activate [builder] only once the placeholder enters the viewport.
///
/// Pre-wipe `KitLazyViewportGate` — keeps rails from firing every pack load
/// until the user scrolls near them.
class LazyViewportGate extends StatefulWidget {
  const LazyViewportGate({
    super.key,
    required this.detectorKey,
    required this.placeholderHeight,
    required this.builder,
    this.eager = false,
  });

  final Key detectorKey;
  final double placeholderHeight;
  final Widget Function(BuildContext context) builder;

  /// When true, skip the gate (hero / first rails).
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

  void _onVisibilityChanged(VisibilityInfo info) {
    if (_activated || info.visibleFraction <= 0) return;
    setState(() => _activated = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_activated) return widget.builder(context);
    return VisibilityDetector(
      key: widget.detectorKey,
      onVisibilityChanged: _onVisibilityChanged,
      child: SizedBox(height: widget.placeholderHeight),
    );
  }
}
