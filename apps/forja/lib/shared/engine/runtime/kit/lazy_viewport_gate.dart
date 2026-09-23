import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forja/shared/engine/runtime/kit/pack_chrome_scope.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Test-only — clear sticky activate keys between widget tests.
@visibleForTesting
void debugResetLazyViewportGateActivatedKeys() {
  _LazyViewportGateState.debugResetActivatedKeys();
}

/// Activate [builder] only once the placeholder enters the viewport — or when
/// the row-prefetch lane warms this slot ahead of visibility.
///
/// Inactive state must paint [placeholder] (section skeleton) — never an empty
/// box or a spinner.
///
/// Activation is sticky for the session ([_activatedKeys]) so a soft remount /
/// tab hide→show does not flash shimmer again when memo already has the rail.
///
/// [eager] rows paint [builder] immediately (first-paint / host mounts) but
/// still claim a lane index and call [KitRowPrefetchLane.notifyVisible] so
/// gated rows below stay [kKitRowPrefetchAhead] ahead.
///
/// Prefetch [setState] can drop an in-flight [VisibilityDetector] callback.
/// Scroll + post-frame viewport checks also activate / notify so every gated
/// rail warms [kKitRowPrefetchAhead] rows before it reaches the screen.
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

  /// When true, paint [builder] immediately (hero / first-paint / host rows)
  /// but still participate in the prefetch lane.
  final bool eager;

  @override
  State<LazyViewportGate> createState() => _LazyViewportGateState();
}

class _LazyViewportGateState extends State<LazyViewportGate> {
  /// Survives State remounts for the same [LazyViewportGate.detectorKey].
  static final Set<String> _activatedKeys = {};

  /// Test-only — sticky keys otherwise poison later widget tests.
  @visibleForTesting
  static void debugResetActivatedKeys() => _activatedKeys.clear();

  bool _activated = false;
  int? _prefetchIndex;
  int _laneGen = -1;
  PackChromeScope? _chrome;
  ScrollPosition? _scrollPosition;

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
    _bindScrollPosition();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncViewport();
    });
  }

  @override
  void didUpdateWidget(covariant LazyViewportGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.eager && !_activated) {
      _markActivated();
    }
  }

  @override
  void dispose() {
    _scrollPosition?.removeListener(_onScroll);
    _scrollPosition = null;
    super.dispose();
  }

  void _markActivated() {
    _activated = true;
    _activatedKeys.add(_stickyId);
  }

  void _ensurePrefetchSlot() {
    final chrome = PackChromeScope.maybeOf(context);
    _chrome = chrome;
    if (chrome == null) return;
    // Claim even when already activated (eager / sticky) — host and first-paint
    // rows must advance the prefetch frontier for gated rails below.
    final gen = chrome.rowPrefetch.generation;
    if (_prefetchIndex != null && _laneGen == gen) return;
    _laneGen = gen;
    _prefetchIndex = chrome.rowPrefetch.claim(_warmFromPrefetch);
  }

  void _bindScrollPosition() {
    final next = Scrollable.maybeOf(context)?.position;
    if (identical(next, _scrollPosition)) return;
    _scrollPosition?.removeListener(_onScroll);
    _scrollPosition = next;
    _scrollPosition?.addListener(_onScroll);
  }

  void _onScroll() => _syncViewport();

  void _warmFromPrefetch() {
    if (!mounted || _activated) return;
    setState(_markActivated);
    // Do not notifyVisible here — that would cascade and fetch the whole page.
    // Only real visibility (or a late claim inside the ahead window) advances
    // the frontier by exactly [kKitRowPrefetchAhead].
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncViewport();
    });
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

  /// True when this gate overlaps the vertical catalog viewport (not cache).
  bool _overlapsViewport() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || box.size.height <= 0) {
      return false;
    }
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable == null) return false;
    final vpBox = scrollable.context.findRenderObject();
    if (vpBox is! RenderBox || !vpBox.hasSize) return false;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: vpBox);
    final viewH = scrollable.position.viewportDimension;
    return topLeft.dy + box.size.height > 0 && topLeft.dy < viewH;
  }

  /// Activate + notify when in the viewport — works for eager and gated rows.
  /// Gated rows must not wait only on VisibilityDetector (prefetch setState can
  /// drop it; scroll past Continue/Mood must still advance the lane).
  void _syncViewport() {
    if (!mounted) return;
    if (!_overlapsViewport()) return;
    _activateFromViewport();
  }

  @override
  Widget build(BuildContext context) {
    _ensurePrefetchSlot();
    _bindScrollPosition();
    final child = _activated
        ? widget.builder(context)
        : (widget.placeholder ??
            SizedBox(height: widget.placeholderHeight));
    return VisibilityDetector(
      key: widget.detectorKey,
      onVisibilityChanged: _onVisibilityChanged,
      child: child,
    );
  }
}
