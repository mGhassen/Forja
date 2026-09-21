import 'package:flutter/material.dart';
import 'package:forja/shared/engine/runtime/kit/pack_chrome_scope.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Activate [builder] only once the placeholder enters the viewport — or when
/// the row-prefetch lane warms this slot ahead of visibility.
///
/// Inactive state must paint [placeholder] (section skeleton) — never an empty
/// box or a spinner.
///
/// Activation is sticky for the session ([_activatedKeys]) so a soft remount /
/// tab hide→show does not flash shimmer again when memo already has the rail.
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
  /// Survives State remounts for the same [LazyViewportGate.detectorKey].
  static final Set<String> _activatedKeys = {};

  bool _activated = false;
  int? _prefetchIndex;
  int _laneGen = -1;
  PackChromeScope? _chrome;

  String get _stickyId => widget.detectorKey.toString();

  @override
  void initState() {
    super.initState();
    if (widget.eager || _activatedKeys.contains(_stickyId)) {
      _activated = true;
      _activatedKeys.add(_stickyId);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensurePrefetchSlot();
  }

  @override
  void didUpdateWidget(covariant LazyViewportGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.eager && !_activated) {
      _markActivated();
    }
  }

  void _markActivated() {
    _activated = true;
    _activatedKeys.add(_stickyId);
  }

  void _ensurePrefetchSlot() {
    final chrome = PackChromeScope.maybeOf(context);
    _chrome = chrome;
    if (chrome == null || widget.eager || _activated) return;
    final gen = chrome.rowPrefetch.generation;
    if (_prefetchIndex != null && _laneGen == gen) return;
    _laneGen = gen;
    _prefetchIndex = chrome.rowPrefetch.claim(_warmFromPrefetch);
  }

  void _warmFromPrefetch() {
    // Activate only — do not notifyVisible. Cascading here would load every
    // claimed row below the fold; ahead is meant to stay a fixed lead of
    // [kKitRowPrefetchAhead] from the actually visible row.
    if (!mounted || _activated) return;
    setState(_markActivated);
  }

  void _activateFromViewport() {
    if (_activated) {
      final index = _prefetchIndex;
      if (index != null) _chrome?.rowPrefetch.notifyVisible(index);
      return;
    }
    setState(_markActivated);
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
    // Static structure only — pulsing shimmer resumes on TickerMode when the
    // tab is shown again and reads as a "reload" even with no fetch.
    final ph = widget.placeholder ??
        SizedBox(height: widget.placeholderHeight);
    return VisibilityDetector(
      key: widget.detectorKey,
      onVisibilityChanged: _onVisibilityChanged,
      child: ph,
    );
  }
}
