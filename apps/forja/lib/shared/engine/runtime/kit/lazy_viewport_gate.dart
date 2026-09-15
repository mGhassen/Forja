import 'package:flutter/material.dart';
import 'package:forja/shared/engine/runtime/kit/pack_chrome_scope.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Activate [builder] only once the placeholder enters the viewport — or when
/// the row-prefetch lane warms this slot ahead of visibility.
///
/// Inactive state must paint [placeholder] (section skeleton) — never an empty
/// box or a spinner.
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
  int? _prefetchIndex;
  int _laneGen = -1;
  PackChromeScope? _chrome;

  @override
  void initState() {
    super.initState();
    if (widget.eager) _activated = true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensurePrefetchSlot();
  }

  @override
  void didUpdateWidget(covariant LazyViewportGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.eager && !_activated) _activated = true;
  }

  void _ensurePrefetchSlot() {
    final chrome = PackChromeScope.maybeOf(context);
    _chrome = chrome;
    if (chrome == null || widget.eager) return;
    final gen = chrome.rowPrefetch.generation;
    if (_prefetchIndex != null && _laneGen == gen) return;
    _laneGen = gen;
    _prefetchIndex = chrome.rowPrefetch.claim(_warmFromPrefetch);
  }

  void _warmFromPrefetch() {
    if (!mounted || _activated) return;
    setState(() => _activated = true);
    final index = _prefetchIndex;
    if (index != null) _chrome?.rowPrefetch.notifyVisible(index);
  }

  void _activateFromViewport() {
    if (_activated) {
      final index = _prefetchIndex;
      if (index != null) _chrome?.rowPrefetch.notifyVisible(index);
      return;
    }
    setState(() => _activated = true);
    final index = _prefetchIndex;
    if (index != null) _chrome?.rowPrefetch.notifyVisible(index);
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    if (info.visibleFraction <= 0) return;
    _activateFromViewport();
  }

  @override
  Widget build(BuildContext context) {
    _ensurePrefetchSlot();
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
