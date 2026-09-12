import 'package:flutter/material.dart';
import 'package:forja/shared/shell/forja_shell_layout.dart';
import 'package:forja/shared/engine/hub/kit_row_prefetch.dart';
import 'package:visibility_detector/visibility_detector.dart';

SliverToBoxAdapter hubRowSliver(
  BuildContext context,
  Widget section, {
  required bool isFirstAfterHero,
}) {
  return SliverToBoxAdapter(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isFirstAfterHero) SizedBox(height: shellHomeRowSpacing(context)),
        RepaintBoundary(child: section),
      ],
    ),
  );
}

/// Defers [onVisible] until the widget enters the scroll viewport.
class KitLazyViewportGate extends StatefulWidget {
  const KitLazyViewportGate({
    super.key,
    required this.detectorKey,
    required this.placeholderHeight,
    required this.onVisible,
    required this.builder,
    this.prefetchSlot,
  });

  final Key detectorKey;
  final double placeholderHeight;
  final VoidCallback onVisible;
  final Widget Function(bool activated) builder;
  final KitRowPrefetchSlot? prefetchSlot;

  @override
  State<KitLazyViewportGate> createState() => _KitLazyViewportGateState();
}

class _KitLazyViewportGateState extends State<KitLazyViewportGate> {
  bool _activated = false;

  @override
  void initState() {
    super.initState();
    _registerPrefetch();
  }

  @override
  void didUpdateWidget(covariant KitLazyViewportGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.prefetchSlot != null) {
      _registerPrefetch();
    }
  }

  void _registerPrefetch() {
    final slot = widget.prefetchSlot;
    if (slot == null) return;
    slot.lane.register(slot.index, _warmFromPrefetch);
  }

  void _warmFromPrefetch() {
    _activate(prefetch: true);
  }

  void _activate({required bool prefetch}) {
    if (_activated) {
      if (!prefetch) widget.prefetchSlot?.notifyVisible();
      return;
    }
    setState(() => _activated = true);
    widget.onVisible();
    widget.prefetchSlot?.notifyVisible();
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    if (_activated || info.visibleFraction <= 0) return;
    _activate(prefetch: false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_activated) {
      return VisibilityDetector(
        key: widget.detectorKey,
        onVisibilityChanged: _onVisibilityChanged,
        child: SizedBox(height: widget.placeholderHeight),
      );
    }
    return widget.builder(true);
  }
}
