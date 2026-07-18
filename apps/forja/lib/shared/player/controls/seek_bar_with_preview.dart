import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/design/src/forja_shell_colors.dart';
import 'package:forja/shared/player/controls/player_chrome_overlays.dart';
import 'package:forja/shared/player/player/utils.dart';

typedef SeekFrameCapture = Future<Uint8List?> Function(Duration position);

class SeekBarWithPreview extends StatefulWidget {
  const SeekBarWithPreview({
    super.key,
    required this.duration,
    required this.position,
    required this.bufferedPosition,
    required this.onSeek,
    this.onDragStart,
    this.onDragEnd,
    this.captureFrame,
  });

  final Duration duration;
  final Duration position;
  final Duration bufferedPosition;
  final void Function(Duration) onSeek;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;
  final SeekFrameCapture? captureFrame;

  @override
  State<SeekBarWithPreview> createState() => _SeekBarWithPreviewState();
}

class _SeekBarWithPreviewState extends State<SeekBarWithPreview> {
  bool _isDragging = false;
  bool _hovering = false;
  double _dragFrac = 0;
  double _hoverFrac = 0;
  double _trackWidth = 0;
  Uint8List? _previewBytes;
  Timer? _previewDebounce;
  int _previewToken = 0;
  int? _activePointer;
  Offset? _downGlobal;
  bool _movedEnoughToScrub = false;
  bool _globalRouteAttached = false;
  bool _overlayClearScheduled = false;

  double get _playFrac {
    final total = widget.duration.inMilliseconds.toDouble();
    if (total <= 0) return 0;
    if (_isDragging) return _dragFrac;
    return (widget.position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  double get _bufFrac {
    final total = widget.duration.inMilliseconds.toDouble();
    if (total <= 0) return 0;
    return (widget.bufferedPosition.inMilliseconds / total).clamp(0.0, 1.0);
  }

  Duration get _hoverTime {
    final total = widget.duration.inMilliseconds.toDouble();
    return Duration(milliseconds: (_hoverFrac * total).round());
  }

  bool get _scrubLive =>
      _isDragging || _hovering || _activePointer != null;

  @override
  void initState() {
    super.initState();
    playerChromeRegisterSeekScrubCancel(_cancelScrubFromOverlay);
  }

  @override
  void dispose() {
    _previewToken++;
    _previewDebounce?.cancel();
    _previewDebounce = null;
    playerChromeUnregisterSeekScrubCancel(_cancelScrubFromOverlay);
    _detachGlobalPointerRoute();
    super.dispose();
  }

  /// Menus open above the bar and would keep the thumb magnetized — drop scrub.
  void _cancelScrubFromOverlay() {
    if (!mounted) return;
    if (!_scrubLive) return;
    _endScrub(commit: false, clearHover: true);
  }

  void _scheduleOverlayClearIfNeeded() {
    if (!playerChromeOverlayBlocksSeek() || !_scrubLive) {
      _overlayClearScheduled = false;
      return;
    }
    if (_overlayClearScheduled) return;
    _overlayClearScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _overlayClearScheduled = false;
      if (!mounted) return;
      if (playerChromeOverlayBlocksSeek() && _scrubLive) {
        _endScrub(commit: false, clearHover: true);
      }
    });
  }

  void _schedulePreview() {
    _previewDebounce?.cancel();
    if (widget.captureFrame == null) return;
    final token = ++_previewToken;
    _previewDebounce = Timer(const Duration(milliseconds: 200), () async {
      if (!mounted || token != _previewToken) return;
      final bytes = await widget.captureFrame!(_hoverTime);
      if (!mounted || token != _previewToken) return;
      setState(() => _previewBytes = bytes);
    });
  }

  double _fracFromLocal(double dx) {
    if (_trackWidth <= 0) return 0;
    return (dx / _trackWidth).clamp(0.0, 1.0);
  }

  double _fracFromGlobal(Offset global) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return _dragFrac;
    return _fracFromLocal(box.globalToLocal(global).dx);
  }

  /// Global scrub follows cursor X anywhere; keep a tight vertical leash so
  /// moving onto Quality / Settings (under the bar) does not magnetize the thumb.
  bool _pointerWithinScrubLeash(Offset global) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return false;
    final local = box.globalToLocal(global);
    const xPad = 24.0;
    const yPad = 12.0;
    return local.dx >= -xPad &&
        local.dx <= box.size.width + xPad &&
        local.dy >= -yPad &&
        local.dy <= box.size.height + yPad;
  }

  void _attachGlobalPointerRoute() {
    if (_globalRouteAttached) return;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onGlobalPointer);
    _globalRouteAttached = true;
  }

  void _detachGlobalPointerRoute() {
    if (!_globalRouteAttached) return;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onGlobalPointer);
    _globalRouteAttached = false;
  }

  /// Keep a global route while hover or press is live so a missed MouseRegion
  /// exit (center transport / top chrome above the bar) cannot leave the thumb
  /// magnetized to the cursor.
  void _syncGlobalPointerRoute() {
    if (_hovering || _activePointer != null || _isDragging) {
      _attachGlobalPointerRoute();
    } else {
      _detachGlobalPointerRoute();
    }
  }

  void _onGlobalPointer(PointerEvent event) {
    if (!mounted) {
      _detachGlobalPointerRoute();
      return;
    }

    // Hover-only: enforce the same leash so the thumb cannot follow the cursor
    // over center play / ±10 or the top bar after onExit is skipped.
    final pointer = _activePointer;
    if (pointer == null) {
      if (!_hovering) return;
      if (event is! PointerHoverEvent && event is! PointerMoveEvent) return;
      if (playerChromeOverlayBlocksSeek() ||
          !_pointerWithinScrubLeash(event.position)) {
        _endScrub(commit: false, clearHover: true);
      }
      return;
    }
    if (event.pointer != pointer) return;

    // Source / Audio / etc. overlays steal the cursor — release scrub so the
    // thumb does not stay magnetized to the pointer over the menu.
    if (playerChromeOverlayBlocksSeek()) {
      _endScrub(commit: false, clearHover: true);
      return;
    }

    if (event is PointerMoveEvent) {
      // Quality / Settings sit under the right end of the bar — leave the track
      // (or press-and-slide onto those icons) must drop capture immediately.
      if (!_pointerWithinScrubLeash(event.position)) {
        _endScrub(commit: false, clearHover: true);
        return;
      }
      final down = _downGlobal;
      if (!_movedEnoughToScrub && down != null) {
        final dist = (event.position - down).distance;
        if (dist < kTouchSlop) return;
        _movedEnoughToScrub = true;
        if (!_isDragging) {
          widget.onDragStart?.call();
          if (!mounted) return;
          setState(() {
            _isDragging = true;
            _dragFrac = _fracFromGlobal(event.position);
            _hoverFrac = _dragFrac;
          });
          _schedulePreview();
        }
      }
      if (!_isDragging) return;
      if (!mounted) return;
      setState(() {
        _dragFrac = _fracFromGlobal(event.position);
        _hoverFrac = _dragFrac;
      });
      _schedulePreview();
      return;
    }

    if (event is PointerUpEvent || event is PointerCancelEvent) {
      final commit = event is PointerUpEvent &&
          (_isDragging || !_movedEnoughToScrub);
      // Tap (no drag): seek to press position. Drag: seek to final frac.
      if (commit && !playerChromeOverlayBlocksSeek()) {
        final total = widget.duration.inMilliseconds.toDouble();
        final frac = _isDragging
            ? _dragFrac
            : _fracFromGlobal(event.position);
        widget.onSeek(Duration(milliseconds: (frac * total).round()));
      }
      // If the release is outside the track, drop hover — otherwise a drag that
      // ended over center/top chrome leaves the thumb stuck to the cursor.
      final clearHover = event is PointerCancelEvent ||
          !_pointerWithinScrubLeash(event.position);
      _endScrub(commit: false, clearHover: clearHover);
    }
  }

  void _endScrub({required bool commit, required bool clearHover}) {
    final wasDragging = _isDragging;
    _activePointer = null;
    _downGlobal = null;
    _movedEnoughToScrub = false;
    if (wasDragging) {
      if (commit && !playerChromeOverlayBlocksSeek()) {
        final total = widget.duration.inMilliseconds.toDouble();
        widget.onSeek(Duration(milliseconds: (_dragFrac * total).round()));
      }
      try {
        widget.onDragEnd?.call();
      } catch (_) {}
    }
    if (!mounted) {
      _detachGlobalPointerRoute();
      return;
    }
    setState(() {
      _isDragging = false;
      if (clearHover) {
        _hovering = false;
        _previewBytes = null;
      }
    });
    _syncGlobalPointerRoute();
  }

  void _onPointerDown(PointerDownEvent event) {
    if (playerChromeOverlayBlocksSeek()) return;
    if (event.buttons != kPrimaryButton && event.buttons != 0) return;
    _activePointer = event.pointer;
    _downGlobal = event.position;
    _movedEnoughToScrub = false;
    setState(() {
      _hoverFrac = _fracFromLocal(event.localPosition.dx);
      _dragFrac = _hoverFrac;
    });
    _syncGlobalPointerRoute();
  }

  @override
  Widget build(BuildContext context) {
    _scheduleOverlayClearIfNeeded();
    final active = _hovering || _isDragging;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (e) {
        if (playerChromeOverlayBlocksSeek()) return;
        setState(() {
          _hovering = true;
          _hoverFrac = _fracFromLocal(e.localPosition.dx);
        });
        _syncGlobalPointerRoute();
        _schedulePreview();
      },
      onHover: (e) {
        if (playerChromeOverlayBlocksSeek() || _isDragging) return;
        setState(() => _hoverFrac = _fracFromLocal(e.localPosition.dx));
        _schedulePreview();
      },
      onExit: (_) {
        // Always clear hover on leave. Drag updates use the global route; skipping
        // this left the thumb magnetized after release over center/top chrome.
        if (_hovering || _previewBytes != null) {
          setState(() {
            _hovering = false;
            _previewBytes = null;
          });
        }
        _syncGlobalPointerRoute();
      },
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _onPointerDown,
        // Fixed hit height — preview paints above via [clipBehavior: Clip.none]
        // and must not grow this box into the transport / Source button row.
        child: SizedBox(
          height: 28,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              if (active)
                Positioned(
                  bottom: 24,
                  left: (_hoverFrac * _trackWidth - 64)
                      .clamp(0.0, _trackWidth - 128),
                  child: IgnorePointer(
                    child: _PreviewBubble(
                      time: _hoverTime,
                      imageBytes: _previewBytes,
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  height: 20,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      _trackWidth = constraints.maxWidth;
                      final trackH = active ? 6.0 : 3.0;
                      final thumbR = active ? 7.0 : 0.0;
                      final playPx =
                          (_playFrac * _trackWidth).clamp(0.0, _trackWidth);
                      final hoverPx =
                          (_hoverFrac * _trackWidth).clamp(0.0, _trackWidth);

                      return Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          Container(
                            height: trackH,
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(trackH),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: _bufFrac.clamp(0.001, 1.0),
                            child: Container(
                              height: trackH,
                              decoration: BoxDecoration(
                                color: Colors.white38,
                                borderRadius: BorderRadius.circular(trackH),
                              ),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: _playFrac.clamp(0.001, 1.0),
                            child: Container(
                              height: trackH,
                              decoration: BoxDecoration(
                                color: ForjaShellColors.brandGreen,
                                borderRadius: BorderRadius.circular(trackH),
                              ),
                            ),
                          ),
                          if (active)
                            Positioned(
                              left: hoverPx - 1,
                              child: Container(
                                width: 2,
                                height: 16,
                                color: ForjaShellColors.brandGreen
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          if (thumbR > 0)
                            Positioned(
                              left: playPx - thumbR,
                              child: Container(
                                width: thumbR * 2,
                                height: thumbR * 2,
                                decoration: const BoxDecoration(
                                  color: ForjaShellColors.brandGreen,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewBubble extends StatelessWidget {
  const _PreviewBubble({required this.time, this.imageBytes});

  final Duration time;
  final Uint8List? imageBytes;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (imageBytes != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.memory(
              imageBytes!,
              width: 128,
              height: 72,
              fit: BoxFit.cover,
            ),
          )
        else
          Container(
            width: 128,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white24),
            ),
            child: Text(
              formatDuration(time),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        const SizedBox(height: 4),
        Text(
          formatDuration(time),
          style: const TextStyle(color: Colors.white, fontSize: 11),
        ),
      ],
    );
  }
}
